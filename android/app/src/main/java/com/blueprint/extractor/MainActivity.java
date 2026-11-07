package com.blueprint.extractor;

import android.app.Activity;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.MediaStore;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.ScrollView;
import android.widget.TextView;

import java.io.BufferedInputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.Locale;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

/**
 * Pick an APK, write every file inside it to Download/ExtractedFiles/<apk name>/
 * as real folders. No network, nothing uploaded, no root.
 */
public class MainActivity extends Activity {

    private static final int REQ_PICK = 42;
    private static final String BASE_DIR = "Download/ExtractedFiles/";

    private final Handler ui = new Handler(Looper.getMainLooper());
    private TextView status;
    private ProgressBar bar;
    private Button pick;
    private volatile boolean running = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(56, 96, 56, 56);
        root.setBackgroundColor(Color.parseColor("#14161F"));

        TextView title = new TextView(this);
        title.setText("APK Extractor");
        title.setTextSize(26);
        title.setTextColor(Color.parseColor("#EEF1F8"));
        root.addView(title);

        TextView sub = new TextView(this);
        sub.setText("Pick an APK. Every file inside is written to "
                + "Download/ExtractedFiles/<name>/ as real folders. "
                + "Nothing leaves your phone.");
        sub.setTextSize(14);
        sub.setTextColor(Color.parseColor("#9AA3BD"));
        sub.setPadding(0, 20, 0, 40);
        root.addView(sub);

        pick = new Button(this);
        pick.setText("Choose APK and extract");
        pick.setAllCaps(false);
        pick.setTextSize(16);
        pick.setOnClickListener(v -> pickFile());
        root.addView(pick);

        bar = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        bar.setMax(100);
        bar.setProgress(0);
        LinearLayout.LayoutParams barParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 28);
        barParams.topMargin = 36;
        root.addView(bar, barParams);

        ScrollView scroll = new ScrollView(this);
        status = new TextView(this);
        status.setText("Ready.");
        status.setTextSize(13);
        status.setTextColor(Color.parseColor("#EEF1F8"));
        status.setPadding(0, 28, 0, 0);
        scroll.addView(status);
        LinearLayout.LayoutParams scrollParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f);
        root.addView(scroll, scrollParams);

        setContentView(root);
    }

    private void pickFile() {
        if (running) {
            say("Still working on the previous file.");
            return;
        }
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("*/*");
        try {
            startActivityForResult(intent, REQ_PICK);
        } catch (Exception e) {
            say("Could not open the file picker: " + e.getMessage());
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != REQ_PICK || resultCode != RESULT_OK || data == null) {
            return;
        }
        Uri uri = data.getData();
        if (uri == null) {
            say("No file was returned by the picker.");
            return;
        }
        extract(uri);
    }

    private void extract(final Uri uri) {
        running = true;
        pick.setEnabled(false);
        bar.setProgress(0);
        say("Opening the archive…");

        new Thread(() -> {
            final ContentResolver cr = getContentResolver();
            int files = 0;
            long bytes = 0;
            String lastName = "";
            try (InputStream raw = cr.openInputStream(uri)) {
                if (raw == null) {
                    throw new IllegalStateException("The picker returned an unreadable file.");
                }
                try (ZipInputStream zin = new ZipInputStream(new BufferedInputStream(raw, 1 << 16))) {
                    ZipEntry entry;
                    byte[] buffer = new byte[1 << 16];
                    while ((entry = zin.getNextEntry()) != null) {
                        if (entry.isDirectory()) {
                            continue;
                        }
                        String name = clean(entry.getName());
                        if (name.isEmpty()) {
                            continue;
                        }
                        int slash = name.lastIndexOf('/');
                        String dir = slash >= 0 ? name.substring(0, slash + 1) : "";
                        String fileName = slash >= 0 ? name.substring(slash + 1) : name;
                        if (fileName.isEmpty()) {
                            continue;
                        }

                        ContentValues values = new ContentValues();
                        values.put(MediaStore.Downloads.DISPLAY_NAME, fileName);
                        values.put(MediaStore.Downloads.MIME_TYPE, mimeOf(fileName));
                        values.put(MediaStore.Downloads.RELATIVE_PATH, BASE_DIR + dir);
                        values.put(MediaStore.Downloads.IS_PENDING, 1);

                        Uri target = cr.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values);
                        if (target == null) {
                            continue;
                        }
                        try (OutputStream out = cr.openOutputStream(target)) {
                            if (out == null) {
                                continue;
                            }
                            int read;
                            while ((read = zin.read(buffer)) > 0) {
                                out.write(buffer, 0, read);
                                bytes += read;
                            }
                        }
                        values.clear();
                        values.put(MediaStore.Downloads.IS_PENDING, 0);
                        cr.update(target, values, null, null);

                        files++;
                        lastName = name;
                        if (files % 20 == 0) {
                            progress(files, bytes, name);
                        }
                    }
                }
                finish(files, bytes, lastName);
            } catch (Exception e) {
                fail(e);
            }
        }, "extractor").start();
    }

    private void progress(int files, long bytes, String name) {
        ui.post(() -> {
            bar.setProgress(Math.min(99, files / 30));
            say(files + " files written, " + mb(bytes) + " MB\n" + name);
        });
    }

    private void finish(int files, long bytes, String lastName) {
        ui.post(() -> {
            running = false;
            pick.setEnabled(true);
            bar.setProgress(100);
            if (files == 0) {
                say("No files were found inside that archive. Is it really an APK?");
            } else {
                say("Done. " + files + " files, " + mb(bytes) + " MB.\n\n"
                        + "Open the Files app → Downloads → ExtractedFiles to see them.");
            }
        });
    }

    private void fail(Exception e) {
        ui.post(() -> {
            running = false;
            pick.setEnabled(true);
            say("Failed: " + e.getClass().getSimpleName() + " — " + e.getMessage());
        });
    }

    private void say(String message) {
        if (status != null) {
            status.setText(message);
        }
    }

    private static String mb(long bytes) {
        return String.format(Locale.US, "%.1f", bytes / 1048576.0);
    }

    /** Strip absolute paths and parent-directory hops so nothing can escape the target. */
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

    private static String mimeOf(String name) {
        String lower = name.toLowerCase(Locale.US);
        int dot = lower.lastIndexOf('.');
        String ext = dot >= 0 ? lower.substring(dot + 1) : "";
        switch (ext) {
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
