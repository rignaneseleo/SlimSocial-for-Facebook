package it.rignanese.leo.slimfacebook;

/**
 * SlimSocial for Facebook is an Open Source app realized by Leonardo Rignanese
 * GNU GENERAL PUBLIC LICENSE  Version 2, June 1991
 */

import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.preference.Preference;
import android.preference.PreferenceActivity;
import android.preference.PreferenceFragment;



public class ShowSettingsActivity extends PreferenceActivity {

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