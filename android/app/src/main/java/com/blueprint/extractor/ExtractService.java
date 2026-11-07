package com.blueprint.extractor;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.net.Uri;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.PowerManager;
import android.provider.MediaStore;

import java.io.BufferedInputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

/**
 * Extracts an APK into Download/ExtractedFiles/<name>/ as real folders.
 *
 * Runs as a foreground service so it keeps going when the app is in the
 * background or the screen is off. Progress is broadcast to the activity and
 * mirrored in the notification, which also carries a Cancel action.
 */
public class ExtractService extends Service {

    public static final String ACTION_START = "com.blueprint.extractor.START";
    public static final String ACTION_CANCEL = "com.blueprint.extractor.CANCEL";
    public static final String EXTRA_URI = "uri";
    public static final String EXTRA_LABEL = "label";
    public static final String EXTRA_SKIP_EXISTING = "skipExisting";
    public static final String EXTRA_KEEP_IMAGES = "keepImages";
    public static final String EXTRA_KEEP_AUDIO = "keepAudio";
    public static final String EXTRA_KEEP_DATA = "keepData";
    public static final String EXTRA_KEEP_FONTS = "keepFonts";
    public static final String EXTRA_KEEP_OTHER = "keepOther";

    public static final String BROADCAST = "com.blueprint.extractor.PROGRESS";
    public static final String OUT_FILES = "files";
    public static final String OUT_BYTES = "bytes";
    public static final String OUT_SKIPPED = "skipped";
    public static final String OUT_NAME = "name";
    public static final String OUT_DONE = "done";
    public static final String OUT_ERROR = "error";
    public static final String OUT_CANCELLED = "cancelled";
    public static final String OUT_FAILED = "failed";

    private static final String CHANNEL_ID = "extract";
    private static final int NOTIFICATION_ID = 1001;
    private static final String BASE_DIR = "Download/ExtractedFiles/";

