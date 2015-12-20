/*
SlimFacebook is an Open Source app realized by Leonardo Rignanese
 GNU GENERAL PUBLIC LICENSE  Version 2, June 1991


 special thanks to https://github.com/indywidualny/FaceSlim
 some of the code is their work!
*/

package it.rignanese.leo.slimfacebook;


import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.preference.ListPreference;
import android.preference.Preference;
import android.preference.PreferenceManager;
import android.support.v4.widget.SwipeRefreshLayout;
import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;
import android.view.KeyEvent;
import android.view.Menu;
import android.view.MenuItem;
import android.webkit.GeolocationPermissions;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Toast;
import android.annotation.TargetApi;
import android.app.Activity;
import android.os.Build;
import android.os.Environment;
import android.provider.MediaStore;

import java.io.File;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.Date;



public class MainActivity extends AppCompatActivity {

    SwipeRefreshLayout swipeRefreshLayout;//the layout that allows the swipe refresh

    private WebView webViewFacebook;//the main webView where is shown facebook

    //to upload files
    public static final int INPUT_FILE_REQUEST_CODE = 1;
    public static final String EXTRA_FROM_NOTIFICATION = "EXTRA_FROM_NOTIFICATION";
    private ValueCallback<Uri[]> mFilePathCallback;
    private String mCameraPhotoPath;

    private Menu optionsMenu;//contains the main menu

    private SharedPreferences savedPreferences;//contains all the values of saved preferences

    boolean noConnectionError = false;//flag: is true if there is a connection error and it should be reload not the error page but the last useful
    boolean swipeRefresh = false;

    boolean isSharer = false;//flag: true if the app is called from sharer
    String urlSharer = "";//to save the url got from the sharer

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // setup the sharedPreferences
        savedPreferences = PreferenceManager.getDefaultSharedPreferences(this);

        //setup the theme
        //int savedThemeId = Integer.parseInt(savedPreferences.getString("pref_key_theme8", "2131361965"));//get the last saved theme id
        //setTheme(savedThemeId);//this refresh the theme if necessary
        // TODO fix the change of status bar

        setContentView(R.layout.activity_main);//load the layout


        // setup the refresh layout
        swipeRefreshLayout = (SwipeRefreshLayout) findViewById(R.id.swipe_container);
        swipeRefreshLayout.setColorSchemeResources(R.color.officialBlueFacebook, R.color.darkBlueSlimFacebookTheme);// set the colors
        swipeRefreshLayout.setOnRefreshListener(new SwipeRefreshLayout.OnRefreshListener() {
            @Override
            public void onRefresh() {
                refreshPage();//reload the page
                swipeRefresh = true;
            }
        });


        /** get a subject and text and check if this is a link trying to be shared */
        String sharedSubject = getIntent().getStringExtra(Intent.EXTRA_SUBJECT);
        String sharedUrl = getIntent().getStringExtra(Intent.EXTRA_TEXT);

        // if we have a valid URL that was shared by us, open the sharer
        if (sharedUrl != null) {
            if (!sharedUrl.equals("")) {
                // check if the URL being shared is a proper web URL
                if (!sharedUrl.startsWith("http://") || !sharedUrl.startsWith("https://")) {
                    // if it's not, let's see if it includes an URL in it (prefixed with a message)
                    int startUrlIndex = sharedUrl.indexOf("http:");
                    if (startUrlIndex > 0) {
                        // seems like it's prefixed with a message, let's trim the start and get the URL only
                        sharedUrl = sharedUrl.substring(startUrlIndex);
                    }
                }
                // final step, set the proper Sharer...
                urlSharer = String.format("https://m.facebook.com/sharer.php?u=%s&t=%s", sharedUrl, sharedSubject);
                // ... and parse it just in case
                urlSharer = Uri.parse(urlSharer).toString();
                isSharer = true;
            }
        }


        // setup the webView
        webViewFacebook = (WebView) findViewById(R.id.webView);
        setUpWebViewDefaults(webViewFacebook);//set the settings

