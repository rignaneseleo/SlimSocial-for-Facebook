/*
SlimSocial for Facebook is an Open Source app realized by Leonardo Rignanese
 GNU GENERAL PUBLIC LICENSE  Version 2, June 1991


!!!!!!!!!!!!!!! Special thanks to https://github.com/indywidualny/FaceSlim !!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!! I've token some inspiration an code from their work!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
*/

package it.rignanese.leo.slimfacebook;


import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.res.Resources;
import android.graphics.Bitmap;
import android.net.Uri;
import android.os.Handler;
import android.os.Message;
import android.os.Parcelable;
import android.preference.PreferenceManager;
import android.support.v4.widget.SwipeRefreshLayout;
import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;
import android.view.KeyEvent;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.webkit.GeolocationPermissions;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Toast;
import android.app.Activity;
import android.os.Build;
import android.os.Environment;
import android.provider.MediaStore;

import java.io.File;
import java.io.IOException;
import java.lang.ref.WeakReference;
import java.net.URL;
import java.util.Iterator;
import java.util.List;



public class MainActivity extends AppCompatActivity {

    SwipeRefreshLayout swipeRefreshLayout;//the layout that allows the swipe refresh

    private WebView webViewFacebook;//the main webView where is shown facebook

    //to choose and upload files
    private static final int FILECHOOSER_RESULTCODE = 1;
    private ValueCallback<Uri> mUploadMessage;
    private Uri mCapturedImageURI = null;
    // the same for Android 5.0 methods only
    private ValueCallback<Uri[]> mFilePathCallback;
    private String mCameraPhotoPath;

    private Menu optionsMenu;//contains the main menu

    private SharedPreferences savedPreferences;//contains all the values of saved preferences
	
    boolean noConnectionError = false;//flag: is true if there is a connection error and it should be reload not the error page but the last useful
    boolean swipeRefresh = false;

    boolean isSharer = false;//flag: true if the app is called from sharer
    String urlSharer = "";//to save the url got from the sharer

    // create link handler (long clicked links)
    private final MyHandler linkHandler = new MyHandler(this);

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // setup the sharedPreferences
        savedPreferences = PreferenceManager.getDefaultSharedPreferences(this);

        // if the app is being launched for the first time
        if (savedPreferences.getBoolean("first_run", true)) {
            //todo presentation
            // save the fact that the app has been started at least once
            savedPreferences.edit().putBoolean("first_run", false).apply();
        }

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
        setUpWebViewDefaults(webViewFacebook);
        //fits images to screen


        if (isSharer) {//if is a share request
            webViewFacebook.loadUrl(urlSharer);//load the sharer url
            isSharer = false;
        } else goHome();//load homepage

//        webViewFacebook.setOnTouchListener(new OnSwipeTouchListener(getApplicationContext()) {
//            public void onSwipeLeft() {
//                webViewFacebook.loadUrl("javascript:try{document.querySelector('#messages_jewel > a').click();}catch(e){window.location.href='" +
//                        getString(R.string.urlFacebookMobile) + "messages/';}");
//            }
//
//        });

