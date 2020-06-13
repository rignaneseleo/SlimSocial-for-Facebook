package it.rignanese.leo.slimfacebook

import android.annotation.SuppressLint
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.net.ConnectivityManager
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Message
import android.os.Process
import android.preference.PreferenceManager
import android.support.v4.widget.SwipeRefreshLayout
import android.support.v4.widget.SwipeRefreshLayout.OnRefreshListener
import android.util.Log
import android.view.*
import android.webkit.GeolocationPermissions
import android.webkit.WebChromeClient
import android.webkit.WebChromeClient.CustomViewCallback
import android.webkit.WebView.HitTestResult
import android.widget.FrameLayout
import android.widget.Toast
import it.rignanese.leo.slimfacebook.R.id
import it.rignanese.leo.slimfacebook.settings.SettingsActivity
import it.rignanese.leo.slimfacebook.utility.Dimension.heightForFixedFacebookNavbar
import it.rignanese.leo.slimfacebook.utility.MyAdvancedWebView
import java.lang.ref.WeakReference

/**
 * SlimSocial for Facebook is an Open Source app realized by Leonardo Rignanese <rignanese.leo></rignanese.leo>@gmail.com>
 * GNU GENERAL PUBLIC LICENSE  Version 2, June 1991
 * GITHUB: https://github.com/rignaneseleo/SlimSocial-for-Facebook
 */
class MainActivity : Activity(), MyAdvancedWebView.Listener {
    private lateinit var swipeRefreshLayout //the layout that allows the swipe refresh
            : SwipeRefreshLayout
    private lateinit var webViewFacebook //the main webView where is shown facebook
            : MyAdvancedWebView
    private lateinit var savedPreferences //contains all the values of saved preferences
            : SharedPreferences
    private var noConnectionError = false //flag: is true if there is a connection error. It should reload the last useful page
    private var isSharer = false //flag: true if the app is called from sharer
    private var urlSharer = "" //to save the url got from the sharer


    // create link handler (long clicked links)
    private val linkHandler = MyHandler(this)

    //full screen video variables
    private lateinit var mTargetView: FrameLayout
    private lateinit var myWebChromeClient: WebChromeClient
    private lateinit var mCustomViewCallback: CustomViewCallback
    private lateinit var mCustomView: View

    //*********************** ACTIVITY EVENTS ****************************
    override fun onCreate(savedInstanceState: Bundle?) {
        savedPreferences = PreferenceManager.getDefaultSharedPreferences(this) // setup the sharedPreferences
        SetTheme() //set the activity theme
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        // if the app is being launched for the first time
        if (savedPreferences.getBoolean("first_run", true)) {
            savedPreferences.edit().putBoolean("first_run", false).apply()
        }
        SetupRefreshLayout() // setup the refresh layout
        ShareLinkHandler() //handle a link shared (if there is)
        SetupWebView() //setup webview
        SetupFullScreenVideo()
        SetupOnLongClickListener()
        if (isSharer) { //if is a share request
            Log.d("MainActivity.OnCreate", "Loading shared link")
            webViewFacebook.loadUrl(urlSharer) //load the sharer url
            isSharer = false
        } else if (intent != null && intent.dataString != null) {
            //if the app is opened by fb link
            webViewFacebook.loadUrl(FromDesktopToMobileUrl(intent.dataString))
        } else GoHome() //load homepage
    }

    @SuppressLint("NewApi")
    override fun onResume() {
        super.onResume()
        webViewFacebook.onResume()
    }

    @SuppressLint("NewApi")
    override fun onPause() {
        webViewFacebook.onPause()
        super.onPause()
    }

    override fun onDestroy() {
        Log.e("Info", "onDestroy()")
        webViewFacebook.onDestroy()
        super.onDestroy()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, intent: Intent) {
        super.onActivityResult(requestCode, resultCode, intent)
        webViewFacebook.onActivityResult(requestCode, resultCode, intent)
    }

    // app is already running and gets a new intent (used to share link without open another activity)
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        // grab an url if opened by clicking a link
        var webViewUrl = getIntent().dataString