        if (isSharer) {//if is a share request
            webViewFacebook.loadUrl(urlSharer);//load the sharer url
            isSharer = false;
        } else goHome();//load homepage


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
                if (url == null || url.contains("facebook.com")) {//// TODO: clear these conditions
                    //url is ok
                    return false;
                } else {
                    if (url.contains("https://scontent")) {
                        //TODO add the possibility to download and share directly

                        Toast.makeText(getApplicationContext(), getString(R.string.downloadOrShareWithBrowser),
                                Toast.LENGTH_LONG).show();
                        //TODO get bitmap from url



                        Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
                        startActivity(intent);
                        return true;
                    }

                    //if the link doesn't contain 'facebook.com', open it using the browser
                    startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url)));
                    return true;
                }//https://www.facebook.com/dialog/return/close?#_=_
            }



            //START management of loading
            @Override
            public void onPageStarted(WebView view, String url, Bitmap favicon) {
                //TODO when I push on messages, open messanger
//                if(url!=null){
//                    if (url.contains("soft=messages") || url.contains("facebook.com/messages")) {
//                        Toast.makeText(getApplicationContext(),"Open Messanger",
//                                Toast.LENGTH_SHORT).show();
//                        startActivity(new Intent(getPackageManager().getLaunchIntentForPackage("com.facebook.orca")));//messanger
//                    }
//                }


                // show you progress image
                if (!swipeRefresh) {
                    if (optionsMenu != null) {//TODO fix this. Sometimes it is null and I don't know why
                        final MenuItem refreshItem = optionsMenu.findItem(R.id.refresh);
                        refreshItem.setActionView(R.layout.circular_progress_bar);
                    }
                }
                swipeRefresh = false;
                super.onPageStarted(view, url, favicon);
            }

            @Override
            public void onPageFinished(WebView view, String url) {
                if (optionsMenu != null) {//TODO fix this. Sometimes it is null and I don't know why
                    final MenuItem refreshItem = optionsMenu.findItem(R.id.refresh);
                    refreshItem.setActionView(null);
                }

                super.onPageFinished(view, url);

                swipeRefreshLayout.setRefreshing(false); //when the page is loaded, stop the refreshing
            }
            //END management of loading

        });

        //WebChromeClient for handling all chrome functions.
        webViewFacebook.setWebChromeClient(new WebChromeClient() {
            //to the geolocalizzation
            public void onGeolocationPermissionsShowPrompt(String origin, GeolocationPermissions.Callback callback) {
                callback.invoke(origin, true, false);
                //todo notify when the gps is used
            }

            //to upload files
            //thanks to gauntface
            //https://github.com/GoogleChrome/chromium-webview-samples
            public boolean onShowFileChooser(
                    //todo fix the compatibility with all versions (4.4.4 specially)
                    WebView webView, ValueCallback<Uri[]> filePathCallback,
                    WebChromeClient.FileChooserParams fileChooserParams) {
                if (mFilePathCallback != null) {
                    mFilePathCallback.onReceiveValue(null);
                }
                mFilePathCallback = filePathCallback;

                Intent takePictureIntent = new Intent(MediaStore.ACTION_IMAGE_CAPTURE);
                if (takePictureIntent.resolveActivity(getBaseContext().getPackageManager()) != null) {
                    // Create the File where the photo should go
                    File photoFile = null;
                    try {
                        photoFile = createImageFile();
                        takePictureIntent.putExtra("PhotoPath", mCameraPhotoPath);
                    } catch (IOException ex) {
                        // Error occurred while creating the File
                    }

                    // Continue only if the File was successfully created
                    if (photoFile != null) {
                        mCameraPhotoPath = "file:" + photoFile.getAbsolutePath();
                        takePictureIntent.putExtra(MediaStore.EXTRA_OUTPUT,
                                Uri.fromFile(photoFile));
                    } else {
                        takePictureIntent = null;
                    }
                }

                Intent contentSelectionIntent = new Intent(Intent.ACTION_GET_CONTENT);
                contentSelectionIntent.addCategory(Intent.CATEGORY_OPENABLE);
                contentSelectionIntent.setType("image/*");

                Intent[] intentArray;
                if (takePictureIntent != null) {
                    intentArray = new Intent[]{takePictureIntent};
                } else {
                    intentArray = new Intent[0];
                }

                Intent chooserIntent = new Intent(Intent.ACTION_CHOOSER);
                chooserIntent.putExtra(Intent.EXTRA_INTENT, contentSelectionIntent);
                chooserIntent.putExtra(Intent.EXTRA_TITLE, "Image Chooser");
                chooserIntent.putExtra(Intent.EXTRA_INITIAL_INTENTS, intentArray);

                startActivityForResult(chooserIntent, INPUT_FILE_REQUEST_CODE);

                return true;
            }
        });
    }

    // app is already running and gets a new intent (used to share link without open another activity
    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);

        // grab an url if opened by clicking a link
        String webViewUrl = getIntent().getDataString();

        /** get a subject and text and check if this is a link trying to be shared */
        String sharedSubject = getIntent().getStringExtra(Intent.EXTRA_SUBJECT);
        String sharedUrl = getIntent().getStringExtra(Intent.EXTRA_TEXT);

        // if we have a valid URL that was shared by us, open the sharer
        if (sharedUrl != null) {
            if (!sharedUrl.equals("")) {
                // check if the URL being shared is a proper web URL
                if (!sharedUrl.startsWith("http://") || !sharedUrl.startsWith("https://")) {
                    // if it's not, let's see if it includes an URL in it (prefixed with a message)
                    int startUrlIndex = sharedUrl.indexOf("http:");
                    if (startUrlIndex > 0) {
                        // seems like it's prefixed with a message, let's trim the start and get the URL only
                        sharedUrl = sharedUrl.substring(startUrlIndex);
                    }
                }
                // final step, set the proper Sharer...
                webViewUrl = String.format("https://m.facebook.com/sharer.php?u=%s&t=%s", sharedUrl, sharedSubject);
                // ... and parse it just in case
                webViewUrl = Uri.parse(webViewUrl).toString();
            }
        }
        webViewFacebook.loadUrl(webViewUrl);
    }

    //*********************** UPLOAD FILES ****************************
    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        //used to upload files
        //thanks to gauntface
        //https://github.com/GoogleChrome/chromium-webview-samples
        if (requestCode != INPUT_FILE_REQUEST_CODE || mFilePathCallback == null) {
            super.onActivityResult(requestCode, resultCode, data);
            return;
        }

        Uri[] results = null;

        // Check that the response is a good one
        if (resultCode == Activity.RESULT_OK) {
            if (data == null) {
                // If there is not data, then we may have taken a photo
                if (mCameraPhotoPath != null) {
                    results = new Uri[]{Uri.parse(mCameraPhotoPath)};
                }
            } else {
                String dataString = data.getDataString();
                if (dataString != null) {
                    results = new Uri[]{Uri.parse(dataString)};
                }
            }
        }

        mFilePathCallback.onReceiveValue(results);
        mFilePathCallback = null;
        return;
    }

    @TargetApi(Build.VERSION_CODES.HONEYCOMB)
    private File createImageFile() throws IOException {
        // Create an image file name
        String timeStamp = new SimpleDateFormat("yyyyMMdd_HHmmss").format(new Date());
        String imageFileName = "JPEG_" + timeStamp + "_";
        File storageDir = Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_PICTURES);
        File imageFile = File.createTempFile(
                imageFileName,  /* prefix */
                ".jpg",         /* suffix */
                storageDir      /* directory */
        );
        return imageFile;
    }

    //*********************** DOWNLOAD PHOTOS ****************************
