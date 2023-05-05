package it.rignanese.leo.slimfacebook;

import static it.rignanese.leo.slimfacebook.R.id.webView;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.preference.PreferenceManager;
import android.text.SpannableString;
import android.text.style.ForegroundColorSpan;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.MenuItem;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;
import android.view.animation.AccelerateInterpolator;
import android.view.animation.Animation;
import android.view.animation.TranslateAnimation;
import android.webkit.GeolocationPermissions;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.widget.FrameLayout;
import android.widget.TextView;
import android.widget.Toast;

import com.android.billingclient.api.BillingClient;
import com.android.billingclient.api.BillingClientStateListener;
import com.android.billingclient.api.BillingFlowParams;
import com.android.billingclient.api.BillingResult;
import com.android.billingclient.api.ConsumeParams;
import com.android.billingclient.api.Purchase;
import com.android.billingclient.api.PurchasesUpdatedListener;
import com.android.billingclient.api.SkuDetails;
import com.android.billingclient.api.SkuDetailsParams;

import java.lang.ref.WeakReference;
import java.util.ArrayList;
import java.util.List;

import it.rignanese.leo.slimfacebook.settings.SettingsActivity;
import it.rignanese.leo.slimfacebook.utility.Dimension;
import it.rignanese.leo.slimfacebook.utility.MyAdvancedWebView;

/**
 * SlimSocial for Facebook is an Open Source app realized by Leonardo Rignanese <rignanese.leo@gmail.com>
 * GNU GENERAL PUBLIC LICENSE  Version 2, June 1991
 * GITHUB: https://github.com/rignaneseleo/SlimSocial-for-Facebook
 */
public class MainActivity extends Activity implements MyAdvancedWebView.Listener, PurchasesUpdatedListener {
    private SwipeRefreshLayout swipeRefreshLayout;//the layout that allows the swipe refresh
    private MyAdvancedWebView webViewFacebook;//the main webView where is shown facebook
    private BillingClient billingClient;
    private SharedPreferences savedPreferences;//contains all the values of saved preferences
    private boolean noConnectionError = false;//flag: is true if there is a connection error. It should reload the last useful page
    private boolean isSharer = false;//flag: true if the app is called from sharer
    private String urlSharer = "";//to save the url got from the sharer

    // create link handler (long clicked links)
    private final MyHandler linkHandler = new MyHandler(this);

    //full screen video variables
    private FrameLayout mTargetView;
    private WebChromeClient myWebChromeClient;
    private WebChromeClient.CustomViewCallback mCustomViewCallback;
    private View mCustomView;

    //donations
    private SkuDetails donation1 = null;
    private SkuDetails donation2 = null;
    private SkuDetails donation3 = null;
    private SkuDetails donation4 = null;
    // donation dialog that will show on start donation process
    // and dismiss on end of donation process
    private AlertDialog donationDialog;

    //*********************** ACTIVITY EVENTS ****************************
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        savedPreferences = PreferenceManager.getDefaultSharedPreferences(this); // setup the sharedPreferences

        setUpBillingClient();

        SetTheme();//set the activity theme

        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        // if the app is being launched for the first time
        if (savedPreferences.getBoolean("first_run", true)) {
            savedPreferences.edit().putBoolean("first_run", false).apply();
        }


        SetupRefreshLayout();// setup the refresh layout

        ShareLinkHandler();//handle a link shared (if there is)

        SetupWebView();//setup webview

        SetupFullScreenVideo();

        SetupOnLongClickListener();

        if (isSharer) {//if is a share request
            Log.d("MainActivity.OnCreate", "Loading shared link");
            webViewFacebook.loadUrl(urlSharer);//load the sharer url
            isSharer = false;
        } else if (getIntent() != null && getIntent().getDataString() != null) {
            //if the app is opened by fb link
            webViewFacebook.loadUrl(FromDesktopToMobileUrl(getIntent().getDataString()));
        } else GoHome();//load homepage

