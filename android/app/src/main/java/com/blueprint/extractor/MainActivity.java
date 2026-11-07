package com.blueprint.extractor;

import android.Manifest;
import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.ScrollView;
import android.widget.TextView;

import java.util.Locale;

/**
 * Picks an APK, hands it to ExtractService, and shows progress.
 * Extraction itself runs in the foreground service, so it survives the app
 * being backgrounded or the screen being switched off.
 */
public class MainActivity extends Activity {

    private static final int REQ_PICK = 42;
    private static final int REQ_NOTIF = 43;

    private TextView status;
    private ProgressBar bar;
    private Button pick;
    private Button cancel;

    private CheckBox cbImages;
    private CheckBox cbAudio;
    private CheckBox cbData;
    private CheckBox cbFonts;
    private CheckBox cbOther;
    private CheckBox cbSkip;

    private boolean running = false;
    private BroadcastReceiver receiver;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(56, 88, 56, 48);
        root.setBackgroundColor(Color.parseColor("#14161F"));

        TextView title = new TextView(this);
        title.setText("APK Extractor");
        title.setTextSize(26);
        title.setTextColor(Color.parseColor("#EEF1F8"));
        root.addView(title);

        TextView sub = new TextView(this);
        sub.setText("Pick an APK. Every file inside is written to "
                + "Download/ExtractedFiles/<name>/ as real folders. "
                + "Runs in the background — you can leave the app. Nothing is uploaded.");
        sub.setTextSize(14);
        sub.setTextColor(Color.parseColor("#9AA3BD"));
        sub.setPadding(0, 18, 0, 28);
        root.addView(sub);

        TextView optTitle = new TextView(this);
        optTitle.setText("What to extract");
        optTitle.setTextSize(13);
        optTitle.setTextColor(Color.parseColor("#F2C94C"));
        root.addView(optTitle);

        cbImages = check("Images  (png, jpg, webp, gif)", true);
        cbAudio = check("Audio  (ogg, mp3, wav, m4a)", true);
        cbData = check("Data  (json, xml, plist, txt, dat)", true);
        cbFonts = check("Fonts  (ttf, otf, fnt)", true);
        cbOther = check("Everything else  (dex, so, bin)", true);
        cbSkip = check("Skip files that already exist", true);

        root.addView(cbImages);
        root.addView(cbAudio);
        root.addView(cbData);
        root.addView(cbFonts);
        root.addView(cbOther);
        root.addView(cbSkip);

        pick = new Button(this);
        pick.setText("Choose APK and extract");
        pick.setAllCaps(false);
        pick.setTextSize(16);
        pick.setOnClickListener(v -> pickFile());
        LinearLayout.LayoutParams pickParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        pickParams.topMargin = 28;
        root.addView(pick, pickParams);

        cancel = new Button(this);
        cancel.setText("Cancel extraction");
        cancel.setAllCaps(false);
        cancel.setVisibility(View.GONE);
        cancel.setOnClickListener(v -> stopExtraction());
        root.addView(cancel);