        /** get a subject and text and check if this is a link trying to be shared  */
        val sharedSubject = getIntent().getStringExtra(Intent.EXTRA_SUBJECT)
        var sharedUrl = getIntent().getStringExtra(Intent.EXTRA_TEXT)
        Log.d("sharedUrl", "onNewIntent() - sharedUrl: $sharedUrl")
        // if we have a valid URL that was shared by us, open the sharer
        if (sharedUrl != null) {
            if (sharedUrl != "") {
                // check if the URL being shared is a proper web URL
                if (!sharedUrl.startsWith("http://") || !sharedUrl.startsWith("https://")) {
                    // if it's not, let's see if it includes an URL in it (prefixed with a message)
                    val startUrlIndex = sharedUrl.indexOf("http:")
                    if (startUrlIndex > 0) {
                        // seems like it's prefixed with a message, let's trim the start and get the URL only
                        sharedUrl = sharedUrl.substring(startUrlIndex)
                    }
                }
                // final step, set the proper Sharer...
                webViewUrl = String.format("https://m.facebook.com/sharer.phpu=%s&t=%s", sharedUrl, sharedSubject)
                // ... and parse it just in case
                webViewUrl = Uri.parse(webViewUrl).toString()
            }
        }
        if (webViewUrl != null) webViewFacebook.loadUrl(FromDesktopToMobileUrl(webViewUrl))


