package it.rignanese.leo.slimfacebook.webview;

import android.annotation.TargetApi;
import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.preference.PreferenceManager;
import android.util.Log;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Toast;

import it.rignanese.leo.slimfacebook.R;



/**
 * SlimSocial for Facebook is an Open Source app realized by Leonardo Rignanese
 * GNU GENERAL PUBLIC LICENSE  Version 2, June 1991
 */
public class MyWebViewClient extends WebViewClient {

    static Context context;
    final SharedPreferences savedPreferences; // get shared preferences

    public MyWebViewClient(Context context) {
        this.context = context;
        savedPreferences = PreferenceManager.getDefaultSharedPreferences(context);
    }

    // when there isn't a connetion
    @Override
    public void onReceivedError(WebView view, int errorCode, String description, String failingUrl) {
        Context context = view.getContext();
        String summary = "<h1 style='text-align:center; padding-top:15%; font-size:70px;'>" +
                context.getString(R.string.titleNoConnection) +
                "</h1> <h3 style='text-align:center; padding-top:1%; font-style: italic;font-size:50px;'>" +
                context.getString(R.string.descriptionNoConnection) +
                "</h3>  <h5 style='font-size:30px; text-align:center; padding-top:80%; opacity: 0.3;'>" +
                context.getString(R.string.awards) +
                "</h5>";
        view.loadData(summary, "text/html; charset=utf-8", "utf-8");//load a custom html page
    }

    // when I click in a external link
    @Override
    public boolean shouldOverrideUrlLoading(WebView view, String url) {
        Context context = view.getContext();
        if (url == null
                || Uri.parse(url).getHost().endsWith("facebook.com")
                || Uri.parse(url).getHost().endsWith("m.facebook.com")
                || url.contains(".gif")) {//it is a normal url
            return false; //url is ok
        } else {
            if (Uri.parse(url).getHost().endsWith("fbcdn.net")) {//it is an image
                //TODO add the possibility to download and share directly

                Toast.makeText(context, context.getString(R.string.downloadOrShareWithBrowser),
                        Toast.LENGTH_LONG).show();
                //TODO get bitmap from url
            }

            //if the link doesn't contain 'facebook.com', open it using the browser
            try {
                context.startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url)));
            } catch (ActivityNotFoundException e) {//this prevents the crash
                Log.e("shouldOverrideUrlLoad", "" + e.getMessage());
                e.printStackTrace();
            }
            return true;
        }//https://www.facebook.com/dialog/return/close?#_=_
    }

    @Override
    public void onPageFinished(WebView view, String url) {
        Context context = view.getContext();
        //load the css customizations
        String css = "";
        if (savedPreferences.getBoolean("pref_centerTextPosts", false)) { css += context.getString(R.string.centerTextPosts); }
        if (savedPreferences.getBoolean("pref_addSpaceBetweenPosts", false)) { css += context.getString(R.string.addSpaceBetweenPosts); }

        switch (savedPreferences.getString("pref_theme", "standard")) {
            case "DarkTheme":
            case "DarkNoBar": { css += context.getString(R.string.blackTheme); }
            default:
                break;
        }

        if (savedPreferences.getBoolean("pref_fixedBar", true)) {
            css += context.getString(R.string.fixedBar);//get the first part

            int navbar = 0;//default value
            int resourceId = context.getResources().getIdentifier("status_bar_height", "dimen", "android");//get id
            if (resourceId > 0) {//if there is
                navbar = context.getResources().getDimensionPixelSize(resourceId);//get the dimension
            }
            float density = context.getResources().getDisplayMetrics().density;
            int barHeight = (int) ((context.getResources().getDisplayMetrics().heightPixels - navbar - 44) / density);

            css += ".flyout { max-height:" + barHeight + "px; overflow-y:scroll;  }";//without this doen-t scroll
        }

        //apply the customizations
        view.loadUrl("javascript:function addStyleString(str) { var node = document.createElement('style'); node.innerHTML = " +
                "str; document.body.appendChild(node); } addStyleString('" + css + "');");

        //finish the load
        super.onPageFinished(view, url);
    }
    //END management of loading
}