        bar = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        bar.setMax(100);
        bar.setProgress(0);
        LinearLayout.LayoutParams barParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 26);
        barParams.topMargin = 26;
        root.addView(bar, barParams);

        ScrollView scroll = new ScrollView(this);
        status = new TextView(this);
        status.setText("Ready. Extraction continues in the background once started.");
        status.setTextSize(13);
        status.setTextColor(Color.parseColor("#EEF1F8"));
        status.setPadding(0, 22, 0, 0);
        scroll.addView(status);
        root.addView(scroll, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));

        setContentView(root);
        askForNotifications();
    }

    private CheckBox check(String label, boolean on) {
        CheckBox box = new CheckBox(this);
        box.setText(label);
        box.setChecked(on);
        box.setTextColor(Color.parseColor("#C7CEE0"));
        box.setTextSize(14);
        return box;
    }

    private void askForNotifications() {
        if (Build.VERSION.SDK_INT >= 33
                && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, REQ_NOTIF);
        }
    }

    @Override
    protected void onStart() {
        super.onStart();
        IntentFilter filter = new IntentFilter(ExtractService.BROADCAST);
        receiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                onProgress(intent);
            }
        };
        if (Build.VERSION.SDK_INT >= 33) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED);
        } else {
            registerReceiver(receiver, filter);
        }
    }

    @Override
    protected void onStop() {
        super.onStop();
        if (receiver != null) {
            try {
                unregisterReceiver(receiver);
            } catch (Exception ignored) {
                // already gone
            }
            receiver = null;
        }
    }

    private void onProgress(Intent intent) {
        int files = intent.getIntExtra(ExtractService.OUT_FILES, 0);
        long bytes = intent.getLongExtra(ExtractService.OUT_BYTES, 0);
        int skipped = intent.getIntExtra(ExtractService.OUT_SKIPPED, 0);
        boolean done = intent.getBooleanExtra(ExtractService.OUT_DONE, false);
        boolean cancelled = intent.getBooleanExtra(ExtractService.OUT_CANCELLED, false);
        String error = intent.getStringExtra(ExtractService.OUT_ERROR);
        String name = intent.getStringExtra(ExtractService.OUT_NAME);

        if (!done) {
            bar.setProgress(Math.min(95, files / 30));
            status.setText(files + " files written · " + mb(bytes) + " MB"
                    + (skipped > 0 ? " · " + skipped + " skipped" : "")
                    + (name != null ? "\n" + name : ""));
            return;
        }

        running = false;
        pick.setEnabled(true);
        pick.setText("Choose APK and extract");
        cancel.setVisibility(View.GONE);
        bar.setProgress(100);

        if (error != null) {
            status.setText("Failed: " + error);
        } else if (cancelled) {
            status.setText("Cancelled. " + files + " files were written.");
        } else if (files == 0 && skipped == 0) {
            status.setText("Nothing matched your filters. Tick more boxes and try again.");
        } else {
            status.setText("Done. " + files + " files · " + mb(bytes) + " MB"
                    + (skipped > 0 ? " · " + skipped + " already existed" : "")
                    + "\n\nOpen Files → Downloads → ExtractedFiles.");
        }
    }

    private void pickFile() {
        if (running) {
            return;
        }
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("*/*");
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION
                | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
        try {
            startActivityForResult(intent, REQ_PICK);
        } catch (Exception e) {
            status.setText("Could not open the file picker: " + e.getMessage());
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
            status.setText("No file was returned by the picker.");
            return;
        }
        try {
            getContentResolver().takePersistableUriPermission(uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION);
        } catch (Exception ignored) {
            // not fatal: the grant lasts as long as this task
        }
        start(uri);
    }

    private void start(Uri uri) {
        running = true;
        pick.setEnabled(false);
        pick.setText("Working…");
        cancel.setVisibility(View.VISIBLE);
        bar.setProgress(0);
        status.setText("Starting. You can switch apps or lock the screen — it will keep going.");

        Intent intent = new Intent(this, ExtractService.class)
                .setAction(ExtractService.ACTION_START)
                .putExtra(ExtractService.EXTRA_URI, uri.toString())
                .putExtra(ExtractService.EXTRA_SKIP_EXISTING, cbSkip.isChecked())
                .putExtra(ExtractService.EXTRA_KEEP_IMAGES, cbImages.isChecked())
                .putExtra(ExtractService.EXTRA_KEEP_AUDIO, cbAudio.isChecked())
                .putExtra(ExtractService.EXTRA_KEEP_DATA, cbData.isChecked())
                .putExtra(ExtractService.EXTRA_KEEP_FONTS, cbFonts.isChecked())
                .putExtra(ExtractService.EXTRA_KEEP_OTHER, cbOther.isChecked());
        try {
            startForegroundService(intent);
        } catch (Exception e) {
            running = false;
            pick.setEnabled(true);
            pick.setText("Choose APK and extract");
            cancel.setVisibility(View.GONE);
            status.setText("Could not start the service: " + e.getMessage());
        }
    }

    private void stopExtraction() {
        startService(new Intent(this, ExtractService.class)
                .setAction(ExtractService.ACTION_CANCEL));
        status.setText("Stopping…");
    }

    private static String mb(long bytes) {
        return String.format(Locale.US, "%.1f", bytes / 1048576.0);
    }
}
