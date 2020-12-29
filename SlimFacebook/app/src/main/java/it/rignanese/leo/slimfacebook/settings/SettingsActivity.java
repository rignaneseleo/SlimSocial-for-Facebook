package it.rignanese.leo.slimfacebook.settings;

import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.preference.Preference;
import android.preference.PreferenceActivity;
import android.preference.PreferenceFragment;
import android.preference.PreferenceManager;
import android.widget.Toast;

import it.rignanese.leo.slimfacebook.MainActivity;
import it.rignanese.leo.slimfacebook.R;

/**
 * SlimSocial for Facebook is an Open Source app realized by Leonardo Rignanese <rignanese.leo@gmail.com>
 * GNU GENERAL PUBLIC LICENSE  Version 2, June 1991
 * GITHUB: https://github.com/rignaneseleo/SlimSocial-for-Facebook
 */
public class SettingsActivity extends PreferenceActivity implements
        SharedPreferences.OnSharedPreferenceChangeListener {
    private static String appVersion;

    //using a PreferenceFragment along with the PreferenceActivity (see there
    // http://alvinalexander.com/android/android-tutorial-preferencescreen-preferenceactivity-preferencefragment )

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        //get the appVersion
        try {
            appVersion = appVersion();
        } catch (PackageManager.NameNotFoundException e) {
            e.printStackTrace();
        }

        //load the fragment
        getFragmentManager().beginTransaction().replace(android.R.id.content, new MyPreferenceFragment()).commit();
    }

    //read the appVersion
    private String appVersion() throws PackageManager.NameNotFoundException {
        PackageInfo pInfo = getPackageManager().getPackageInfo(getPackageName(), 0);
        return pInfo.versionName;
    }

    @Override
    public void onResume() {
        super.onResume();
        // register the listener
        PreferenceManager.getDefaultSharedPreferences(getApplicationContext()).registerOnSharedPreferenceChangeListener(this);
    }

    @Override
    public void onPause() {
        super.onPause();
        // unregister the listener
        PreferenceManager.getDefaultSharedPreferences(getApplicationContext()).unregisterOnSharedPreferenceChangeListener(this);
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
    }

    @Override
    public void onSharedPreferenceChanged(SharedPreferences sharedPreferences, String key) {
        switch (key) {
            case "pref_recentNewsFirst":
            case "pref_centerTextPosts":
            case "pref_fixedBar":
            case "pref_hideStories":
            case "pref_addSpaceBetweenPosts":
            case "pref_enableMessagesShortcut": {
                Toast.makeText(SettingsActivity.this, R.string.refreshToApply, Toast.LENGTH_SHORT).show();
                break;
            }
            case "pref_doNotDownloadImages":
            case "pref_allowGeolocation":
            case "pref_theme":
            case "pref_textSize": {
                restart();
                break;
            }
            case "pref_notifications": {
                Toast.makeText(SettingsActivity.this, R.string.noNotificationEnjoyLife, Toast.LENGTH_LONG).show();

                break;
            }
        }
    }

    private void restart() {
        // notify user
        Toast.makeText(SettingsActivity.this, R.string.applyingChanges, Toast.LENGTH_SHORT).show();

        // sending intent to onNewIntent() of MainActivity that restarts the app
        Intent intent = new Intent(getApplicationContext(), MainActivity.class);
        intent.putExtra("settingsChanged", true);
        intent.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP);
        startActivity(intent);
    }

    //preference fragment
    public static class MyPreferenceFragment extends PreferenceFragment {
        @Override
        public void onCreate(final Bundle savedInstanceState) {
            super.onCreate(savedInstanceState);
            addPreferencesFromResource(R.xml.settings);//load the layout

            //set the appVersion
            Preference version = findPreference("pref_key_version");
            version.setSummary(appVersion);// set the current version
        }
    }
}

