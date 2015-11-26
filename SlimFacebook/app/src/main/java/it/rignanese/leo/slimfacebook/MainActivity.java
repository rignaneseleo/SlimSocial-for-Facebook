/*
SlimFacebook is an Open Source app realized by Leonardo Rignanese
 GNU GENERAL PUBLIC LICENSE  Version 2, June 1991
*/

package it.rignanese.leo.slimfacebook;


import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.net.Uri;
import android.preference.PreferenceManager;
import android.support.v4.widget.SwipeRefreshLayout;
import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;
import android.view.KeyEvent;
import android.view.Menu;
import android.view.MenuItem;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Toast;



public class MainActivity extends AppCompatActivity {

    SwipeRefreshLayout swipeRefreshLayout;//the layout that allows the swipe refresh

    private WebView webViewFacebook;//the main webView where is shown facebook
    private WebSettings webViewFacebookSettings;//the settings of the webview

    private Menu optionsMenu;//contains the main menu

    private SharedPreferences savedPreferences;//contains all the values of saved preferences

    boolean noConnectionError = false;//flag: is true if there is a connection error and it should be reload not the error page but the last useful
    boolean swipeRefresh = false;


    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // setup the sharedPreferences
        savedPreferences = PreferenceManager.getDefaultSharedPreferences(this);

        //setup the theme
        int savedThemeId = Integer.parseInt(savedPreferences.getString("pref_key_theme8", "2131361965"));//get the last saved theme id
        setTheme(savedThemeId);//this refresh the theme if necessary
        setContentView(R.layout.activity_main);//load the layout

        // setup the refresh layout
        swipeRefreshLayout = (SwipeRefreshLayout) findViewById(R.id.swipe_container);
        //swipeRefreshLayout.setColorSchemeResources(R.color.officialBlueFacebookok, R.color.blueSlimFacebook, R.color.darkBlueSlimFacebook);// set
        // the colors
        swipeRefreshLayout.setOnRefreshListener(new SwipeRefreshLayout.OnRefreshListener() {
            @Override
            public void onRefresh() {
                refreshPage();//reload the page
                swipeRefresh = true;
            }
        });

        // setup the webView
        webViewFacebook = (WebView) findViewById(R.id.webView);
        webViewFacebookSettings = webViewFacebook.getSettings();

        webViewFacebookSettings.setCacheMode(WebSettings.LOAD_NO_CACHE);//to make the webview faster
        webViewFacebookSettings.setJavaScriptEnabled(true);//enable js
        webViewFacebookSettings.setDefaultTextEncodingName("utf-8");

        //load homepage
        goHome();

        //WebViewClient that is the client callback.
        webViewFacebook.setWebViewClient(new WebViewClient() {//advanced set up

            // when there isn't a connetion
            public void onReceivedError(WebView view, int errorCode, String description, String failingUrl) {
                String summary = "<html><head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\" /></head><body><h1 " +
                        "style='text-align:center; padding-top:15%;'>" + getString(R.string.titleNoConnection) + "</h1> <h3 style='text-align:center; padding-top:1%; font-style: italic;'>" + getString(R.string.descriptionNoConnection) + "</h3>  <h5 style='text-align:center; padding-top:80%; opacity: 0.3;'>" + getString(R.string.awards) + "</h5></body></html>";
                webViewFacebook.loadData(summary, "text/html; charset=utf-8", "utf-8");//load a custom html page

                noConnectionError = true;
                swipeRefreshLayout.setRefreshing(false); //when the page is loaded, stop the refreshing
            }

            // when I click in a external link
            public boolean shouldOverrideUrlLoading(WebView view, String url) {
                if (url == null || url.contains("facebook.com")) {
                    return false;
                } else {
                    if (url.contains("https://scontent")) {
                        Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
                        startActivity(intent);

                        // to add the possibility to download
                        return false;
                    } else {
                        //if the link doesn't contain 'facebook.com', open it using the browser
                        startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url)));
                        return true;
                    }
                }
            }

            //START management of loading
            @Override
            public void onPageStarted(WebView view, String url, Bitmap favicon) {
                // show you progress image
                if (!swipeRefresh) {
                    final MenuItem refreshItem = optionsMenu.findItem(R.id.refresh);
                    refreshItem.setActionView(R.layout.circular_progress_bar);
                }
                swipeRefresh = false;
                super.onPageStarted(view, url, favicon);
            }

            @Override
            public void onPageFinished(WebView view, String url) {
                // hide your progress image
                final MenuItem refreshItem = optionsMenu.findItem(R.id.refresh);
                refreshItem.setActionView(null);
                super.onPageFinished(view, url);

                swipeRefreshLayout.setRefreshing(false); //when the page is loaded, stop the refreshing
            }
            //END management of loading

        });

        //WebChromeClient for handling all chrome functions.
        //webViewFacebook.setWebChromeClient(new WebChromeClient());//for a future usage
    }

    // management the back button
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


    //add my menu
    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        this.optionsMenu = menu;
        // Inflate the menu; this adds items to the action bar if it is present.
        getMenuInflater().inflate(R.menu.menu_main, menu);
        return true;
    }
    //management the tap on the menu's items
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
                refreshPage();
                break;
            }
            case R.id.home: {//go to the home
                goHome();
                break;
            }
            case R.id.share: {//share this app
                Intent sharingIntent = new Intent(android.content.Intent.ACTION_SEND);
                sharingIntent.setType("text/plain");
                sharingIntent.putExtra(android.content.Intent.EXTRA_TEXT, getResources().getString(R.string.downloadInstruction));
                startActivity(Intent.createChooser(sharingIntent, getResources().getString(R.string.share)));

                Toast.makeText(getApplicationContext(), getResources().getString(R.string.thanks),
                        Toast.LENGTH_SHORT).show();
                break;
            }
            case R.id.settings: {//open settings
                startActivity(new Intent(this, ShowSettingsActivity.class));
                return true;
            }

            default:
                break;
        }
        return super.onOptionsItemSelected(item);
    }


    private void goHome() {
        if (savedPreferences.getBoolean("pref_recentNewsFirst", false)) {
            webViewFacebook.loadUrl(getString(R.string.urlFacebookMobile) + "?sk=h_chr");//load .facebook.com/home.php
        } else {
            webViewFacebook.loadUrl(getString(R.string.urlFacebookMobile) + "?sk=h_nor");//load m.facebook.com
        }
    }
    private void refreshPage() {
        if (noConnectionError) {
            webViewFacebook.goBack();
            noConnectionError = false;
        } else webViewFacebook.reload();
    }
}