//    public Bitmap getBitmapFromURL(String src) {
//        try {
//            URL url = new URL(src);
//            HttpURLConnection connection = (HttpURLConnection) url.openConnection();
//            connection.setDoInput(true);
//            connection.connect();
//            InputStream input = connection.getInputStream();
//            Bitmap myBitmap = BitmapFactory.decodeStream(input);
//            return myBitmap;
//        } catch (IOException e) {
//            e.printStackTrace();
//            return null;
//        }
//    }

    //*********************** KEY ****************************
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


    //*********************** MENU ****************************
    //add my menu
    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        optionsMenu = menu;
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


    //*********************** WEBVIEW FACILITIES ****************************
    private void setUpWebViewDefaults(WebView webView) {
        WebSettings settings = webView.getSettings();

        // Enable Javascript
        settings.setJavaScriptEnabled(true);

        //to make the webview faster
        //settings.setCacheMode(WebSettings.LOAD_NO_CACHE);


        // Use WideViewport and Zoom out if there is no viewport defined
        settings.setUseWideViewPort(true);
        settings.setLoadWithOverviewMode(true);

        settings.setGeolocationDatabasePath(getBaseContext().getFilesDir().getPath() );

        settings.setLoadsImagesAutomatically(!savedPreferences.getBoolean("pref_downloadImages", false));//to save data
        //todo setLoadsImagesAutomatically without restart the app

        // Enable pinch to zoom without the zoom buttons
        settings.setBuiltInZoomControls(true);

        if (Build.VERSION.SDK_INT > Build.VERSION_CODES.HONEYCOMB) {
            // Hide the zoom controls for HONEYCOMB+
            settings.setDisplayZoomControls(false);
        }

        // Enable remote debugging via chrome://inspect
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            WebView.setWebContentsDebuggingEnabled(true);
        }
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


