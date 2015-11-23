package it.rignanese.leo.slimfacebook;

/**
 * SlimFacebook is an Open Source app realized by Leonardo Rignanese
 * GNU GENERAL PUBLIC LICENSE  Version 2, June 1991
 */


import android.os.Bundle;
import android.preference.PreferenceActivity;


public class ShowSettingsActivity extends PreferenceActivity {
        @Override
        protected void onCreate(Bundle savedInstanceState) {
            // TODO Auto-generated method stub
            super.onCreate(savedInstanceState);
            addPreferencesFromResource(R.layout.preferences);
        }
    }