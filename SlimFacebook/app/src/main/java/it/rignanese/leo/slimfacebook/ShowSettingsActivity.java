package it.rignanese.leo.slimfacebook;

/**
 * SlimSocial for Facebook is an Open Source app realized by Leonardo Rignanese
 * GNU GENERAL PUBLIC LICENSE  Version 2, June 1991
 */

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



public class ShowSettingsActivity extends PreferenceActivity implements
        SharedPreferences.OnSharedPreferenceChangeListener {

    static String appVersion;

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
    public void onSharedPreferenceChanged(SharedPreferences sharedPreferences, String key) {
        switch (key) {
            case "pref_doNotDownloadImages":
            case "pref_allowGeolocation": {
                restart();
            }
        }
    }
    private void restart() {
        // notify user
        Toast.makeText(ShowSettingsActivity.this, R.string.applyingChanges, Toast.LENGTH_SHORT).show();

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
            addPreferencesFromResource(R.xml.preferences);//load the layout

            //set the appVersion
            Preference version = findPreference("pref_key_version");
            version.setSummary(appVersion);// set the current version
        }
    }


    //read the appVersion
    public String appVersion() throws PackageManager.NameNotFoundException {
        PackageInfo pInfo = getPackageManager().getPackageInfo(getPackageName(), 0);
        String version = pInfo.versionName;
        return version;
    }
}