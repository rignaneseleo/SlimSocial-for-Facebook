package it.rignanese.leo.slimfacebook.utility

import android.content.Context
import android.content.res.Configuration

/**
 * This class is made from FaceSlim
 * https://github.com/indywidualny/FaceSlim
 */
object Dimension {
    // get navigation bar height
    private fun getNavigationBarHeight(context: Context, orientation: Int): Int {
        val resources = context.resources
        val resourceId = resources.getIdentifier(if (orientation == Configuration.ORIENTATION_PORTRAIT) "navigation_bar_height" else "navigation_bar_height_landscape", "dimen", "android")
        return if (resourceId > 0) {
            resources.getDimensionPixelSize(resourceId)
        } else 0
    }

    // window's height minus navbar minus extra top padding, all divided by density
    @JvmStatic
    fun heightForFixedFacebookNavbar(context: Context): Int {
        val navbar = getNavigationBarHeight(context, context.resources.configuration.orientation)
        val density = context.resources.displayMetrics.density
        return ((context.resources.displayMetrics.heightPixels - navbar - 44) / density).toInt()
    }
}