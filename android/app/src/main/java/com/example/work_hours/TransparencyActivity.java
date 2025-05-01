package com.example.work_hours;

import android.content.SharedPreferences;
import android.os.Bundle;
import android.widget.SeekBar;
import androidx.appcompat.app.AppCompatActivity;
import android.util.Log;

import es.antonborri.home_widget.HomeWidgetProvider;
public class TransparencyActivity extends AppCompatActivity {
    private static final String TAG = "TransparencyActivity";

    private static final String PREFS_NAME = "HomeWidgetPreferences";
    private static final String KEY_TRANSPARENCY = "widget_transparency";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Log.d(TAG, "onCreate: Activity started");
        setContentView(R.layout.activity_transparency);
        findViewById(R.id.back_button).setOnClickListener(v -> finish());
        Log.d(TAG, "Back button clicked");

        SeekBar transparencySeekBar = findViewById(R.id.transparency_seekbar);
        Log.d(TAG, "SeekBar initialized");

        SharedPreferences prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        int currentTransparency = prefs.getInt(KEY_TRANSPARENCY, 255); // Fully visible default
        Log.d(TAG, "Current transparency loaded: " + currentTransparency);

        transparencySeekBar.setProgress(currentTransparency);

        transparencySeekBar.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                Log.d(TAG, "SeekBar progress changed: " + progress + ", fromUser: " + fromUser);
                prefs.edit().putInt(KEY_TRANSPARENCY, progress).apply();
                // You can trigger a widget refresh here if you want
                MyHomeWidgetProvider.updateWidget(TransparencyActivity.this);

            }
            @Override public void onStartTrackingTouch(SeekBar seekBar) {}
            @Override public void onStopTrackingTouch(SeekBar seekBar) {}
        });
    }
}