    private final Handler main = new Handler(Looper.getMainLooper());
    private volatile boolean cancelled = false;
    private PowerManager.WakeLock wakeLock;

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null && ACTION_CANCEL.equals(intent.getAction())) {
            cancelled = true;
            notifyUser("Stopping…", 0, 0, false);
            return START_NOT_STICKY;
        }
        if (intent == null || intent.getStringExtra(EXTRA_URI) == null) {
            stopSelf();
            return START_NOT_STICKY;
        }

        final Uri uri = Uri.parse(intent.getStringExtra(EXTRA_URI));
        final String label = intent.getStringExtra(EXTRA_LABEL);
        final boolean skipExisting = intent.getBooleanExtra(EXTRA_SKIP_EXISTING, true);
        final int mask = maskOf(intent);

        createChannel();
        startForeground(NOTIFICATION_ID, buildNotification("Preparing…", 0, 0, true),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC);

        PowerManager pm = (PowerManager) getSystemService(Context.POWER_SERVICE);
        if (pm != null) {
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "extractor:work");
            wakeLock.setReferenceCounted(false);
            wakeLock.acquire(8 * 60 * 60 * 1000L);
        }

        new Thread(() -> run(uri, label, skipExisting, mask), "extract-worker").start();
        return START_NOT_STICKY;
    }

    private int maskOf(Intent intent) {
        int mask = 0;
        if (intent.getBooleanExtra(EXTRA_KEEP_IMAGES, true)) mask |= 1;
        if (intent.getBooleanExtra(EXTRA_KEEP_AUDIO, true)) mask |= 2;
        if (intent.getBooleanExtra(EXTRA_KEEP_DATA, true)) mask |= 4;
        if (intent.getBooleanExtra(EXTRA_KEEP_FONTS, true)) mask |= 8;
        if (intent.getBooleanExtra(EXTRA_KEEP_OTHER, true)) mask |= 16;
        return mask == 0 ? 31 : mask;
    }

    private void run(Uri uri, String label, boolean skipExisting, int mask) {
        final ContentResolver cr = getContentResolver();
        int files = 0;
        int skipped = 0;
        int failed = 0;
        long bytes = 0;

        Set<String> alreadyThere = skipExisting ? existingFiles(cr) : new HashSet<>();

        try (InputStream raw = cr.openInputStream(uri)) {
            if (raw == null) {
                throw new IllegalStateException("The picked file could not be opened.");
            }
            try (ZipInputStream zin = new ZipInputStream(new BufferedInputStream(raw, 1 << 16))) {
                ZipEntry entry;
                byte[] buffer = new byte[1 << 16];
                while ((entry = zin.getNextEntry()) != null) {
                    if (cancelled) {
                        finish(files, bytes, skipped, failed, null, true);
                        return;
                    }
                    if (entry.isDirectory()) {
                        continue;
                    }
                    String name = clean(entry.getName());
                    if (name.isEmpty() || !keep(name, mask)) {
                        continue;
                    }
                    int slash = name.lastIndexOf('/');
                    String dir = slash >= 0 ? name.substring(0, slash + 1) : "";
                    String fileName = slash >= 0 ? name.substring(slash + 1) : name;
                    if (fileName.isEmpty()) {
                        continue;
                    }
                    String key = BASE_DIR + dir + fileName;
                    if (alreadyThere.contains(key)) {
                        skipped++;
                        continue;
                    }

                    // One unwritable file must never kill the whole run: a single
                    // rejected name used to abort a multi-thousand file extraction.
                    try {
                        ContentValues values = new ContentValues();
                        values.put(MediaStore.Downloads.DISPLAY_NAME, safeName(fileName));
                        values.put(MediaStore.Downloads.MIME_TYPE, mimeOf(fileName));
                        values.put(MediaStore.Downloads.RELATIVE_PATH, BASE_DIR + safeDir(dir));
                        values.put(MediaStore.Downloads.IS_PENDING, 1);

                        Uri target = cr.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values);
                        if (target == null) {
                            failed++;
                            continue;
                        }
                        try (OutputStream out = cr.openOutputStream(target)) {
                            if (out == null) {
                                failed++;
                                continue;
                            }
                            int read;
                            while ((read = zin.read(buffer)) > 0) {
                                if (cancelled) {
                                    break;
                                }
                                out.write(buffer, 0, read);
                                bytes += read;
                            }
                        }
                        values.clear();
                        values.put(MediaStore.Downloads.IS_PENDING, 0);
                        cr.update(target, values, null, null);
                    } catch (Exception perFile) {
                        failed++;
                        continue;
                    }

                    files++;
                    if (files % 15 == 0) {
                        publish(files, bytes, skipped, name);
                    }
                }
            }
            finish(files, bytes, skipped, failed, null, false);
        } catch (Exception e) {
            finish(files, bytes, skipped, failed, e, false);
        }
    }

    private Set<String> existingFiles(ContentResolver cr) {
        Set<String> out = new HashSet<>();
        String[] projection = {MediaStore.Downloads.RELATIVE_PATH, MediaStore.Downloads.DISPLAY_NAME};
        try (android.database.Cursor c = cr.query(MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                projection, null, null, null)) {
            if (c != null) {
                while (c.moveToNext()) {
                    String dir = c.getString(0);
                    String name = c.getString(1);
                    if (dir != null && name != null && dir.startsWith(BASE_DIR)) {
                        out.add(dir + name);
                    }
                }
            }
        } catch (Exception ignored) {
            // an empty set just means nothing is skipped
        }
        return out;
    }

    private void publish(int files, long bytes, int skipped, String name) {
        notifyUser(files + " files · " + mb(bytes) + " MB", files, bytes, true);
        Intent i = new Intent(BROADCAST);
        i.setPackage(getPackageName());
        i.putExtra(OUT_FILES, files);
        i.putExtra(OUT_BYTES, bytes);
        i.putExtra(OUT_SKIPPED, skipped);
        i.putExtra(OUT_NAME, name);
        i.putExtra(OUT_DONE, false);
        sendBroadcast(i);
    }

    private void finish(int files, long bytes, int skipped, int failed, Exception error, boolean wasCancelled) {
        Intent i = new Intent(BROADCAST);
        i.setPackage(getPackageName());
        i.putExtra(OUT_FILES, files);
        i.putExtra(OUT_BYTES, bytes);
        i.putExtra(OUT_SKIPPED, skipped);
        i.putExtra(OUT_FAILED, failed);
        i.putExtra(OUT_DONE, true);
        i.putExtra(OUT_CANCELLED, wasCancelled);
        if (error != null) {
            i.putExtra(OUT_ERROR, error.getClass().getSimpleName() + ": " + error.getMessage());
        }
        sendBroadcast(i);

        String head = failed > 0 ? failed + " files could not be written. " : "";
        String text = head + (wasCancelled
                ? "Cancelled after " + files + " files"
                : (error != null ? "Failed: " + error.getMessage()
                : files + " files · " + mb(bytes) + " MB written"));
        notifyUser(text, files, bytes, false);

        releaseWakeLock();
        stopForeground(false);
        stopSelf();
    }

    private void releaseWakeLock() {
        try {
            if (wakeLock != null && wakeLock.isHeld()) {
                wakeLock.release();
            }
        } catch (Exception ignored) {
            // nothing to do
        }
        wakeLock = null;
    }

    @Override
    public void onDestroy() {
        releaseWakeLock();
        super.onDestroy();
    }

    // ---- notification -----------------------------------------------------

    private void createChannel() {
        NotificationManager nm = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
        if (nm == null) {
            return;
        }
        NotificationChannel channel = new NotificationChannel(CHANNEL_ID, "Extraction",
                NotificationManager.IMPORTANCE_LOW);
        channel.setDescription("Progress while an APK is being extracted");
        channel.setShowBadge(false);
        nm.createNotificationChannel(channel);
    }

    private Notification buildNotification(String text, int files, long bytes, boolean ongoing) {
        Intent open = new Intent(this, MainActivity.class);
        open.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
        PendingIntent content = PendingIntent.getActivity(this, 0, open,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

        Notification.Builder b = new Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("Extracting APK")
                .setContentText(text)
                .setSmallIcon(android.R.drawable.stat_sys_download)
                .setOngoing(ongoing)
                .setOnlyAlertOnce(true)
                .setContentIntent(content);

        if (ongoing) {
            b.setProgress(0, 0, true);
            Intent cancel = new Intent(this, ExtractService.class).setAction(ACTION_CANCEL);
            PendingIntent cancelPi = PendingIntent.getService(this, 1, cancel,
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
            b.addAction(new Notification.Action.Builder(null, "Cancel", cancelPi).build());
        }
        return b.build();
    }

    private void notifyUser(String text, int files, long bytes, boolean ongoing) {
        NotificationManager nm = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
        if (nm == null) {
            return;
        }
        try {
            nm.notify(NOTIFICATION_ID, buildNotification(text, files, bytes, ongoing));
        } catch (Exception ignored) {
            // notification permission may have been denied; the service still runs
        }
    }

    // ---- helpers ----------------------------------------------------------

    private static String mb(long bytes) {
        return String.format(Locale.US, "%.1f", bytes / 1048576.0);
    }


    /** MediaStore rejects some characters; keep names it will accept. */
    private static String safeName(String name) {
        String n = name.replaceAll("[\\\\/:*?\"<>|\\x00-\\x1F]", "_");
        if (n.length() > 120) {
            String ext = extOf(n);
            n = n.substring(0, Math.max(1, 120 - ext.length() - 1)) + (ext.isEmpty() ? "" : "." + ext);
        }
        return n.isEmpty() ? "_unnamed" : n;
    }

    private static String safeDir(String dir) {
        return dir.replaceAll("[\\\\:*?\"<>|\\x00-\\x1F]", "_");
    }

    private static String clean(String name) {
        String n = name.replace('\\', '/');
        while (n.startsWith("/")) {
            n = n.substring(1);
        }
        if (n.contains("..")) {
            n = n.replace("..", "_");
        }
        return n;
    }

    private static boolean keep(String name, int mask) {
        String ext = extOf(name);
        boolean image = ext.equals("png") || ext.equals("jpg") || ext.equals("jpeg")
                || ext.equals("webp") || ext.equals("gif") || ext.equals("bmp");
        boolean audio = ext.equals("ogg") || ext.equals("mp3") || ext.equals("wav")
                || ext.equals("m4a") || ext.equals("aac") || ext.equals("opus");
        boolean data = ext.equals("json") || ext.equals("xml") || ext.equals("plist")
                || ext.equals("csv") || ext.equals("txt") || ext.equals("dat")
                || ext.equals("lvl") || ext.equals("atlas") || ext.equals("tmx")
                || ext.equals("ini") || ext.equals("cfg") || ext.equals("yml")
                || ext.equals("yaml") || ext.equals("md");
        boolean font = ext.equals("ttf") || ext.equals("otf") || ext.equals("fnt");
        if (image) return (mask & 1) != 0;
        if (audio) return (mask & 2) != 0;
        if (data) return (mask & 4) != 0;
        if (font) return (mask & 8) != 0;
        return (mask & 16) != 0;
    }

    private static String extOf(String name) {
        int dot = name.lastIndexOf('.');
        return dot >= 0 ? name.substring(dot + 1).toLowerCase(Locale.US) : "";
    }

    private static String mimeOf(String name) {
        switch (extOf(name)) {
            case "png": return "image/png";
            case "jpg":
            case "jpeg": return "image/jpeg";
            case "webp": return "image/webp";
            case "gif": return "image/gif";
            case "ogg": return "audio/ogg";
            case "mp3": return "audio/mpeg";
            case "wav": return "audio/wav";
            case "m4a": return "audio/mp4";
            case "json": return "application/json";
            case "xml": return "application/xml";
            case "txt": return "text/plain";
            case "ttf": return "font/ttf";
            case "otf": return "font/otf";
            default: return "application/octet-stream";
        }
    }
}
