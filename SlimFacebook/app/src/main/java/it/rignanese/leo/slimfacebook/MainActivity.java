/*
SlimFacebook is an Open Source app realized by Leonardo Rignanese
 GNU GENERAL PUBLIC LICENSE  Version 2, June 1991
*/

package it.rignanese.leo.slimfacebook;

import android.content.Intent;
import android.graphics.Bitmap;
import android.net.Uri;
import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;
import android.view.KeyEvent;
import android.view.Menu;
import android.view.MenuItem;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;



public class MainActivity extends AppCompatActivity {

    private WebView webViewFacebook;//the main webView where is shown facebook
    private WebSettings webViewFacebookSettings;//the settings of the webview

    private Menu optionsMenu;//contains the main menu

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        // set up the webView
        webViewFacebook = (WebView) findViewById(R.id.webView);
        webViewFacebookSettings = webViewFacebook.getSettings();

        webViewFacebookSettings.setCacheMode(WebSettings.LOAD_NO_CACHE);//to make the webview faster
        webViewFacebookSettings.setJavaScriptEnabled(true);//enable js

        webViewFacebook.loadUrl(getString(R.string.urlFacebookMobile));//load m.facebook.com


        //WebViewClient that is the client callback.
        webViewFacebook.setWebViewClient(new WebViewClient() {//advanced set up

            // when there isn't a connetion
            public void onReceivedError(WebView view, int errorCode, String description, String failingUrl) {
                String summary = "<html><head></head><body><h1 style='text-align:center; padding-top:15%;'>" + getString(R.string.titleNoConnection) + "</h1> <h3 style='text-align:center; padding-top:1%; font-style: italic;'>" + getString(R.string.descriptionNoConnection) + "</h3>  <h5 style='text-align:center; padding-top:80%; opacity: 0.3;'>" + getString(R.string.awards) + "</h5></body></html>";
                webViewFacebook.loadData(summary, "text/html", null);//load a custom html page
            }

            // when I click in a external link
            public boolean shouldOverrideUrlLoading(WebView view, String url) {
                if (url == null || url.contains("facebook.com")) {
                    return false;
                } else {//if the link doesn't contain 'facebook.com', open it using the browser
                    view.getContext().startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url)));
                    return true;
                }
            }

            //START management of loading
            @Override
            public void onPageStarted(WebView view, String url, Bitmap favicon) {
                // show you progress image
                final MenuItem refreshItem = optionsMenu.findItem(R.id.refresh);
                refreshItem.setActionView(R.layout.circular_progress_bar);
                super.onPageStarted(view, url, favicon);
            }

            @Override
            public void onPageFinished(WebView view, String url) {
                // hide your progress image
                final MenuItem refreshItem = optionsMenu.findItem(R.id.refresh);
                refreshItem.setActionView(null);
                super.onPageFinished(view, url);
            }
            //END management of loading

        });

        //WebChromeClient for handling all chrome functions.
        webViewFacebook.setWebChromeClient(new WebChromeClient());//for a future usage
    }


    // manage the back button
    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        if (event.getAction() == KeyEvent.ACTION_DOWN) {
            switch (keyCode) {
                case KeyEvent.KEYCODE_BACK:
                    if (webViewFacebook.canGoBack()) {
                        webViewFacebook.goBack();
                    } else {
                        // exit
                        finish();
                    }
                    return true;
            }
        }
        return super.onKeyDown(keyCode, event);
    }

    //manage the tap on the menu's items
    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        int id = item.getItemId();
        switch (id) {
            case R.id.top: {//scroll on the top of the page
                webViewFacebook.scrollTo(0, 0);
                break;
            }
            case R.id.openInBrowser: {//open the actual page into using the browser
                webViewFacebook.getContext().startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(webViewFacebook.getUrl())));
                break;
            }
            case R.id.refresh: {//refresh the page
                webViewFacebook.reload();
                break;
            }
            case R.id.home: {//go to the home
                webViewFacebook.loadUrl(getString(R.string.urlFacebookMobile));
                break;
            }
            case R.id.share: {//share this app
                Intent sharingIntent = new Intent(android.content.Intent.ACTION_SEND);
                sharingIntent.setType("text/plain");
                sharingIntent.putExtra(android.content.Intent.EXTRA_SUBJECT, getResources().getString(R.string.share));
                sharingIntent.putExtra(android.content.Intent.EXTRA_TEXT, getResources().getString(R.string.downloadInstruction));
                startActivity(Intent.createChooser(sharingIntent, getResources().getString(R.string.share)));
                break;
            }
//            case R.id.settings: {//share this app
//                startActivity(new Intent(this, ShowSettingsActivity.class));
//                return true;
//            }

            default:
                break;
        }
        return super.onOptionsItemSelected(item);
    }

    //add my menu
    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        this.optionsMenu = menu;
        // Inflate the menu; this adds items to the action bar if it is present.
        getMenuInflater().inflate(R.menu.menu_main, menu);
        return true;
    }
}
