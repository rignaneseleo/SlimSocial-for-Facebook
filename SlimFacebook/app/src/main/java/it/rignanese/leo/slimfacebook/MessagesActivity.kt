package it.rignanese.leo.slimfacebook

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.net.Uri
import android.os.Bundle
import android.preference.PreferenceManager
import android.util.Log
import android.view.Menu
import android.view.MenuItem
import android.view.View
import android.view.WindowManager
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout
import it.rignanese.leo.slimfacebook.utility.MyAdvancedWebView

/**
 * SlimSocial for Facebook is an Open Source app realized by Leonardo Rignanese <rignanese.leo></rignanese.leo>@gmail.com>
 * GNU GENERAL PUBLIC LICENSE  Version 2, June 1991
 * GITHUB: https://github.com/rignaneseleo/SlimSocial-for-Facebook
 */
class MessagesActivity : Activity(), MyAdvancedWebView.Listener {
    private var swipeRefreshLayout //the layout that allows the swipe refresh
            : SwipeRefreshLayout? = null
    private  lateinit var webViewMessages //the main webView where is shown facebook
            : MyAdvancedWebView
    private lateinit var savedPreferences //contains all the values of saved preferences
            : SharedPreferences

    override fun onCreate(savedInstanceState: Bundle?) {
        savedPreferences = PreferenceManager.getDefaultSharedPreferences(this)
        // setup the sharedPreferences
        SetTheme()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_messages)
        SetupRefreshLayout()
        SetupMessagesWebView() //setup messages webview
        webViewMessages!!.loadUrl(getString(R.string.urlMessages))
    }

    private fun SetTheme() {
        when (savedPreferences!!.getString("pref_theme", "default")) {
            "DarkTheme" -> {
                setTheme(R.style.DarkTheme)
            }
            else -> {
                setTheme(R.style.DefaultTheme)
            }
        }
    }

    private fun SetupMessagesWebView() {
        webViewMessages = findViewById(R.id.webViewMessages)
        webViewMessages.setListener(this, this)
        webViewMessages.addPermittedHostname("mbasic.facebook.com")
        webViewMessages.setDesktopMode(false)
        webViewMessages.requestFocus(View.FOCUS_DOWN)
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
        //remove the keyboard issue
        val settings = webViewMessages.settings
        //set text zoom
        val zoom = savedPreferences!!.getString("pref_textSize", "100").toInt()
        settings.textZoom = zoom


        // Use WideViewport and Zoom out if there is no viewport defined
        settings.useWideViewPort = false
        settings.loadWithOverviewMode = false


        // better image sizing support
        settings.setSupportZoom(false)
        settings.displayZoomControls = false
        settings.builtInZoomControls = false

        // Hide the zoom controls for HONEYCOMB+
        settings.displayZoomControls = false
    }

    private fun SetupRefreshLayout() {
        swipeRefreshLayout = findViewById(R.id.swipe_container)
        swipeRefreshLayout?.setColorSchemeResources(
                R.color.officialBlueFacebook,
                R.color.darkBlueSlimFacebookTheme) // set the colors
        swipeRefreshLayout?.setOnRefreshListener { webViewMessages!!.reload() }
    }

    //*********************** WEBVIEW EVENTS ****************************
    override fun onPageStarted(url: String?, favicon: Bitmap?) {
        // We are no longer in 'messages', so pass this off to the main activity
        if (!url!!.contains("messages")) {
            val i = Intent(this, MainActivity::class.java)
            i.data = Uri.parse(url)
            startActivity(i)
        }
        swipeRefreshLayout!!.isRefreshing = true
    }

    override fun onPageFinished(url: String?) {
        webViewMessages.loadUrl(getString(R.string.hideHeaderFooterMessages)) //apply the customizations
        swipeRefreshLayout?.isRefreshing = false
    }

    override fun onPageError(errorCode: Int, description: String?, failingUrl: String?) {

    }

    override fun onDownloadRequested(url: String?, suggestedFilename: String?, mimeType: String?, contentLength: Long, contentDisposition: String?, userAgent: String?) {

    }

    override fun onExternalPageRequest(url: String?) {
        try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
        } catch (e: ActivityNotFoundException) { //this prevents the crash
            Log.e("shouldOverrideUrlLoad", "" + e.message)
            e.printStackTrace()
        }
    }

    override fun shouldLoadUrl(url: String?): Boolean {
        return true
    }

    //*********************** MENU ****************************
    //add my menu
    override fun onCreateOptionsMenu(menu: Menu): Boolean {
        // Inflate the menu; this adds items to the action bar if it is present.
        menuInflater.inflate(R.menu.messages_menu, menu)
        return true
    }

    //handling the tap on the menu's items
    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        val id = item.itemId
        when (id) {
            R.id.close -> {
                finish() // close view
            }
            else -> {
            }
        }
        return super.onOptionsItemSelected(item)
    }

    //*********************** BUTTON ****************************
    // handling the back button
    override fun onBackPressed() {
        if (webViewMessages.canGoBack()) {
            webViewMessages.goBack()
        } else {
            finish() // close view
        }
    }
}