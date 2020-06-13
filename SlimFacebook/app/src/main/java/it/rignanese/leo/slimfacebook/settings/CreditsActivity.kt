package it.rignanese.leo.slimfacebook.settings

import android.os.Bundle
import android.preference.PreferenceActivity
import android.preference.PreferenceFragment
import it.rignanese.leo.slimfacebook.R

/**
 * SlimSocial for Facebook is an Open Source app realized by Leonardo Rignanese <rignanese.leo></rignanese.leo>@gmail.com>
 * GNU GENERAL PUBLIC LICENSE  Version 2, June 1991
 * GITHUB: https://github.com/rignaneseleo/SlimSocial-for-Facebook
 */
class CreditsActivity : PreferenceActivity() {
    override fun onCreate(savedInstanceState: Bundle) {
        super.onCreate(savedInstanceState)

        //load the fragment
        fragmentManager.beginTransaction().replace(android.R.id.content, MyPreferenceFragment()).commit()
    }

    //preference fragment
    class MyPreferenceFragment : PreferenceFragment() {
        override fun onCreate(savedInstanceState: Bundle) {
            super.onCreate(savedInstanceState)
            addPreferencesFromResource(R.xml.credits) //load the layout
        }
    }
}