        // recreate activity when something important was just changed
        if (getIntent().getBooleanExtra("settingsChanged", false)) {
            finish() // close this
            val restart = Intent(this@MainActivity, MainActivity::class.java)
            startActivity(restart) //reopen this
        }
    }

    //*********************** SETUP ****************************
    private fun SetupWebView() {
        webViewFacebook = findViewById(id.webView)
        webViewFacebook.setListener(this, this)
        webViewFacebook.clearPermittedHostnames()
        webViewFacebook.addPermittedHostname("facebook.com")
        webViewFacebook.addPermittedHostname("fbcdn.net")
        webViewFacebook.addPermittedHostname("fb.com")
        webViewFacebook.addPermittedHostname("fb.me")

/*
        webViewFacebook.addPermittedHostname("m.facebook.com");
        webViewFacebook.addPermittedHostname("h.facebook.com");
        webViewFacebook.addPermittedHostname("touch.facebook.com");
        webViewFacebook.addPermittedHostname("mbasic.facebook.com");
        webViewFacebook.addPermittedHostname("touch.facebook.com");
        webViewFacebook.addPermittedHostname("messenger.com");
*/
        webViewFacebook.requestFocus(View.FOCUS_DOWN)
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE) //remove the keyboard issue
        val settings = webViewFacebook.settings
        webViewFacebook.setDesktopMode(true)

        settings.let {
            settings.userAgentString = "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36"
            settings.javaScriptEnabled = true

            //set text zoom
            val zoom = savedPreferences.getString("pref_textSize", "100").toInt()
            settings.textZoom = zoom

            //set Geolocation
            settings.setGeolocationEnabled(savedPreferences.getBoolean("pref_allowGeolocation", true))

            // Use WideViewport and Zoom out if there is no viewport defined
            settings.useWideViewPort = true
            settings.loadWithOverviewMode = true

            // better image sizing support
            settings.setSupportZoom(true)
            settings.displayZoomControls = false
            settings.builtInZoomControls = true

            // set caching
            settings.setAppCachePath(cacheDir.absolutePath)
            settings.setAppCacheEnabled(true)
            settings.loadsImagesAutomatically = !savedPreferences.getBoolean("pref_doNotDownloadImages", false) //to save data
            settings.displayZoomControls = false
        }
    }

    private fun SetupOnLongClickListener() {
        // OnLongClickListener for detecting long clicks on links and images
        webViewFacebook.setOnLongClickListener { v: View ->
            val result = webViewFacebook.hitTestResult
            val type = result.type
            if (type == HitTestResult.SRC_ANCHOR_TYPE || type == HitTestResult.SRC_IMAGE_ANCHOR_TYPE || type == HitTestResult.IMAGE_TYPE) {
                val msg = linkHandler.obtainMessage()
                webViewFacebook.requestFocusNodeHref(msg)
            }
            false
        }
        webViewFacebook.setOnTouchListener { v: View, event: MotionEvent ->
            when (event.action) {
                MotionEvent.ACTION_DOWN, MotionEvent.ACTION_UP -> if (!v.hasFocus()) {
                    v.requestFocus()
                }
            }
            false
        }
    }

    private fun SetupFullScreenVideo() {
        //full screen video
        mTargetView = findViewById(id.target_view)
        myWebChromeClient = object : WebChromeClient() {
            //this custom WebChromeClient allow to show video on full screen
            override fun onShowCustomView(view: View, callback: CustomViewCallback) {
                mCustomViewCallback = callback
                mTargetView.addView(view)
                mCustomView = view
                swipeRefreshLayout.visibility = View.GONE
                mTargetView.visibility = View.VISIBLE
                mTargetView.bringToFront()


            }

            override fun onHideCustomView() {
                mCustomView.visibility = View.GONE
                mTargetView.removeView(mCustomView)
                mCustomView
                mTargetView.visibility = View.GONE
                mCustomViewCallback.onCustomViewHidden()
                swipeRefreshLayout.visibility = View.VISIBLE
            }

            override fun onGeolocationPermissionsShowPrompt(origin: String, callback: GeolocationPermissions.Callback) {
                callback.invoke(origin, true, false)
            }
        }
        webViewFacebook.webChromeClient = myWebChromeClient
    }

    private fun ShareLinkHandler() {
        /** get a subject and text and check if this is a link trying to be shared  */
        val sharedSubject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
        var sharedUrl = intent.getStringExtra(Intent.EXTRA_TEXT)
        Log.d("sharedUrl", "ShareLinkHandler() - sharedUrl: $sharedUrl")

        // if we have a valid URL that was shared by us, open the sharer
        if (sharedUrl != null) {
            if (sharedUrl != "") {
                // check if the URL being shared is a proper web URL
                if (!sharedUrl.startsWith("http://") || !sharedUrl.startsWith("https://")) {
                    // if it's not, let's see if it includes an URL in it (prefixed with a message)
                    val startUrlIndex = sharedUrl.indexOf("http:")
                    if (startUrlIndex > 0) {
                        // seems like it's prefixed with a message, let's trim the start and get the URL only
                        sharedUrl = sharedUrl.substring(startUrlIndex)
                    }
                }
                // final step, set the proper Sharer...
                urlSharer = String.format("https://touch.facebook.com/sharer.phpu=%s&t=%s", sharedUrl, sharedSubject)
                // ... and parse it just in case
                urlSharer = Uri.parse(urlSharer).toString()
                isSharer = true
            }
        }
    }

    private fun SetTheme() {
        when (savedPreferences.getString("pref_theme", "default")) {
            "DarkTheme" -> {
                setTheme(R.style.DarkTheme)
            }
            else -> {
                setTheme(R.style.DefaultTheme)
            }
        }
    }

    private fun SetupRefreshLayout() {
        swipeRefreshLayout = findViewById(id.swipe_container)
        swipeRefreshLayout.setColorSchemeResources(
                R.color.officialBlueFacebook, R.color.darkBlueSlimFacebookTheme) // set the colors
        //reload the page
        swipeRefreshLayout.setOnRefreshListener(OnRefreshListener { RefreshPage() })
    }

    //*********************** WEBVIEW FACILITIES ****************************
    private fun GoHome() {
        if (savedPreferences.getBoolean("pref_recentNewsFirst", false)) {
            webViewFacebook.loadUrl(getString(R.string.urlFacebookMobile) + "sk=h_chr")
        } else {
            webViewFacebook.loadUrl(getString(R.string.urlFacebookMobile) + "sk=h_nor")
        }
    }

    private fun RefreshPage() {
        if (noConnectionError) {
            webViewFacebook.goBack()
            noConnectionError = false
        } else webViewFacebook.reload()
    }

    //*********************** WEBVIEW EVENTS ****************************
    override fun shouldLoadUrl(url: String?): Boolean {
        Log.d("MainActivity", "shouldLoadUrl: $url")
        //Check is it's opening a image
        val b = Uri.parse(url).host != null && Uri.parse(url).host.endsWith("fbcdn.net")
        if (b) {
            //open the activity to show the pic
            startActivity(Intent(this, PictureActivity::class.java).putExtra("URL", url))
        }
        return !b
    }

    override fun onPageStarted(url: String?, favicon: Bitmap?) {
        swipeRefreshLayout.isRefreshing = true
    }

    override fun onPageFinished(url: String?) {
        ApplyCustomCss()
        if (savedPreferences.getBoolean("pref_enableMessagesShortcut", false)) {
            webViewFacebook.loadUrl(getString(R.string.fixMessages))
        }
        swipeRefreshLayout.isRefreshing = false
    }

    override fun onPageError(errorCode: Int, description: String?, failingUrl: String?) {
        // refresh on connection error (sometimes there is an error even when there is a network connection)
        if (isInternetAvailable) {
        } else {
            Log.i("onPageError link", failingUrl)
            val summary = "<h1 style='text-align:center; padding-top:15%; font-size:70px;'>" +
                    getString(R.string.titleNoConnection) +
                    "</h1> <h3 style='text-align:center; padding-top:1%; font-style: italic;font-size:50px;'>" +
                    getString(R.string.descriptionNoConnection) +
                    "</h3>  <h5 style='font-size:30px; text-align:center; padding-top:80%; opacity: 0.3;'>" +
                    getString(R.string.awards) +
                    "</h5>"
            webViewFacebook.loadData(summary, "text/html; charset=utf-8", "utf-8") //load a custom html page
            //to allow to return at the last visited page
            noConnectionError = true
        }
    }

    val isInternetAvailable: Boolean
        get() {
            val networkInfo = (getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager).activeNetworkInfo
            return networkInfo != null && networkInfo.isAvailable && networkInfo.isConnected
        }

    override fun onDownloadRequested(url: String?, suggestedFilename: String?, mimeType: String?,
                                     contentLength: Long, contentDisposition: String?, userAgent: String?) {
        val i = Intent(Intent.ACTION_VIEW)
        i.data = Uri.parse(url)
        startActivity(i)
    }

    override fun onExternalPageRequest(url: String?) { //if the link doesn't contain 'facebook.com', open it using the browser
        if (Uri.parse(url).host != null && Uri.parse(url).host.endsWith("slimsocial.leo")) {
            //he clicked on messages
            startActivity(Intent(this, MessagesActivity::class.java))
        } else {
            try {
                startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
            } catch (e: ActivityNotFoundException) { //this prevents the crash
                Log.e("shouldOverrideUrlLoad", "" + e.message)
                e.printStackTrace()
            }
        }
    }

    //*********************** BUTTON ****************************
    // handling the back button
    override fun onBackPressed() {
        myWebChromeClient.onHideCustomView()
    }

    //*********************** MENU ****************************
    //add my menu
    override fun onCreateOptionsMenu(menu: Menu): Boolean {
        // Inflate the menu; this adds items to the action bar if it is present.
        menuInflater.inflate(R.menu.menu, menu)
        return true
    }

    //handling the tap on the menu's items
    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        val id = item.itemId
        when (id) {
            R.id.top -> {
                //scroll on the top of the page
                webViewFacebook.scrollTo(0, 0)
            }
            R.id.openInBrowser -> {
                //open the actual page into using the browser
                try {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(webViewFacebook.url)))
                } catch (e: ActivityNotFoundException) {
                    Toast.makeText(this, "Turn on data please", Toast.LENGTH_SHORT).show()
                }
            }
            R.id.messages -> {
                //open messages
                startActivity(Intent(this, MessagesActivity::class.java))
            }
            R.id.refresh -> {
                //refresh the page
                RefreshPage()
            }
            R.id.home -> {
                //go to the home
                GoHome()
            }
            R.id.shareLink -> {
                //share this page
                val sharingIntent = Intent(Intent.ACTION_SEND)
                sharingIntent.type = "text/plain"
                sharingIntent.putExtra(Intent.EXTRA_TEXT, MyHandler.cleanUrl(webViewFacebook.url))
                startActivity(Intent.createChooser(sharingIntent, resources.getString(R.string.shareThisLink)))
            }
            R.id.share -> {
                //share this app
                val sharingIntent = Intent(Intent.ACTION_SEND)
                sharingIntent.type = "text/plain"
                sharingIntent.putExtra(Intent.EXTRA_TEXT, resources.getString(R.string.downloadThisApp))
                startActivity(Intent.createChooser(sharingIntent, resources.getString(R.string.shareThisApp)))
                Toast.makeText(applicationContext, resources.getString(R.string.thanks),
                        Toast.LENGTH_SHORT).show()
            }
            R.id.settings -> {
                //open settings
                startActivity(Intent(this, SettingsActivity::class.java))
                return true
            }
            R.id.exit -> {
                //open settings
                Process.killProcess(Process.myPid())
                System.exit(1)
                return true
            }
            else -> {
            }
        }
        return super.onOptionsItemSelected(item)
    }

    //*********************** OTHER ****************************
    fun FromDesktopToMobileUrl(url: String): String {
        var url = url
        if (Uri.parse(url).host != null && Uri.parse(url).host.endsWith("facebook.com")) {
            url = url.replace("mbasic.facebook.com", "touch.facebook.com")
            url = url.replace("www.facebook.com", "touch.facebook.com")
        }
        return url
    }

    private fun ApplyCustomCss() {
        var css: String = ""
        if (savedPreferences.getBoolean("pref_centerTextPosts", false)) {
            css += getString(R.string.centerTextPosts)
        }
        if (savedPreferences.getBoolean("pref_addSpaceBetweenPosts", false)) {
            css += getString(R.string.addSpaceBetweenPosts)
        }
        if (savedPreferences.getBoolean("pref_hideSponsoredPosts", false)) {
            css += getString(R.string.hideAdsAndPeopleYouMayKnow)
        }
        if (savedPreferences.getBoolean("pref_fixedBar", true)) { //without add the barHeight doesn't scroll
            css += getString(R.string.fixedBar).replace("\$s", ""
                    + heightForFixedFacebookNavbar(applicationContext))
        }
        if (savedPreferences.getBoolean("pref_removeMessengerDownload", true)) {
            css += getString(R.string.removeMessengerDownload)
        }
        when (savedPreferences.getString("pref_theme", "standard")) {
            "DarkTheme", "DarkNoBar" -> {
                css += getString(R.string.blackTheme)
            }
            else -> {
            }
        }

        //apply the customizations
        webViewFacebook.loadUrl(getString(R.string.editCss).replace("\$css", css))
    }

    // handle long clicks on links, an awesome way to avoid memory leaks
    private class MyHandler(var activity: MainActivity) : Handler() {

        //thanks to FaceSlim
        private val mActivity: WeakReference<MainActivity>
        override fun handleMessage(msg: Message) {
            val savedPreferences = PreferenceManager.getDefaultSharedPreferences(activity) // setup the sharedPreferences
            if (savedPreferences.getBoolean("pref_enableFastShare", true)) {
                val activity = mActivity.get()
                if (activity != null) {

                    // get url to share
                    var url = msg.data["url"] as String
                    if (url != null) {
                        /* "clean" an url to remove Facebook tracking redirection while sharing
                    and recreate all the special characters */
                        url = decodeUrl(cleanUrl(url))

                        // create share intent for long clicked url
                        val intent = Intent(Intent.ACTION_SEND)
                        intent.type = "text/plain"
                        intent.putExtra(Intent.EXTRA_TEXT, url)
                        activity.startActivity(Intent.createChooser(intent, activity.getString(R.string.shareThisLink)))
                    }
                }
            }
        }

        companion object {
            // "clean" an url and remove Facebook tracking redirection
            fun cleanUrl(url: String): String {
                return url.replace("http://lm.facebook.com/l.phpu=", "")
                        .replace("https://m.facebook.com/l.phpu=", "")
                        .replace("http://0.facebook.com/l.phpu=", "")
                        .replace("&h=.*".toRegex(), "").replace("\\acontext=.*".toRegex(), "")
            }

            // url decoder, recreate all the special characters
            private fun decodeUrl(url: String): String {
                return url.replace("%3C", "<").replace("%3E", ">")
                        .replace("%23", "#").replace("%25", "%")
                        .replace("%7B", "{").replace("%7D", "}")
                        .replace("%7C", "|").replace("%5C", "\\")
                        .replace("%5E", "^").replace("%7E", "~")
                        .replace("%5B", "[").replace("%5D", "]")
                        .replace("%60", "`").replace("%3B", ";")
                        .replace("%2F", "/").replace("%3F", "")
                        .replace("%3A", ":").replace("%40", "@")
                        .replace("%3D", "=").replace("%26", "&")
                        .replace("%24", "$").replace("%2B", "+")
                        .replace("%22", "\"").replace("%2C", ",")
                        .replace("%20", " ")
            }
        }

        init {
            mActivity = WeakReference(activity)
        }
    }
}