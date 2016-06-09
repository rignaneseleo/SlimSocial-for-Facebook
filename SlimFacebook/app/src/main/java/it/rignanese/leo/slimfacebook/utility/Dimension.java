package it.rignanese.leo.slimfacebook.utility;

import android.content.Context;
import android.content.res.Configuration;
import android.content.res.Resources;

/**
 * This class is made from FaceSlim
 * https://github.com/indywidualny/FaceSlim
 */
public class Dimension {
    // get navigation bar height
    private static int getNavigationBarHeight(Context context, int orientation) {
        Resources resources = context.getResources();
        int resourceId = resources.getIdentifier(orientation == Configuration.ORIENTATION_PORTRAIT ?
                "navigation_bar_height" : "navigation_bar_height_landscape", "dimen", "android");
        if (resourceId > 0) {
            return resources.getDimensionPixelSize(resourceId);
        }
        return 0;
    }

    // window's height minus navbar minus extra top padding, all divided by density
    public static int heightForFixedFacebookNavbar(Context context) {
        final int navbar = getNavigationBarHeight(context, context.getResources().getConfiguration().orientation);
        final float density = context.getResources().getDisplayMetrics().density;
        return (int) ((context.getResources().getDisplayMetrics().heightPixels - navbar - 44) / density);
    }
}