        //WebViewClient that is the client callback.
        webViewFacebook.setWebViewClient(new WebViewClient() {//advanced set up

            // when there isn't a connetion
            public void onReceivedError(WebView view, int errorCode, String description, String failingUrl) {
                String summary = "<h1 style='text-align:center; padding-top:15%; font-size:70px;'>" + getString(R.string.titleNoConnection) + "</h1> <h3 " +
                        "style='text-align:center; padding-top:1%; font-style: italic;font-size:50px;'>" +
                        getString(R.string.descriptionNoConnection) + "</h3>  <h5 style='font-size:30px; text-align:center; padding-top:80%; " +
                        "opacity: 0.3;'>" + getString(R.string.awards) + "</h5>";
                webViewFacebook.loadData(summary, "text/html; charset=utf-8", "utf-8");//load a custom html page

                noConnectionError = true;
                swipeRefreshLayout.setRefreshing(false); //when the page is loaded, stop the refreshing
            }

            // when I click in a external link
            public boolean shouldOverrideUrlLoading(WebView view, String url) {
                if (url == null
                        || Uri.parse(url).getHost().endsWith("facebook.com")
                        || Uri.parse(url).getHost().endsWith("m.facebook.com")
                        || url.contains(".gif")) {
                    //url is ok
                    return false;
                } else {
                    if (Uri.parse(url).getHost().endsWith("fbcdn.net")) {
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

                //load the css customizations
                String css = "";
                if (savedPreferences.getBoolean("pref_blackTheme", false)) { css += getString(R.string.blackCss); }
                if (savedPreferences.getBoolean("pref_fixedBar", true)) {

                    css += getString(R.string.fixedBar);//get the first part

                    int navbar = 0;//default value
                    int resourceId = getResources().getIdentifier("status_bar_height", "dimen", "android");//get id
                    if (resourceId > 0) {//if there is
                        navbar = getResources().getDimensionPixelSize(resourceId);//get the dimension
                    }
                    float density = getResources().getDisplayMetrics().density;
                    int barHeight = (int) ((getResources().getDisplayMetrics().heightPixels - navbar - 44) / density);

                    css += ".flyout { max-height:" + barHeight + "px; overflow-y:scroll;  }";//without this doen-t scroll

                }
                if (savedPreferences.getBoolean("pref_hideSponsoredPosts", false)) { css += getString(R.string.hideSponsoredPost); }

                //apply the customizations
                webViewFacebook.loadUrl("javascript:function addStyleString(str) { var node = document.createElement('style'); node.innerHTML = " +
                        "str; document.body.appendChild(node); } addStyleString('" + css + "');");

                //finish the load
                super.onPageFinished(view, url);

                //when the page is loaded, stop the refreshing
                swipeRefreshLayout.setRefreshing(false);
            }
            //END management of loading

        });

        //WebChromeClient for handling all chrome functions.
        webViewFacebook.setWebChromeClient(new WebChromeClient() {
            //to the Geolocation
            public void onGeolocationPermissionsShowPrompt(String origin, GeolocationPermissions.Callback callback) {
                callback.invoke(origin, true, false);
                //todo notify when the gps is used
            }

            //to upload files
            //!!!!!!!!!!! thanks to FaceSlim !!!!!!!!!!!!!!!
            // for >= Lollipop, all in one
            public boolean onShowFileChooser(
                    WebView webView, ValueCallback<Uri[]> filePathCallback,
                    WebChromeClient.FileChooserParams fileChooserParams) {

                /** Request permission for external storage access.
                 *  If granted it's awesome and go on,
                 *  otherwise just stop here and leave the method.
                 */
                if (mFilePathCallback != null) {
                    mFilePathCallback.onReceiveValue(null);
                }
                mFilePathCallback = filePathCallback;

                Intent takePictureIntent = new Intent(MediaStore.ACTION_IMAGE_CAPTURE);
                if (takePictureIntent.resolveActivity(getPackageManager()) != null) {

                    // create the file where the photo should go
                    File photoFile = null;
                    try {
                        photoFile = createImageFile();
                        takePictureIntent.putExtra("PhotoPath", mCameraPhotoPath);
                    } catch (IOException ex) {
                        // Error occurred while creating the File
                        Toast.makeText(getApplicationContext(), "Error occurred while creating the File", Toast.LENGTH_LONG).show();
                    }

                    // continue only if the file was successfully created
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
                chooserIntent.putExtra(Intent.EXTRA_TITLE, getString(R.string.chooseAnImage));
                chooserIntent.putExtra(Intent.EXTRA_INITIAL_INTENTS, intentArray);

                startActivityForResult(chooserIntent, FILECHOOSER_RESULTCODE);

                return true;
            }

            // creating image files (Lollipop only)
            private File createImageFile() throws IOException {
                String appDirectoryName = getString(R.string.app_name).replace(" ", "");
                File imageStorageDir = new File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), appDirectoryName);

                if (!imageStorageDir.exists()) {
                    //noinspection ResultOfMethodCallIgnored
                    imageStorageDir.mkdirs();
                }

                // create an image file name
                imageStorageDir = new File(imageStorageDir + File.separator + "IMG_" + String.valueOf(System.currentTimeMillis()) + ".jpg");
                return imageStorageDir;
            }

            // openFileChooser for Android 3.0+
            public void openFileChooser(ValueCallback<Uri> uploadMsg, String acceptType) {
                String appDirectoryName = getString(R.string.app_name).replace(" ", "");
                mUploadMessage = uploadMsg;

                try {
                    File imageStorageDir = new File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), appDirectoryName);

                    if (!imageStorageDir.exists()) {
                        //noinspection ResultOfMethodCallIgnored
                        imageStorageDir.mkdirs();
                    }

                    File file = new File(imageStorageDir + File.separator + "IMG_" + String.valueOf(System.currentTimeMillis()) + ".jpg");

                    mCapturedImageURI = Uri.fromFile(file); // save to the private variable

                    final Intent captureIntent = new Intent(android.provider.MediaStore.ACTION_IMAGE_CAPTURE);
                    captureIntent.putExtra(MediaStore.EXTRA_OUTPUT, mCapturedImageURI);
                    //captureIntent.putExtra(MediaStore.EXTRA_SCREEN_ORIENTATION, ActivityInfo.SCREEN_ORIENTATION_PORTRAIT);

                    Intent i = new Intent(Intent.ACTION_GET_CONTENT);
                    i.addCategory(Intent.CATEGORY_OPENABLE);
                    i.setType("image/*");

                    Intent chooserIntent = Intent.createChooser(i, getString(R.string.chooseAnImage));
                    chooserIntent.putExtra(Intent.EXTRA_INITIAL_INTENTS, new Parcelable[]{captureIntent});

                    startActivityForResult(chooserIntent, FILECHOOSER_RESULTCODE);
                } catch (Exception e) {
                    Toast.makeText(getApplicationContext(), ("Camera Exception"), Toast.LENGTH_LONG).show();
                }
            }

            // openFileChooser for other Android versions
            /** may not work on KitKat due to lack of implementation of openFileChooser() or onShowFileChooser()
             *  https://code.google.com/p/android/issues/detail?id=62220
             *  however newer versions of KitKat fixed it on some devices */
            public void openFileChooser(ValueCallback<Uri> uploadMsg, String acceptType, String capture) {
                openFileChooser(uploadMsg, acceptType);
            }

        });

        // OnLongClickListener for detecting long clicks on links and images
        // !!!!!!!!!!! thanks to FaceSlim !!!!!!!!!!!!!!!
        webViewFacebook.setOnLongClickListener(new View.OnLongClickListener() {
            @Override
            public boolean onLongClick(View v) {
                // activate long clicks on links and image links according to settings
                if (true) {
                    WebView.HitTestResult result = webViewFacebook.getHitTestResult();
                    if (result.getType() == WebView.HitTestResult.SRC_ANCHOR_TYPE || result.getType() == WebView.HitTestResult.SRC_IMAGE_ANCHOR_TYPE) {
                        Message msg = linkHandler.obtainMessage();
                        webViewFacebook.requestFocusNodeHref(msg);
                        return true;
                    }
                }
                return false;
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
    //!!!!!!!!!!! thanks to FaceSlim !!!!!!!!!!!!!!!
    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        //used to upload files
        // code for all versions except of Lollipop
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {

            if (requestCode == FILECHOOSER_RESULTCODE) {
                if (null == this.mUploadMessage)
                    return;

                Uri result = null;

                try {
                    if (resultCode != RESULT_OK)
                        result = null;
                    else {
                        // retrieve from the private variable if the intent is null
                        result = data == null ? mCapturedImageURI : data.getData();
                    }
                } catch (Exception e) {
                    Toast.makeText(getApplicationContext(), "activity :" + e, Toast.LENGTH_LONG).show();
                }

                mUploadMessage.onReceiveValue(result);
                mUploadMessage = null;
            }

        } // end of code for all versions except of Lollipop

        // start of code for Lollipop only
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {

            if (requestCode != FILECHOOSER_RESULTCODE || mFilePathCallback == null) {
                super.onActivityResult(requestCode, resultCode, data);
                return;
            }

            Uri[] results = null;

            // check that the response is a good one
            if (resultCode == Activity.RESULT_OK) {
                if (data == null || data.getData() == null) {
                    // if there is not data, then we may have taken a photo
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

        } // end of code for Lollipop only
    }


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
                sharingIntent.putExtra(android.content.Intent.EXTRA_TEXT, getResources().getString(R.string.downloadThisApp));
                startActivity(Intent.createChooser(sharingIntent, getResources().getString(R.string.share)));

                Toast.makeText(getApplicationContext(), getResources().getString(R.string.thanks),
                        Toast.LENGTH_SHORT).show();
                break;
            }
            case R.id.settings: {//open settings
                startActivity(new Intent(this, ShowSettingsActivity.class));
                return true;
            }

            case R.id.exit: {//open settings
                android.os.Process.killProcess(android.os.Process.myPid());
                System.exit(1);
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

        //allow Geolocation
        settings.setGeolocationEnabled(savedPreferences.getBoolean("pref_allowGeolocation", true));

        // Enable Javascript
        settings.setJavaScriptEnabled(true);

        //to make the webview faster
        //settings.setCacheMode(WebSettings.LOAD_NO_CACHE);


        // Use WideViewport and Zoom out if there is no viewport defined
        settings.setUseWideViewPort(true);
        settings.setLoadWithOverviewMode(true);
        // better image sizing support
        settings.setSupportZoom(true);
        settings.setDisplayZoomControls(false);
        settings.setBuiltInZoomControls(true);


        settings.setGeolocationDatabasePath(getBaseContext().getFilesDir().getPath());

        settings.setLoadsImagesAutomatically(!savedPreferences.getBoolean("pref_doNotDownloadImages", false));//to save data
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


    //*********************** OTHER ****************************

    // handle long clicks on links, an awesome way to avoid memory leaks
    private static class MyHandler extends Handler {
        //thanks to FaceSlim
        private final WeakReference<MainActivity> mActivity;

        public MyHandler(MainActivity activity) {
            mActivity = new WeakReference<>(activity);
        }

        @Override
        public void handleMessage(Message msg) {
            MainActivity activity = mActivity.get();
            if (activity != null) {

                // get url to share
                String url = (String) msg.getData().get("url");

                if (url != null) {
                    /* "clean" an url to remove Facebook tracking redirection while sharing
                    and recreate all the special characters */
                    url = decodeUrl(cleanUrl(url));

                    // create share intent for long clicked url
                    Intent intent = new Intent(Intent.ACTION_SEND);
                    intent.setType("text/plain");
                    intent.putExtra(Intent.EXTRA_TEXT, url);
                    activity.startActivity(Intent.createChooser(intent, activity.getString(R.string.shareThisLink)));
                }
            }
        }

        // "clean" an url and remove Facebook tracking redirection
        private static String cleanUrl(String url) {
            return url.replace("http://lm.facebook.com/l.php?u=", "")
                    .replace("https://m.facebook.com/l.php?u=", "")
                    .replace("http://0.facebook.com/l.php?u=", "")
                    .replaceAll("&h=.*", "").replaceAll("\\?acontext=.*", "");
        }

        // url decoder, recreate all the special characters
        private static String decodeUrl(String url) {
            return url.replace("%3C", "<").replace("%3E", ">").replace("%23", "#").replace("%25", "%")
                    .replace("%7B", "{").replace("%7D", "}").replace("%7C", "|").replace("%5C", "\\")
                    .replace("%5E", "^").replace("%7E", "~").replace("%5B", "[").replace("%5D", "]")
                    .replace("%60", "`").replace("%3B", ";").replace("%2F", "/").replace("%3F", "?")
                    .replace("%3A", ":").replace("%40", "@").replace("%3D", "=").replace("%26", "&")
                    .replace("%24", "$").replace("%2B", "+").replace("%22", "\"").replace("%2C", ",")
                    .replace("%20", " ");
        }
    }

    //to check if there is the key for future use
    //I 'll never add premium features but I would acknowledge who has buyed the app
    protected boolean isProInstalled(Context context) {
        // the packagename of the 'key' app
        String proPackage = "it.rignanese.leo.donationkey1";

        // get the package manager
        final PackageManager pm = context.getPackageManager();

        // get a list of installed packages
        List<PackageInfo> list = pm.getInstalledPackages(PackageManager.GET_DISABLED_COMPONENTS);

        // let's iterate through the list
        Iterator<PackageInfo> i = list.iterator();
        while (i.hasNext()) {
            PackageInfo p = i.next();
            // check if proPackage is in the list AND whether that package is signed
            //  with the same signature as THIS package
            if ((p.packageName.equals(proPackage)) &&
                    (pm.checkSignatures(context.getPackageName(), p.packageName) == PackageManager.SIGNATURE_MATCH))
                return true;
        }
        return false;
    }


}

