package it.rignanese.leo.slimfacebook.utils;

import android.content.Context;
import android.preference.SwitchPreference;
import android.util.AttributeSet;

/**
 * SlimSocial for Facebook is an Open Source app realized by Leonardo Rignanese <rignanese.leo@gmail.com>
 * GNU GENERAL PUBLIC LICENSE  Version 2, June 1991
 * GITHUB: https://github.com/rignaneseleo/SlimSocial-for-Facebook
 */
public class SwitchWithoutBugs extends SwitchPreference {
    public SwitchWithoutBugs(Context context) {
        super(context);
    }

    public SwitchWithoutBugs(Context context, AttributeSet attrs) {
        super(context, attrs);
    }

    public SwitchWithoutBugs(Context context, AttributeSet attrs, int defStyle) {
        super(context, attrs, defStyle);
    }
}