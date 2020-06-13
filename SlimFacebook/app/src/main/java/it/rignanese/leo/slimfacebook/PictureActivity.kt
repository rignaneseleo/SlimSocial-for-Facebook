package it.rignanese.leo.slimfacebook

import android.Manifest
import android.app.Activity
import android.app.DownloadManager
import android.content.*
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.preference.PreferenceManager
import android.support.v4.app.ActivityCompat
import android.support.v4.content.ContextCompat
import android.view.Menu
import android.view.MenuItem
import android.view.WindowManager
import android.widget.Toast
import it.rignanese.leo.slimfacebook.utility.MyAdvancedWebView
import java.io.File

/**
 * SlimSocial for Facebook is an Open Source app realized by Leonardo Rignanese <rignanese.leo></rignanese.leo>@gmail.com>
 * GNU GENERAL PUBLIC LICENSE  Version 2, June 1991
 * GITHUB: https://github.com/rignaneseleo/SlimSocial-for-Facebook
 */
class PictureActivity : Activity(), MyAdvancedWebView.Listener{
    private lateinit var webViewPicture //the main webView where is shown facebook
            : MyAdvancedWebView
    private lateinit var savedPreferences //contains all the values of saved preferences
            : SharedPreferences
    private lateinit var downloadManager: DownloadManager
    private var idDownloadedFile: Long = -1
    override fun onCreate(savedInstanceState: Bundle) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_picture)
        savedPreferences = PreferenceManager.getDefaultSharedPreferences(this) // setup the sharedPreferences
        downloadManager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val receiver = downloadCompletedReceiver
        registerReceiver(receiver, IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE))
        SetupPictureWebView()
        val pictureUrl = intent.getStringExtra("URL")
        webViewPicture!!.loadUrl(pictureUrl)
    }

    var downloadCompletedReceiver: BroadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val action = intent.action
            if (DownloadManager.ACTION_DOWNLOAD_COMPLETE == action) {
                val downloadId = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, 0)
                val query = DownloadManager.Query()
                query.setFilterById(idDownloadedFile)
                val c = downloadManager!!.query(query)
                if (c.moveToFirst()) {
                    val columnIndex = c.getColumnIndex(DownloadManager.COLUMN_STATUS)
                    if (DownloadManager.STATUS_SUCCESSFUL == c.getInt(columnIndex)) {
                        //get the url
                        val pictureUri = c.getString(c.getColumnIndex(DownloadManager.COLUMN_LOCAL_URI))

                        // Create the URI from the media
                        val media = File(Uri.parse(pictureUri).path)
                        val uri = Uri.fromFile(media)

                        //to share
                        val shareIntent = Intent(Intent.ACTION_SEND)
                        shareIntent.type = "image/jpeg"
                        shareIntent.putExtra(Intent.EXTRA_STREAM, uri)
                        startActivity(Intent.createChooser(shareIntent, getString(R.string.share)))

                        //reset
                        idDownloadedFile = -1
                    }
                }
            }
        }
    }

    private fun DownloadPicture(url: String, share: Boolean) {
        //check permission
        if (Build.VERSION.SDK_INT >= 23 && ContextCompat.checkSelfPermission(this,
                        Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_DENIED) {
            //ask permission
            Toast.makeText(applicationContext, getString(R.string.acceptPermissionAndRetry),
                    Toast.LENGTH_LONG).show()
            val requestResult = 0
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), requestResult
            )
        } else {
            //download photo
            val request = DownloadManager.Request(Uri.parse(url))
            request.setTitle("SlimSocial Download")
            request.allowScanningByMediaScanner()
            request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            var path = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES).path
            if (savedPreferences!!.getBoolean("pref_useSlimSocialSubfolderToDownloadedFiles", false)) {
                path += "/SlimSocial"
            }
            request.setDestinationInExternalPublicDir(path, "SlimSocial.jpg")
            if (share) request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_HIDDEN)

            // get download service and enqueue file
            val _idDownloadedFile = downloadManager!!.enqueue(request)
            if (share) idDownloadedFile = _idDownloadedFile else Toast.makeText(applicationContext, getString(R.string.downloadingPhoto),
                    Toast.LENGTH_LONG).show()
        }
    }

    //*********************** MENU ****************************
    //add my menu
    override fun onCreateOptionsMenu(menu: Menu): Boolean {
        // Inflate the menu; this adds items to the action bar if it is present.
        menuInflater.inflate(R.menu.picture_menu, menu)
        return true
    }

    //handling the tap on the menu's items
    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        val id = item.itemId
        when (id) {
            R.id.share -> {
                //scroll on the top of the page
                DownloadPicture(webViewPicture!!.url, true)
            }
            R.id.download -> {
                //scroll on the top of the page
                DownloadPicture(webViewPicture!!.url, false)
            }
            else -> {
            }
        }
        return super.onOptionsItemSelected(item)
    }

    //*********************** WEBVIEW ****************************
    private fun SetupPictureWebView() {
        webViewPicture = findViewById(R.id.webViewPicture)
        webViewPicture.setListener(this, this)

        //  webViewPicture.setDesktopMode(true);

        //webViewPicture.requestFocus(View.F);
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE) //remove the keyboard issue
        val settings = webViewPicture.settings
        settings.builtInZoomControls = true
        settings.useWideViewPort = true
        settings.javaScriptEnabled = true
        settings.loadWithOverviewMode = true
        settings.displayZoomControls = false
    }

    override fun onPageStarted(url: String?, favicon: Bitmap?) {

    }

    override fun onPageFinished(url: String?) {}
    override fun onPageError(errorCode: Int, description: String?, failingUrl: String?) {

    }

    override fun onDownloadRequested(url: String?, suggestedFilename: String?, mimeType: String?, contentLength: Long, contentDisposition: String?, userAgent: String?) {

    }
    override fun onExternalPageRequest(url: String?) {}
    override fun shouldLoadUrl(url: String?): Boolean {
        return true
    }
}