        //showDonationDialog();
        showDisclosureDialog();
    }

    private void showDonationDialog() {
        //only once
        SharedPreferences donation_pref = getSharedPreferences("donation_pref", MODE_PRIVATE);

        //TODO translate this
        if (donation_pref.getBoolean("is_show_first_time", true)) {
            new AlertDialog.Builder(this, android.R.style.Theme_DeviceDefault_Dialog_Alert).setTitle("Support the app")
                    .setMessage("please donate to this project.")
                    .setPositiveButton("ok", (dialog, which) -> {
                        donation_pref.edit().putBoolean("is_show_first_time", false).apply();
                        setupDonation();
                    }).setNegativeButton("not now", (dialog, which) -> {
                donation_pref.edit().putBoolean("is_show_first_time", false).apply();
            }).create().show();
        }

    }

    private void showDisclosureDialog() {
        //only once
        SharedPreferences disclosure_pref = getSharedPreferences("disclosure_pref", MODE_PRIVATE);
        String prefName = "shown_disclosure";

        if (!disclosure_pref.getBoolean(prefName, false)) {
            new AlertDialog.Builder(this, android.R.style.Theme_Material_Light_Dialog)
                    .setTitle("Disclosure")
                    .setMessage("SlimSocial does not access, collect, use or share any of your data. All the data that you will input on this app (mobile, email, location, etc.) will be handled by Facebook according to its policy.")
                    .setCancelable(false)
                    .setPositiveButton("Agree", (dialog, which) -> {
                        disclosure_pref.edit().putBoolean(prefName, true).apply();
                    }).setNegativeButton("Exit", (dialog, which) -> {
                finish();// close app
            }).create().show();
        }
    }


    @Override
    protected void onResume() {
        super.onResume();
        webViewFacebook.onResume();
    }

    @Override
    protected void onPause() {
        webViewFacebook.onPause();
        super.onPause();
    }

    @Override
    protected void onDestroy() {
        Log.e("Info", "onDestroy()");
        webViewFacebook.onDestroy();
        super.onDestroy();
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent intent) {
        super.onActivityResult(requestCode, resultCode, intent);
        webViewFacebook.onActivityResult(requestCode, resultCode, intent);
    }

    // app is already running and gets a new intent (used to share link without open another activity)
    @Override
    protected void onNewIntent(Intent intent) {

        super.onNewIntent(intent);
        setIntent(intent);

        // grab an url if opened by clicking a link
        String webViewUrl = getIntent().getDataString();

        /** get a subject and text and check if this is a link trying to be shared */
        String sharedSubject = getIntent().getStringExtra(Intent.EXTRA_SUBJECT);
        String sharedUrl = getIntent().getStringExtra(Intent.EXTRA_TEXT);
        Log.d("sharedUrl", "onNewIntent() - sharedUrl: " + sharedUrl);
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

        if (webViewUrl != null)
            webViewFacebook.loadUrl(FromDesktopToMobileUrl(webViewUrl));


        // recreate activity when something important was just changed
        if (getIntent().getBooleanExtra("settingsChanged", false)) {
            finish(); // close this
            Intent restart = new Intent(MainActivity.this, MainActivity.class);
            startActivity(restart);//reopen this
        }
    }

    //*********************** SETUP ****************************

    private void SetupWebView() {
        webViewFacebook = findViewById(webView);
        webViewFacebook.setListener(this, this);

        webViewFacebook.clearPermittedHostnames();

        //list of hosts allowed
        webViewFacebook.addPermittedHostname("facebook.com");
        webViewFacebook.addPermittedHostname("fbcdn.net");
        webViewFacebook.addPermittedHostname("fb.com");
        webViewFacebook.addPermittedHostname("fb.me");
        webViewFacebook.addPermittedHostname("messenger.com");

        webViewFacebook.requestFocus(View.FOCUS_DOWN);
        getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);//remove the keyboard issue

        WebSettings settings = webViewFacebook.getSettings();

        webViewFacebook.setDesktopMode(true);
        settings.setUserAgentString(getString(R.string.userAgent));
        settings.setJavaScriptEnabled(true);

        //set text zoom
        int zoom = Integer.parseInt(savedPreferences.getString("pref_textSize", "100"));
        settings.setTextZoom(zoom);

        //set Geolocation
        settings.setGeolocationEnabled(savedPreferences.getBoolean("pref_allowGeolocation", true));

        // Use WideViewport and Zoom out if there is no viewport defined
        settings.setUseWideViewPort(true);
        settings.setLoadWithOverviewMode(true);

        // better image sizing support
        settings.setSupportZoom(true);
        settings.setDisplayZoomControls(false);
        settings.setBuiltInZoomControls(true);

        // set caching
        settings.setAppCachePath(getCacheDir().getAbsolutePath());
        settings.setAppCacheEnabled(true);

        settings.setLoadsImagesAutomatically(!savedPreferences.getBoolean("pref_doNotDownloadImages", false));//to save data

        settings.setDisplayZoomControls(false);

        //to fix "Cross-App Scripting Vulnerability"
        //https://stackoverflow.com/questions/53095398/google-play-warning-your-app-contains-a-cross-app-scripting-vulnerability
        settings.setAppCacheMaxSize(0);
        settings.setAllowFileAccess(false);
        settings.setAppCacheEnabled(false);
    }

    private void SetupOnLongClickListener() {
        // OnLongClickListener for detecting long clicks on links and images
        webViewFacebook.setOnLongClickListener(v -> {

            WebView.HitTestResult result = webViewFacebook.getHitTestResult();
            int type = result.getType();
            if (type == WebView.HitTestResult.SRC_ANCHOR_TYPE
                    || type == WebView.HitTestResult.SRC_IMAGE_ANCHOR_TYPE
                    || type == WebView.HitTestResult.IMAGE_TYPE) {
                Message msg = linkHandler.obtainMessage();
                webViewFacebook.requestFocusNodeHref(msg);
            }
            return false;
        });

        webViewFacebook.setOnTouchListener((v, event) -> {
            switch (event.getAction()) {
                case MotionEvent.ACTION_DOWN:
                case MotionEvent.ACTION_UP:
                    if (!v.hasFocus()) {
                        v.requestFocus();
                    }
                    break;
            }
            return false;
        });
    }

    private void SetupFullScreenVideo() {
        //full screen video
        mTargetView = findViewById(R.id.target_view);
        myWebChromeClient = new WebChromeClient() {
            //this custom WebChromeClient allow to show video on full screen
            @Override
            public void onShowCustomView(View view, CustomViewCallback callback) {
                mCustomViewCallback = callback;
                mTargetView.addView(view);
                mCustomView = view;
                swipeRefreshLayout.setVisibility(View.GONE);
                mTargetView.setVisibility(View.VISIBLE);
                mTargetView.bringToFront();
            }

            @Override
            public void onHideCustomView() {
                if (mCustomView == null)
                    return;

                mCustomView.setVisibility(View.GONE);
                mTargetView.removeView(mCustomView);
                mCustomView = null;
                mTargetView.setVisibility(View.GONE);
                mCustomViewCallback.onCustomViewHidden();
                swipeRefreshLayout.setVisibility(View.VISIBLE);
            }

            @Override
            public void onGeolocationPermissionsShowPrompt(String origin, GeolocationPermissions.Callback callback) {
                callback.invoke(origin, true, false);
            }
        };
        webViewFacebook.setWebChromeClient(myWebChromeClient);
    }

    private void ShareLinkHandler() {
        /** get a subject and text and check if this is a link trying to be shared */
        String sharedSubject = getIntent().getStringExtra(Intent.EXTRA_SUBJECT);
        String sharedUrl = getIntent().getStringExtra(Intent.EXTRA_TEXT);
        Log.d("sharedUrl", "ShareLinkHandler() - sharedUrl: " + sharedUrl);

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
                urlSharer = String.format("https://touch.facebook.com/sharer.php?u=%s&t=%s", sharedUrl, sharedSubject);
                // ... and parse it just in case
                urlSharer = Uri.parse(urlSharer).toString();
                isSharer = true;
            }
        }

    }

    private void SetTheme() {
        switch (savedPreferences.getString("pref_theme", "default")) {
            case "DarkTheme":
                setTheme(R.style.DarkTheme);
                break;
            /*case "donate_theme":
                setTheme(R.style.DonateTheme);
                break;*/
            default:
                setTheme(R.style.DefaultTheme);
                break;
        }
    }

    private void SetupRefreshLayout() {
        swipeRefreshLayout = findViewById(R.id.swipe_container);
        swipeRefreshLayout.setColorSchemeResources(
                R.color.officialBlueFacebook, R.color.darkBlueSlimFacebookTheme);// set the colors
        //reload the page
        swipeRefreshLayout.setOnRefreshListener(this::RefreshPage);
    }


    //*********************** WEBVIEW FACILITIES ****************************
    private void GoHome() {
        if (savedPreferences.getBoolean("pref_recentNewsFirst", false)) {
            webViewFacebook.loadUrl(getString(R.string.urlFacebookMobile) + "?sk=h_chr");
        } else {
            webViewFacebook.loadUrl(getString(R.string.urlFacebookMobile) + "?sk=h_nor");
        }
    }

    private void OpenMessenger() {
        webViewFacebook.loadUrl(getString(R.string.urlMessages));

    }

    private void RefreshPage() {
        if (noConnectionError) {
            webViewFacebook.goBack();
            noConnectionError = false;
        } else webViewFacebook.reload();
    }


    //*********************** WEBVIEW EVENTS ****************************
    @Override
    public boolean shouldLoadUrl(String url) {
        Log.d("MainActivity", "shouldLoadUrl: " + url);
        //Check is it's opening a image
        boolean b = Uri.parse(url).getHost() != null && Uri.parse(url).getHost().endsWith("fbcdn.net");

        if (b) {
            //open the activity to show the pic
            startActivity(new Intent(this, PictureActivity.class).putExtra("URL", url));
        }

        return !b;
    }

    @Override
    public void onPageStarted(String url, Bitmap favicon) {
        swipeRefreshLayout.setRefreshing(true);
    }

    @Override
    public void onPageFinished(String url) {
        if (savedPreferences.getBoolean("pref_enableFab", true))
            webViewFacebook.loadUrl(getString(R.string.createFab));

        ApplyCustomCss(url);

        //if (savedPreferences.getBoolean("pref_enableMessagesShortcut", false)) {
        // webViewFacebook.loadUrl(getString(R.string.fixMessages));
        //}

        swipeRefreshLayout.setRefreshing(false);

        //remove pull to refresh if it is messenger
        swipeRefreshLayout.setEnabled(!url.contains("messenger.com"));
    }

    @Override
    public void onPageError(int errorCode, String description, String failingUrl) {
        // refresh on connection error (sometimes there is an error even when there is a network connection)
        if (isInternetAvailable()) {
        }
        //  if (!isInternetAvailable() && !failingUrl.contains("edge-chat") && !failingUrl.contains("akamaihd")
        // && !failingUrl.contains("atdmt") && !noConnectionError)
        else {
            Log.i("onPageError link", failingUrl);
            String summary = "<h1 style='text-align:center; padding-top:15%; font-size:70px;'>" +
                    getString(R.string.titleNoConnection) +
                    "</h1> <h3 style='text-align:center; padding-top:1%; font-style: italic;font-size:50px;'>" +
                    getString(R.string.descriptionNoConnection) +
                    "</h3>  <h5 style='font-size:30px; text-align:center; padding-top:80%; opacity: 0.3;'>" +
                    getString(R.string.awards) +
                    "</h5>";
            webViewFacebook.loadData(summary, "text/html; charset=utf-8", "utf-8");//load a custom html page
            //to allow to return at the last visited page
            noConnectionError = true;
        }
    }


    public boolean isInternetAvailable() {
        NetworkInfo networkInfo = ((ConnectivityManager) getSystemService(Context.CONNECTIVITY_SERVICE)).getActiveNetworkInfo();
        return networkInfo != null && networkInfo.isAvailable() && networkInfo.isConnected();
    }

    @Override
    public void onDownloadRequested(String url, String suggestedFilename, String mimeType,
                                    long contentLength, String contentDisposition, String userAgent) {
        Intent i = new Intent(Intent.ACTION_VIEW);
        i.setData(Uri.parse(url));
        startActivity(i);
    }


    @Override
    public void onExternalPageRequest(String url) {
        //if the link doesn't contain 'facebook.com', open it using the browser

        //this allows to open chats on messenger inside the app
        if (url.contains("/m.me/")) {
            //Transform the link
            // from https://m.me/XX?fbclid=YY
            // to https://www.messenger.com/t/XX/
            String newUrl = url.replace("m.me", "www.messenger.com/t");
            webViewFacebook.loadUrl(newUrl);
            return;
        }

        try {
            startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url)));
        } catch (ActivityNotFoundException e) {//this prevents the crash
            Log.e("shouldOverrideUrlLoad", "" + e.getMessage());
            e.printStackTrace();
        }
    }


    //*********************** BUTTON ****************************
    // handling the back button
    @Override
    public void onBackPressed() {
        if (mCustomView != null) {
            myWebChromeClient.onHideCustomView();//hide video player
        } else {
            if (webViewFacebook.canGoBack()) {
                //WebBackForwardList wbfl = webViewFacebook.copyBackForwardList();
                webViewFacebook.goBack();
            } else {
                finish();// close app
            }
        }
    }


    //*********************** MENU ****************************
    //add my menu
    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        // Inflate the menu; this adds items to the action bar if it is present.
        getMenuInflater().inflate(R.menu.menu, menu);

        for (int i = 0; i < menu.size(); i++) {
            MenuItem item = menu.getItem(i);
            if (item.getItemId() == R.id.action_donate) {
                SpannableString spanString = new SpannableString("★ " + item.getTitle().toString());
                spanString.setSpan(new ForegroundColorSpan(Color.parseColor("#CCA733")), 0, spanString.length(), 0);
                item.setTitle(spanString);
                break;
            }
        }


        //hide or show the donate button
        if (savedPreferences.getBoolean("supporter", false)) {
            menu.findItem(R.id.action_donate).setVisible(false);
            this.setTitle("SlimSocial+");
        }

        return true;
    }

    //handling the tap on the menu's items
    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        int id = item.getItemId();
        switch (id) {
            case R.id.top: {//scroll on the top of the page
                webViewFacebook.scrollTo(0, 0);
                break;
            }
            case R.id.openInBrowser: {//open the actual page into using the browser
                try {
                    startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(webViewFacebook.getUrl())));
                } catch (ActivityNotFoundException e) {
                    Toast.makeText(this, "Turn on data please", Toast.LENGTH_SHORT).show();
                }
                break;
            }
            case R.id.messages: {//open messages
                //startActivity(new Intent(this, MessagesActivity.class));
                OpenMessenger();
                break;
            }
            case R.id.refresh: {//refresh the page
                RefreshPage();
                break;
            }
            case R.id.home: {//go to the home
                GoHome();
                break;
            }
            case R.id.shareLink: {//share this page
                Intent sharingIntent = new Intent(android.content.Intent.ACTION_SEND);
                sharingIntent.setType("text/plain");
                sharingIntent.putExtra(android.content.Intent.EXTRA_TEXT, MyHandler.cleanUrl(webViewFacebook.getUrl()));
                startActivity(Intent.createChooser(sharingIntent, getResources().getString(R.string.shareThisLink)));

                break;
            }
            case R.id.share: {//share this app
                Intent sharingIntent = new Intent(android.content.Intent.ACTION_SEND);
                sharingIntent.setType("text/plain");
                sharingIntent.putExtra(android.content.Intent.EXTRA_TEXT, getResources().getString(R.string.downloadThisApp));
                startActivity(Intent.createChooser(sharingIntent, getResources().getString(R.string.shareThisApp)));

                Toast.makeText(getApplicationContext(), getResources().getString(R.string.thanks),
                        Toast.LENGTH_SHORT).show();
                break;
            }
            case R.id.settings: {//open settings
                startActivity(new Intent(this, SettingsActivity.class));
                return true;
            }

            case R.id.exit: {//open settings
                android.os.Process.killProcess(android.os.Process.myPid());
                System.exit(1);
                return true;
            }
            case R.id.action_donate: {
                setupDonation();
                break;
            }
            default:
                break;
        }
        return super.onOptionsItemSelected(item);
    }

    private void setupDonation() {
        if (donation1 == null) {
            Toast.makeText(this, getString(R.string.descriptionNoConnection), Toast.LENGTH_SHORT).show();
            return;
        }

        View donationView = LayoutInflater.from(MainActivity.this).inflate(R.layout.purchase_item, null, false);

        //View #1
        donationView.findViewById(R.id.btn_next).setOnClickListener(v -> {
            donationView.findViewById(R.id.root_mesg).setVisibility(View.GONE);
            View view = donationView.findViewById(R.id.root_donation);
            view.setVisibility(View.VISIBLE);
            view.startAnimation(inFromRightAnimation());
        });

        //View #2
        ((TextView) donationView.findViewById(R.id.tv_donation_1))
                .setText(String.format("%s", donation1.getPrice()));
        ((TextView) donationView.findViewById(R.id.tv_donation_2))
                .setText(String.format("%s", donation2.getPrice()));
        ((TextView) donationView.findViewById(R.id.tv_donation_3))
                .setText(String.format("%s", donation3.getPrice()));
        ((TextView) donationView.findViewById(R.id.tv_donation_4))
                .setText(String.format("%s", donation4.getPrice()));
        ((TextView) donationView.findViewById(R.id.tv_donation_0))
                .setText(String.format("%s", donation1.getPrice().replaceAll("[0-9]", "0")));
        donationView.findViewById(R.id.donation_1).setOnClickListener(v -> startBillingFlow(donation1));
        donationView.findViewById(R.id.donation_2).setOnClickListener(v -> startBillingFlow(donation2));
        donationView.findViewById(R.id.donation_3).setOnClickListener(v -> startBillingFlow(donation3));
        donationView.findViewById(R.id.donation_4).setOnClickListener(v -> startBillingFlow(donation4));
        donationView.findViewById(R.id.donation_0).setOnClickListener(v -> {
            donationDialog.cancel();
        });

        donationDialog = new AlertDialog.Builder(this)
                .setTitle(getString(R.string.needsupport))
                .setView(donationView)
                .setCancelable(false)
                .create();
        donationDialog.show();
    }

    private Animation inFromRightAnimation() {

        Animation inFromRight = new TranslateAnimation(
                Animation.RELATIVE_TO_PARENT, +1.0f,
                Animation.RELATIVE_TO_PARENT, 0.0f,
                Animation.RELATIVE_TO_PARENT, 0.0f,
                Animation.RELATIVE_TO_PARENT, 0.0f);
        inFromRight.setDuration(300);
        inFromRight.setInterpolator(new AccelerateInterpolator());
        return inFromRight;
    }


    private void startBillingFlow(SkuDetails donation) {
        if (billingClient.isReady()) {
            BillingFlowParams flowParams = BillingFlowParams.newBuilder().setSkuDetails(donation).build();
            billingClient.launchBillingFlow(this, flowParams);
        }
    }


    //*********************** OTHER ****************************

    String FromDesktopToMobileUrl(String url) {
        if (Uri.parse(url).getHost() != null && Uri.parse(url).getHost().endsWith("facebook.com")) {
            url = url.replace("mbasic.facebook.com", "touch.facebook.com");
            url = url.replace("www.facebook.com", "touch.facebook.com");
        }
        return url;
    }

    private void ApplyCustomCss(String loadingUrl) {
        String css = "";

        css += getString(R.string.removeBrowserNotSupported);

        if (savedPreferences.getBoolean("pref_enableFab", true))
            css += getString(R.string.fabBtn);

        if (savedPreferences.getBoolean("pref_centerTextPosts", false)) {
            css += getString(R.string.centerTextPosts);
        }
        if (savedPreferences.getBoolean("pref_addSpaceBetweenPosts", false)) {
            css += getString(R.string.addSpaceBetweenPosts);
        }
        if (savedPreferences.getBoolean("pref_hideSponsoredPosts", false)) {
            css += getString(R.string.hideAdsAndPeopleYouMayKnow);
        }
        if (savedPreferences.getBoolean("pref_fixedBar", true)) {//without add the barHeight doesn't scroll
            css += (getString(R.string.fixedBar).replace("$s", ""
                    + Dimension.heightForFixedFacebookNavbar(getApplicationContext())));
        }
        if (savedPreferences.getBoolean("pref_hideStories", false)) {
            css += getString(R.string.hideStories);
        }
        if (savedPreferences.getBoolean("pref_removeMessengerDownload", true)) {
            css += getString(R.string.removeMessengerDownload);
        }

        switch (savedPreferences.getString("pref_theme", "standard")) {
            case "DarkTheme":
            case "DarkNoBar": {
                css += getString(R.string.blackTheme);
                break;
            }
            default:
                break;
        }

        if (loadingUrl.contains("messenger.com"))
            css += getString(R.string.adaptMessenger);


        //apply the customizations
        webViewFacebook.loadUrl(getString(R.string.editCss).replace("$css", css));
    }

    @Override
    public void onPurchasesUpdated(@NonNull BillingResult billingResult, List<Purchase> purchases) {
        if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK && purchases != null) {
            for (Purchase purchase : purchases) {
                //handleNonConcumablePurchase(purchase);
                handlePurchases(purchase);
            }
        } else if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.USER_CANCELED) {
            Toast.makeText(this, "Canceled!", Toast.LENGTH_SHORT).show();
            // Handle an error caused by a user cancelling the purchase flow.
        } else {
            Toast.makeText(this, getString(R.string.descriptionNoConnection), Toast.LENGTH_SHORT).show();
            // Handle any other error codes.
        }

    }

    private void setUpBillingClient() {
        billingClient = BillingClient.newBuilder(this)
                .setListener(this)
                .enablePendingPurchases()
                .build();
        startConnection();
    }

    private void startConnection() {
        billingClient.startConnection(new BillingClientStateListener() {
            @Override
            public void onBillingSetupFinished(@NonNull BillingResult billingResult) {
                if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK) {
                    Log.v("TAG_INAPP", "Setup Billing Done");
                    // The BillingClient is ready. You can query purchases here.
                    queryAvailableProducts();
                }
            }

            @Override
            public void onBillingServiceDisconnected() {
                Log.v("TAG_INAPP", "Billing client Disconnected");
                // Try to restart the connection on the next request to
                // Google Play by calling the startConnection() method.
            }
        });
    }

    private void queryAvailableProducts() {
        List<String> skuList = new ArrayList<>();
        skuList.add("donation_1");
        skuList.add("donation_2");
        skuList.add("donation_3");
        skuList.add("donation_4");
        SkuDetailsParams.Builder builder = SkuDetailsParams.newBuilder();
        builder.setSkusList(skuList).setType(BillingClient.SkuType.INAPP);
        billingClient.querySkuDetailsAsync(builder.build(), (billingResult, skuDetailsList) -> {
            // Process the result.
            if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK && skuDetailsList != null) {
                for (SkuDetails skuDetails : skuDetailsList) {
                    if (skuDetails.getSku().equals("donation_1")) {
                        donation1 = skuDetails;

                    } else if (skuDetails.getSku().equals("donation_2")) {
                        donation2 = skuDetails;

                    } else if (skuDetails.getSku().equals("donation_3")) {
                        donation3 = skuDetails;

                    } else if (skuDetails.getSku().equals("donation_4")) {
                        donation4 = skuDetails;

                    }
                }
            }

        });
    }

    private void handlePurchases(@NonNull Purchase purchase) {
        ConsumeParams consumeParams = ConsumeParams.newBuilder().setPurchaseToken(purchase.getPurchaseToken()).build();
        billingClient.consumeAsync(consumeParams, (billingResult, purchaseToken) -> {
            if (donationDialog != null && donationDialog.isShowing()) {
                donationDialog.dismiss();
            }
            if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK) {
                Toast.makeText(this, getString(R.string.thanks) + " :)", Toast.LENGTH_SHORT).show();
                savedPreferences.edit().putBoolean("supporter", true).apply();
                //savedPreferences.edit().putString("pref_theme", "donate_theme").apply();
                SetTheme();
            } else {
                Log.w("TAG_INAPP", billingResult.getDebugMessage());
            }
        });
    }

    // handle long clicks on links, an awesome way to avoid memory leaks
    private static class MyHandler extends Handler {
        MainActivity activity;
        //thanks to FaceSlim
        private final WeakReference<MainActivity> mActivity;

        public MyHandler(MainActivity activity) {
            this.activity = activity;
            mActivity = new WeakReference<>(activity);
        }

        @Override
        public void handleMessage(Message msg) {
            SharedPreferences savedPreferences = PreferenceManager.getDefaultSharedPreferences(activity); // setup the sharedPreferences
            if (savedPreferences.getBoolean("pref_enableFastShare", true)) {
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
            return url.replace("%3C", "<").replace("%3E", ">")
                    .replace("%23", "#").replace("%25", "%")
                    .replace("%7B", "{").replace("%7D", "}")
                    .replace("%7C", "|").replace("%5C", "\\")
                    .replace("%5E", "^").replace("%7E", "~")
                    .replace("%5B", "[").replace("%5D", "]")
                    .replace("%60", "`").replace("%3B", ";")
                    .replace("%2F", "/").replace("%3F", "?")
                    .replace("%3A", ":").replace("%40", "@")
                    .replace("%3D", "=").replace("%26", "&")
                    .replace("%24", "$").replace("%2B", "+")
                    .replace("%22", "\"").replace("%2C", ",")
                    .replace("%20", " ");
        }
    }


}
