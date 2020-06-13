package it.rignanese.leo.slimfacebook.settings

import android.content.Intent
import android.content.SharedPreferences
import android.content.SharedPreferences.OnSharedPreferenceChangeListener
import android.content.pm.PackageManager
import android.os.Bundle
import android.preference.PreferenceActivity
import android.preference.PreferenceFragment
import android.preference.PreferenceManager
import android.widget.Toast
import it.rignanese.leo.slimfacebook.MainActivity
import it.rignanese.leo.slimfacebook.R
import it.rignanese.leo.slimfacebook.settings.SettingsActivity

/**
 * SlimSocial for Facebook is an Open Source app realized by Leonardo Rignanese <rignanese.leo></rignanese.leo>@gmail.com>
 * GNU GENERAL PUBLIC LICENSE  Version 2, June 1991
 * GITHUB: https://github.com/rignaneseleo/SlimSocial-for-Facebook
 */
class SettingsActivity : PreferenceActivity(), OnSharedPreferenceChangeListener {
    //using a PreferenceFragment along with the PreferenceActivity (see there
    // http://alvinalexander.com/android/android-tutorial-preferencescreen-preferenceactivity-preferencefragment )
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        //get the appVersion
        try {
            appVersion = appVersion()
        } catch (e: PackageManager.NameNotFoundException) {
            e.printStackTrace()
        }

        //load the fragment
        fragmentManager.beginTransaction().replace(android.R.id.content, MyPreferenceFragment()).commit()
    }

    //read the appVersion
    @Throws(PackageManager.NameNotFoundException::class)
    private fun appVersion(): String {
        val pInfo = packageManager.getPackageInfo(packageName, 0)
        return pInfo.versionName
    }

    public override fun onResume() {
        super.onResume()
        // register the listener
        PreferenceManager.getDefaultSharedPreferences(applicationContext).registerOnSharedPreferenceChangeListener(this)
    }

    public override fun onPause() {
        super.onPause()
        // unregister the listener
        PreferenceManager.getDefaultSharedPreferences(applicationContext).unregisterOnSharedPreferenceChangeListener(this)
    }

    public override fun onDestroy() {
        super.onDestroy()
    }

    override fun onSharedPreferenceChanged(sharedPreferences: SharedPreferences, key: String) {
        when (key) {
            "pref_recentNewsFirst", "pref_centerTextPosts", "pref_fixedBar", "pref_addSpaceBetweenPosts", "pref_enableMessagesShortcut" -> {
                Toast.makeText(this@SettingsActivity, R.string.refreshToApply, Toast.LENGTH_SHORT).show()
            }
            "pref_doNotDownloadImages", "pref_allowGeolocation", "pref_theme", "pref_textSize" -> {
                restart()
            }
            "pref_notifications" -> {
                Toast.makeText(this@SettingsActivity, R.string.noNotificationEnjoyLife, Toast.LENGTH_LONG).show()
            }
        }
    }

    private fun restart() {
        // notify user
        Toast.makeText(this@SettingsActivity, R.string.applyingChanges, Toast.LENGTH_SHORT).show()

        // sending intent to onNewIntent() of MainActivity that restarts the app
        val intent = Intent(applicationContext, MainActivity::class.java)
        intent.putExtra("settingsChanged", true)
        intent.flags = Intent.FLAG_ACTIVITY_CLEAR_TOP
        startActivity(intent)
    }

    //preference fragment
    class MyPreferenceFragment : PreferenceFragment() {
        override fun onCreate(savedInstanceState: Bundle?) {
            super.onCreate(savedInstanceState)
            addPreferencesFromResource(R.xml.settings) //load the layout

            //set the appVersion
            val version = findPreference("pref_key_version")
            version.summary = appVersion // set the current version
        }
    }

    companion object {
        private var appVersion: String? = null
    }
}