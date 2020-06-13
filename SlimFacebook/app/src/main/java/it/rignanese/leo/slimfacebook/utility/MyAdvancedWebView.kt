package it.rignanese.leo.slimfacebook.utility

import android.annotation.SuppressLint
import android.annotation.TargetApi
import android.app.Activity
import android.app.DownloadManager
import android.app.Fragment
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.net.Uri
import android.net.http.SslError
import android.os.Build
import android.os.Environment
import android.os.Message
import android.provider.Settings
import android.util.AttributeSet
import android.util.Base64
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.webkit.*
import android.webkit.WebStorage.QuotaUpdater
import java.io.UnsupportedEncodingException
import java.lang.ref.WeakReference
import java.nio.charset.Charset
import java.util.*

/* CUSTOM LIBRARY OF:
 * Android-AdvancedWebView (https://github.com/delight-im/Android-AdvancedWebView)
 * Copyright (c) delight.im (https://www.delight.im/)
 * Licensed under the MIT License (https://opensource.org/licenses/MIT)
 * Version 3.0.0
 */
/**
 * Advanced WebView component for Android that works as intended out of the box
 */
/* CUSTOM LIBRARY OF:
 * Android-AdvancedWebView (https://github.com/delight-im/Android-AdvancedWebView)
 * Copyright (c) delight.im (https://www.delight.im/)
 * Licensed under the MIT License (https://opensource.org/licenses/MIT)
 * Version 3.0.0
 */
class MyAdvancedWebView : WebView {
    interface Listener {
        fun onPageStarted(url: String?, favicon: Bitmap?)
        fun onPageFinished(url: String?)
        fun onPageError(errorCode: Int, description: String?, failingUrl: String?)
        fun onDownloadRequested(url: String?, suggestedFilename: String?, mimeType: String?,
                                contentLength: Long, contentDisposition: String?, userAgent: String?)

        fun onExternalPageRequest(url: String?)

        //method by rignaneseleo
        fun shouldLoadUrl(url: String?): Boolean
    }

    protected var mActivity: WeakReference<Activity?>? = null
    protected var mFragment: WeakReference<Fragment?>? = null
    protected var mListener: Listener? = null
    protected val mPermittedHostnames: MutableList<String> = LinkedList()

    /**
     * File upload callback for platform versions prior to Android 5.0
     */
    protected var mFileUploadCallbackFirst: ValueCallback<Uri?>? = null

    /**
     * File upload callback for Android 5.0+
     */
    protected var mFileUploadCallbackSecond: ValueCallback<Array<Uri?>?>? = null
    protected var mLastError: Long = 0
    protected var mLanguageIso3: String? = null
    protected var mRequestCodeFilePicker = REQUEST_CODE_FILE_PICKER
    protected var mCustomWebViewClient: WebViewClient? = null
    protected var mCustomWebChromeClient: WebChromeClient? = null
    protected var mGeolocationEnabled = false
    protected var mUploadableFileTypes = "*/*"
    protected val mHttpHeaders: MutableMap<String, String> = HashMap()

    constructor(context: Context) : super(context) {
        init(context)
    }

    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs) {
        init(context)
    }

    constructor(context: Context, attrs: AttributeSet?, defStyleAttr: Int) : super(context, attrs, defStyleAttr) {
        init(context)
    }

    fun setListener(activity: Activity?, listener: Listener?) {
        setListener(activity, listener, REQUEST_CODE_FILE_PICKER)
    }

    fun setListener(activity: Activity?, listener: Listener?, requestCodeFilePicker: Int) {
        mActivity = activity?.let { WeakReference(it) }
        setListener(listener, requestCodeFilePicker)
    }

    fun setListener(fragment: Fragment?, listener: Listener?) {
        setListener(fragment, listener, REQUEST_CODE_FILE_PICKER)
    }

    fun setListener(fragment: Fragment?, listener: Listener?, requestCodeFilePicker: Int) {
        mFragment = fragment?.let { WeakReference(it) }
        setListener(listener, requestCodeFilePicker)
    }

    protected fun setListener(listener: Listener?, requestCodeFilePicker: Int) {
        mListener = listener
        mRequestCodeFilePicker = requestCodeFilePicker
    }

    override fun setWebViewClient(client: WebViewClient?) {
        mCustomWebViewClient = client
    }

    override fun setWebChromeClient(client: WebChromeClient?) {
        mCustomWebChromeClient = client
    }

    @SuppressLint("SetJavaScriptEnabled")
    fun setGeolocationEnabled(enabled: Boolean) {
        if (enabled) {
            settings.javaScriptEnabled = true
            settings.setGeolocationEnabled(true)
            setGeolocationDatabasePath()
        }
        mGeolocationEnabled = enabled
    }

    @SuppressLint("NewApi")
    protected fun setGeolocationDatabasePath() {
        val activity: Activity?
        activity = if (mFragment != null && mFragment!!.get() != null && mFragment!!.get()!!.activity != null) {
            mFragment!!.get()!!.activity
        } else if (mActivity != null && mActivity!!.get() != null) {
            mActivity!!.get()
        } else {
            return
        }
        settings.setGeolocationDatabasePath(activity!!.filesDir.path)
    }

    fun setUploadableFileTypes(mimeType: String) {
        mUploadableFileTypes = mimeType
    }
    /**
     * Loads and displays the provided HTML source text
     *
     * @param html       the HTML source text to load
     * @param baseUrl    the URL to use as the page's base URL
     * @param historyUrl the URL to use for the page's history entry
     * @param encoding   the encoding or charset of the HTML source text
     */
    /**
     * Loads and displays the provided HTML source text
     *
     * @param html       the HTML source text to load
     * @param baseUrl    the URL to use as the page's base URL
     * @param historyUrl the URL to use for the page's history entry
     */
    /**
     * Loads and displays the provided HTML source text
     *
     * @param html    the HTML source text to load
     * @param baseUrl the URL to use as the page's base URL
     */
    /**
     * Loads and displays the provided HTML source text
     *
     * @param html the HTML source text to load
     */
    @JvmOverloads
    fun loadHtml(html: String?, baseUrl: String? = null, historyUrl: String? = null, encoding: String? = "utf-8") {
        loadDataWithBaseURL(baseUrl, html, "text/html", encoding, historyUrl)
    }

    override fun onResume() {
        if (Build.VERSION.SDK_INT >= 11) {
            super.onResume()
        }
        resumeTimers()
    }

    override fun onPause() {
        pauseTimers()
        if (Build.VERSION.SDK_INT >= 11) {
            super.onPause()
        }
    }

    fun onDestroy() {
        // try to remove this view from its parent first
        try {
            (parent as ViewGroup).removeView(this)
        } catch (ignored: Exception) {
        }

        // then try to remove all child views from this view
        try {
            removeAllViews()
        } catch (ignored: Exception) {
        }

        // and finally destroy this view
        destroy()
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, intent: Intent?) {
        if (requestCode == mRequestCodeFilePicker) {
            if (resultCode == Activity.RESULT_OK) {
                if (intent != null) {
                    if (mFileUploadCallbackFirst != null) {
                        mFileUploadCallbackFirst!!.onReceiveValue(intent.data)
                        mFileUploadCallbackFirst = null
                    } else if (mFileUploadCallbackSecond != null) {
                        var dataUris: Array<Uri?>? = null
                        try {
                            if (intent.dataString != null) {
                                dataUris = arrayOf(Uri.parse(intent.dataString))
                            } else {
                                if (Build.VERSION.SDK_INT >= 16) {
                                    if (intent.clipData != null) {
                                        val numSelectedFiles = intent.clipData.itemCount
                                        dataUris = arrayOfNulls(numSelectedFiles)
                                        for (i in 0 until numSelectedFiles) {
                                            dataUris[i] = intent.clipData.getItemAt(i).uri
                                        }
                                    }
                                }
                            }
                        } catch (ignored: Exception) {
                        }
                        mFileUploadCallbackSecond!!.onReceiveValue(dataUris)
                        mFileUploadCallbackSecond = null
                    }
                }
            } else {
                if (mFileUploadCallbackFirst != null) {
                    mFileUploadCallbackFirst!!.onReceiveValue(null)
                    mFileUploadCallbackFirst = null
                } else if (mFileUploadCallbackSecond != null) {
                    mFileUploadCallbackSecond!!.onReceiveValue(null)
                    mFileUploadCallbackSecond = null
                }
            }
        }
    }

    /**
     * Adds an additional HTTP header that will be sent along with every HTTP `GET` request
     *
     *
     * This does only affect the main requests, not the requests to included resources (e.g. images)
     *
     *
     * If you later want to delete an HTTP header that was previously added this way, call `removeHttpHeader()`
     *
     *
     * The `WebView` implementation may in some cases overwrite headers that you set or unset
     *
     * @param name  the name of the HTTP header to add
     * @param value the value of the HTTP header to send
     */
    fun addHttpHeader(name: String, value: String) {
        mHttpHeaders[name] = value
    }

    /**
     * Removes one of the HTTP headers that have previously been added via `addHttpHeader()`
     *
     *
     * If you want to unset a pre-defined header, set it to an empty string with `addHttpHeader()` instead
     *
     *
     * The `WebView` implementation may in some cases overwrite headers that you set or unset
     *
     * @param name the name of the HTTP header to remove
     */
    fun removeHttpHeader(name: String) {
        mHttpHeaders.remove(name)
    }

    fun addPermittedHostname(hostname: String) {
        mPermittedHostnames.add(hostname)
    }

    fun addPermittedHostnames(collection: Collection<String>?) {
        mPermittedHostnames.addAll(collection!!)
    }

    fun getPermittedHostnames(): List<String> {
        return mPermittedHostnames
    }

    fun removePermittedHostname(hostname: String) {
        mPermittedHostnames.remove(hostname)
    }

    fun clearPermittedHostnames() {
        mPermittedHostnames.clear()
    }

    fun onBackPressed(): Boolean {
        return if (canGoBack()) {
            goBack()
            false
        } else {
            true
        }
    }

    fun setCookiesEnabled(enabled: Boolean) {
        CookieManager.getInstance().setAcceptCookie(enabled)
    }

    @SuppressLint("NewApi")
    fun setThirdPartyCookiesEnabled(enabled: Boolean) {
        if (Build.VERSION.SDK_INT >= 21) {
            CookieManager.getInstance().setAcceptThirdPartyCookies(this, enabled)
        }
    }

    fun setMixedContentAllowed(allowed: Boolean) {
        setMixedContentAllowed(settings, allowed)
    }

    @SuppressLint("NewApi")
    protected fun setMixedContentAllowed(webSettings: WebSettings, allowed: Boolean) {
        if (Build.VERSION.SDK_INT >= 21) {
            webSettings.mixedContentMode = if (allowed) WebSettings.MIXED_CONTENT_ALWAYS_ALLOW else WebSettings.MIXED_CONTENT_NEVER_ALLOW
        }
    }

    fun setDesktopMode(enabled: Boolean) {
        val webSettings = settings
        val newUserAgent: String
        newUserAgent = if (enabled) {
            webSettings.userAgentString
                    .replace("Mobile", "eliboM")
                    .replace("Android", "diordnA")
        } else {
            webSettings.userAgentString
                    .replace("eliboM", "Mobile")
                    .replace("diordnA", "Android")
        }
        webSettings.userAgentString = newUserAgent
        webSettings.useWideViewPort = enabled
        webSettings.loadWithOverviewMode = enabled
        webSettings.setSupportZoom(enabled)
        webSettings.builtInZoomControls = enabled
    }

    @SuppressLint("SetJavaScriptEnabled")
    protected fun init(context: Context) {
        // in IDE's preview mode
        if (isInEditMode) {
            // do not run the code from this method
            return
        }
        if (context is Activity) {
            mActivity = WeakReference(context)
        }
        mLanguageIso3 = languageIso3
        isFocusable = true
        isFocusableInTouchMode = true
        isSaveEnabled = true
        val filesDir = context.filesDir.path
        val databaseDir = filesDir.substring(0, filesDir.lastIndexOf("/")) + DATABASES_SUB_FOLDER
        val webSettings = settings
        webSettings.allowFileAccess = false
        setAllowAccessFromFileUrls(webSettings)
        webSettings.builtInZoomControls = false
        webSettings.javaScriptEnabled = true
        webSettings.domStorageEnabled = true
        if (Build.VERSION.SDK_INT < 18) {
            webSettings.setRenderPriority(WebSettings.RenderPriority.HIGH)
        }
        webSettings.databaseEnabled = true
        if (Build.VERSION.SDK_INT < 19) {
            webSettings.databasePath = databaseDir
        }
        setMixedContentAllowed(webSettings, true)
        setThirdPartyCookiesEnabled(true)
        super.setWebViewClient(object : WebViewClient() {

            override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
                if (hasNoError()) {
                    if (mListener != null) {
                        mListener!!.onPageStarted(url, favicon)
                    }
                }
                if (mCustomWebViewClient != null) {
                    mCustomWebViewClient!!.onPageStarted(view, url, favicon)
                }
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                if (hasNoError()) {
                    if (mListener != null) {
                        mListener!!.onPageFinished(url)
                    }
                }
                if (mCustomWebViewClient != null) {
                    mCustomWebViewClient!!.onPageFinished(view, url)
                }
            }

            override fun onReceivedError(view: WebView?, errorCode: Int, description: String?, failingUrl: String?) {
                setLastError()
                if (mListener != null) {
                    mListener!!.onPageError(errorCode, description, failingUrl)
                }
                if (mCustomWebViewClient != null) {
                    mCustomWebViewClient!!.onReceivedError(view, errorCode, description, failingUrl)
                }
            }

            @TargetApi(Build.VERSION_CODES.M)
            override fun onReceivedError(view: WebView?, req: WebResourceRequest?, rerr: WebResourceError?) {
                // Redirect to deprecated method, so you can use it in all SDK versions
                onReceivedError(view, rerr!!.errorCode, rerr.description.toString(), req?.url.toString())
            }

            override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean {

                // if the hostname may not be accessed
                if (!isHostnameAllowed(url)) {
                    // if a listener is available
                    if (mListener != null) {
                        // inform the listener about the request
                        mListener!!.onExternalPageRequest(url)
                    }

                    // cancel the original request
                    return true
                }

                // if there is a user-specified handler available
                if (mCustomWebViewClient != null) {
                    // if the user-specified handler asks to override the request
                    if (mCustomWebViewClient!!.shouldOverrideUrlLoading(view, url)) {
                        // cancel the original request
                        return true
                    }
                }

                // route the request through the custom URL loading method
                view?.loadUrl(url)

                // cancel the original request
                return true
            }

            override fun onLoadResource(view: WebView?, url: String?) {
                if (mCustomWebViewClient != null) {
                    mCustomWebViewClient!!.onLoadResource(view, url)
                } else {
                    super.onLoadResource(view, url)
                }
            }

            @SuppressLint("NewApi")
            override fun shouldInterceptRequest(view: WebView?, url: String?): WebResourceResponse? {
                return if (Build.VERSION.SDK_INT >= 11) {
                    if (mCustomWebViewClient != null) {
                        mCustomWebViewClient!!.shouldInterceptRequest(view, url)
                    } else {
                        super.shouldInterceptRequest(view, url)
                    }
                } else {
                    null
                }
            }

            @SuppressLint("NewApi")
            override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? {
                return if (Build.VERSION.SDK_INT >= 21) {
                    if (mCustomWebViewClient != null) {
                        mCustomWebViewClient!!.shouldInterceptRequest(view, request)
                    } else {
                        super.shouldInterceptRequest(view, request)
                    }
                } else {
                    null
                }
            }

            override fun onFormResubmission(view: WebView, dontResend: Message, resend: Message) {
                if (mCustomWebViewClient != null) {
                    mCustomWebViewClient!!.onFormResubmission(view, dontResend, resend)
                } else {
                    super.onFormResubmission(view, dontResend, resend)
                }
            }

            override fun doUpdateVisitedHistory(view: WebView, url: String, isReload: Boolean) {
                if (mCustomWebViewClient != null) {
                    mCustomWebViewClient!!.doUpdateVisitedHistory(view, url, isReload)
                } else {
                    super.doUpdateVisitedHistory(view, url, isReload)
                }
            }

            override fun onReceivedSslError(view: WebView, handler: SslErrorHandler, error: SslError) {
                if (mCustomWebViewClient != null) {
                    mCustomWebViewClient!!.onReceivedSslError(view, handler, error)
                } else {
                    super.onReceivedSslError(view, handler, error)
                }
            }

            @SuppressLint("NewApi")
            override fun onReceivedClientCertRequest(view: WebView, request: ClientCertRequest) {
                if (Build.VERSION.SDK_INT >= 21) {
                    if (mCustomWebViewClient != null) {
                        mCustomWebViewClient!!.onReceivedClientCertRequest(view, request)
                    } else {
                        super.onReceivedClientCertRequest(view, request)
                    }
                }
            }

            override fun onReceivedHttpAuthRequest(view: WebView, handler: HttpAuthHandler, host: String, realm: String) {
                if (mCustomWebViewClient != null) {
                    mCustomWebViewClient!!.onReceivedHttpAuthRequest(view, handler, host, realm)
                } else {
                    super.onReceivedHttpAuthRequest(view, handler, host, realm)
                }
            }

            override fun shouldOverrideKeyEvent(view: WebView, event: KeyEvent): Boolean {
                return if (mCustomWebViewClient != null) {
                    mCustomWebViewClient!!.shouldOverrideKeyEvent(view, event)
                } else {
                    super.shouldOverrideKeyEvent(view, event)
                }
            }

            override fun onUnhandledKeyEvent(view: WebView, event: KeyEvent) {
                if (mCustomWebViewClient != null) {
                    mCustomWebViewClient!!.onUnhandledKeyEvent(view, event)
                } else {
                    super.onUnhandledKeyEvent(view, event)
                }
            }

            override fun onScaleChanged(view: WebView, oldScale: Float, newScale: Float) {
                if (mCustomWebViewClient != null) {
                    mCustomWebViewClient!!.onScaleChanged(view, oldScale, newScale)
                } else {
                    super.onScaleChanged(view, oldScale, newScale)
                }
            }

            @SuppressLint("NewApi")
            override fun onReceivedLoginRequest(view: WebView, realm: String, account: String, args: String) {
                if (Build.VERSION.SDK_INT >= 12) {
                    if (mCustomWebViewClient != null) {
                        mCustomWebViewClient!!.onReceivedLoginRequest(view, realm, account, args)
                    } else {
                        super.onReceivedLoginRequest(view, realm, account, args)
                    }
                }
            }
        })
        super.setWebChromeClient(object : WebChromeClient() {
            // file upload callback (Android 4.1 (API level 16) -- Android 4.3 (API level 18)) (hidden method)
            // file upload callback (Android 3.0 (API level 11) -- Android 4.0 (API level 15)) (hidden method)
            // file upload callback (Android 2.2 (API level 8) -- Android 2.3 (API level 10)) (hidden method)
            fun openFileChooser(uploadMsg: ValueCallback<Uri?>?, acceptType: String? = null, capture: String? = null) {
                openFileInput(uploadMsg, null, false)
            }

            // file upload callback (Android 5.0 (API level 21) -- current) (public method)
            override fun onShowFileChooser(webView: WebView, filePathCallback: ValueCallback<Array<Uri?>?>,
                                           fileChooserParams: FileChooserParams): Boolean {
                return if (Build.VERSION.SDK_INT >= 21) {
                    val allowMultiple = fileChooserParams.mode == FileChooserParams.MODE_OPEN_MULTIPLE
                    openFileInput(null, filePathCallback, allowMultiple)
                    true
                } else {
                    false
                }
            }

            override fun onProgressChanged(view: WebView, newProgress: Int) {
                if (mCustomWebChromeClient != null) {
                    mCustomWebChromeClient!!.onProgressChanged(view, newProgress)
                } else {
                    super.onProgressChanged(view, newProgress)
                }
            }

            override fun onReceivedTitle(view: WebView, title: String) {
                if (mCustomWebChromeClient != null) {
                    mCustomWebChromeClient!!.onReceivedTitle(view, title)
                } else {
                    super.onReceivedTitle(view, title)
                }
            }

            override fun onReceivedIcon(view: WebView, icon: Bitmap) {
                if (mCustomWebChromeClient != null) {
                    mCustomWebChromeClient!!.onReceivedIcon(view, icon)
                } else {
                    super.onReceivedIcon(view, icon)
                }
            }

            override fun onReceivedTouchIconUrl(view: WebView, url: String, precomposed: Boolean) {
                if (mCustomWebChromeClient != null) {
                    mCustomWebChromeClient!!.onReceivedTouchIconUrl(view, url, precomposed)
                } else {
                    super.onReceivedTouchIconUrl(view, url, precomposed)
                }
            }

            override fun onShowCustomView(view: View, callback: CustomViewCallback) {
                if (mCustomWebChromeClient != null) {
                    mCustomWebChromeClient!!.onShowCustomView(view, callback)
                } else {
                    super.onShowCustomView(view, callback)
                }
            }

            @SuppressLint("NewApi")
            override fun onShowCustomView(view: View, requestedOrientation: Int, callback: CustomViewCallback) {
                if (Build.VERSION.SDK_INT >= 14) {
                    if (mCustomWebChromeClient != null) {
                        mCustomWebChromeClient!!.onShowCustomView(view, requestedOrientation, callback)
                    } else {
                        super.onShowCustomView(view, requestedOrientation, callback)
                    }
                }
            }

            override fun onHideCustomView() {
                if (mCustomWebChromeClient != null) {
                    mCustomWebChromeClient!!.onHideCustomView()
                } else {
                    super.onHideCustomView()
                }
            }

            override fun onCreateWindow(view: WebView, isDialog: Boolean, isUserGesture: Boolean, resultMsg: Message): Boolean {
                return if (mCustomWebChromeClient != null) {
                    mCustomWebChromeClient!!.onCreateWindow(view, isDialog, isUserGesture, resultMsg)
                } else {
                    super.onCreateWindow(view, isDialog, isUserGesture, resultMsg)
                }
            }

            override fun onRequestFocus(view: WebView) {
                if (mCustomWebChromeClient != null) {
                    mCustomWebChromeClient!!.onRequestFocus(view)
                } else {
                    super.onRequestFocus(view)
                }
            }

            override fun onCloseWindow(window: WebView) {
                if (mCustomWebChromeClient != null) {
                    mCustomWebChromeClient!!.onCloseWindow(window)
                } else {
                    super.onCloseWindow(window)
                }
            }

            override fun onJsAlert(view: WebView, url: String, message: String, result: JsResult): Boolean {
                return if (mCustomWebChromeClient != null) {
                    mCustomWebChromeClient!!.onJsAlert(view, url, message, result)
                } else {
                    super.onJsAlert(view, url, message, result)
                }
            }

            override fun onJsConfirm(view: WebView, url: String, message: String, result: JsResult): Boolean {
                return if (mCustomWebChromeClient != null) {
                    mCustomWebChromeClient!!.onJsConfirm(view, url, message, result)
                } else {
                    super.onJsConfirm(view, url, message, result)
                }
            }

            override fun onJsPrompt(view: WebView, url: String, message: String, defaultValue: String, result: JsPromptResult): Boolean {
                return if (mCustomWebChromeClient != null) {
                    mCustomWebChromeClient!!.onJsPrompt(view, url, message, defaultValue, result)
                } else {
                    super.onJsPrompt(view, url, message, defaultValue, result)
                }
            }

            override fun onJsBeforeUnload(view: WebView, url: String, message: String, result: JsResult): Boolean {
                return if (mCustomWebChromeClient != null) {
                    mCustomWebChromeClient!!.onJsBeforeUnload(view, url, message, result)
                } else {
                    super.onJsBeforeUnload(view, url, message, result)
                }
            }

            override fun onGeolocationPermissionsShowPrompt(origin: String, callback: GeolocationPermissions.Callback) {
                if (mGeolocationEnabled) {
                    callback.invoke(origin, true, false)
                } else {
                    if (mCustomWebChromeClient != null) {
                        mCustomWebChromeClient!!.onGeolocationPermissionsShowPrompt(origin, callback)
                    } else {
                        super.onGeolocationPermissionsShowPrompt(origin, callback)
                    }
                }
            }

            override fun onGeolocationPermissionsHidePrompt() {
                if (mCustomWebChromeClient != null) {
                    mCustomWebChromeClient!!.onGeolocationPermissionsHidePrompt()
                } else {
                    super.onGeolocationPermissionsHidePrompt()
                }
            }

            @SuppressLint("NewApi")
            override fun onPermissionRequest(request: PermissionRequest) {
                if (Build.VERSION.SDK_INT >= 21) {
                    if (mCustomWebChromeClient != null) {
                        mCustomWebChromeClient!!.onPermissionRequest(request)
                    } else {
                        super.onPermissionRequest(request)
                    }
                }
            }

            @SuppressLint("NewApi")
            override fun onPermissionRequestCanceled(request: PermissionRequest) {
                if (Build.VERSION.SDK_INT >= 21) {
                    if (mCustomWebChromeClient != null) {
                        mCustomWebChromeClient!!.onPermissionRequestCanceled(request)
                    } else {
                        super.onPermissionRequestCanceled(request)
                    }
                }
            }

            override fun onJsTimeout(): Boolean {
                return if (mCustomWebChromeClient != null) {
                    mCustomWebChromeClient!!.onJsTimeout()
                } else {
                    super.onJsTimeout()
                }
            }

            override fun onConsoleMessage(message: String, lineNumber: Int, sourceID: String) {
                if (mCustomWebChromeClient != null) {
                    mCustomWebChromeClient!!.onConsoleMessage(message, lineNumber, sourceID)
                } else {
                    super.onConsoleMessage(message, lineNumber, sourceID)
                }
            }

            override fun onConsoleMessage(consoleMessage: ConsoleMessage): Boolean {
                return if (mCustomWebChromeClient != null) {
                    mCustomWebChromeClient!!.onConsoleMessage(consoleMessage)
                } else {
                    super.onConsoleMessage(consoleMessage)
                }
            }

            override fun getDefaultVideoPoster(): Bitmap {
                return if (mCustomWebChromeClient != null) {
                    mCustomWebChromeClient!!.defaultVideoPoster
                } else {
                    super.getDefaultVideoPoster()
                }
            }

            override fun getVideoLoadingProgressView(): View {
                return if (mCustomWebChromeClient != null) {
                    mCustomWebChromeClient!!.videoLoadingProgressView
                } else {
                    super.getVideoLoadingProgressView()
                }
            }

            override fun getVisitedHistory(callback: ValueCallback<Array<String>>) {
                if (mCustomWebChromeClient != null) {
                    mCustomWebChromeClient!!.getVisitedHistory(callback)
                } else {
                    super.getVisitedHistory(callback)
                }
            }

            override fun onExceededDatabaseQuota(url: String, databaseIdentifier: String,
                                                 quota: Long, estimatedDatabaseSize: Long, totalQuota: Long, quotaUpdater: QuotaUpdater) {
                if (mCustomWebChromeClient != null) {
                    mCustomWebChromeClient!!.onExceededDatabaseQuota(url, databaseIdentifier, quota, estimatedDatabaseSize, totalQuota, quotaUpdater)
                } else {
                    super.onExceededDatabaseQuota(url, databaseIdentifier, quota, estimatedDatabaseSize, totalQuota, quotaUpdater)
                }
            }

            override fun onReachedMaxAppCacheSize(requiredStorage: Long, quota: Long, quotaUpdater: QuotaUpdater) {
                if (mCustomWebChromeClient != null) {
                    mCustomWebChromeClient!!.onReachedMaxAppCacheSize(requiredStorage, quota, quotaUpdater)
                } else {
                    super.onReachedMaxAppCacheSize(requiredStorage, quota, quotaUpdater)
                }
            }
        })
        setDownloadListener { url: String?, userAgent: String?, contentDisposition: String?, mimeType: String?, contentLength: Long ->
            val suggestedFilename = URLUtil.guessFileName(url, contentDisposition, mimeType)
            if (mListener != null) {
                mListener!!.onDownloadRequested(url, suggestedFilename, mimeType, contentLength, contentDisposition, userAgent)
            }
        }
    }

    override fun loadUrl(url: String, additionalHttpHeaders: MutableMap<String, String>?) {
        var additionalHttpHeaders = additionalHttpHeaders
        if (additionalHttpHeaders == null) {
            additionalHttpHeaders = mHttpHeaders
        } else if (mHttpHeaders.size > 0) {
            additionalHttpHeaders.putAll(mHttpHeaders)
        }
        if (checkKeepLoading(url)) super.loadUrl(url, additionalHttpHeaders)
    }

    override fun loadUrl(url: String) {
        if (checkKeepLoading(url)) if (mHttpHeaders.size > 0) {
            super.loadUrl(url, mHttpHeaders)
        } else {
            super.loadUrl(url)
        }
    }

    fun loadUrl(url: String, preventCaching: Boolean) {
        var url = url
        if (preventCaching) {
            url = makeUrlUnique(url)
        }
        loadUrl(url)
    }

    fun loadUrl(url: String, preventCaching: Boolean, additionalHttpHeaders: MutableMap<String, String>?) {
        var url = url
        if (preventCaching) {
            url = makeUrlUnique(url)
        }
        loadUrl(url, additionalHttpHeaders)
    }

    //method by rignaneseleo
    private fun checkKeepLoading(url: String): Boolean {
        //true if it should keep load
        return if (mListener == null) true else mListener!!.shouldLoadUrl(url)

        //keep loading
    }

    protected fun isHostnameAllowed(url: String?): Boolean {
        // if the permitted hostnames have not been restricted to a specific set
        if (mPermittedHostnames.size == 0) {
            // all hostnames are allowed
            return true
        }

        // get the actual hostname of the URL that is to be checked
        val actualHost = Uri.parse(url).host ?: return false
        //To avoid crash

        // for every hostname in the set of permitted hosts
        for (expectedHost in mPermittedHostnames) {

            // if the two hostnames match or if the actual host is a subdomain of the expected host

            //if edited by rignaneseleo
            if (actualHost.endsWith(expectedHost)) { //actualHost.equals(expectedHost) || actualHost.endsWith("."+expectedHost)
                // the actual hostname of the URL to be checked is allowed
                return true
            }
        }

        // the actual hostname of the URL to be checked is not allowed since there were no matches
        return false
    }

    protected fun setLastError() {
        mLastError = System.currentTimeMillis()
    }

    protected fun hasNoError(): Boolean {
        return mLastError + 500 < System.currentTimeMillis()
    }

    /**
     * Provides localizations for the 25 most widely spoken languages that have a ISO 639-2/T code
     *
     * @return the label for the file upload prompts as a string
     */
    protected fun getFileUploadPromptLabel(): String {
        try {
            when (mLanguageIso3) {
                "zho" -> return decodeBase64("6YCJ5oup5LiA5Liq5paH5Lu2")
                "spa" -> return decodeBase64("RWxpamEgdW4gYXJjaGl2bw==")
                "hin" -> return decodeBase64("4KSP4KSVIOCkq+CkvOCkvuCkh+CksiDgpJrgpYHgpKjgpYfgpII=")
                "ben" -> return decodeBase64("4KaP4KaV4Kaf4Ka/IOCmq+CmvuCmh+CmsiDgpqjgpr/gprDgp43gpqzgpr7gpprgpqg=")
                "ara" -> return decodeBase64("2KfYrtiq2YrYp9ixINmF2YTZgSDZiNin2K3Yrw==")
                "por" -> return decodeBase64("RXNjb2xoYSB1bSBhcnF1aXZv")
                "rus" -> return decodeBase64("0JLRi9Cx0LXRgNC40YLQtSDQvtC00LjQvSDRhNCw0LnQuw==")
                "jpn" -> return decodeBase64("MeODleOCoeOCpOODq+OCkumBuOaKnuOBl+OBpuOBj+OBoOOBleOBhA==")
                "pan" -> return decodeBase64("4KiH4Kmx4KiVIOCoq+CovuCoh+CosiDgqJrgqYHgqKPgqYs=")
                "deu" -> return decodeBase64("V8OkaGxlIGVpbmUgRGF0ZWk=")
                "jav" -> return decodeBase64("UGlsaWggc2lqaSBiZXJrYXM=")
                "msa" -> return decodeBase64("UGlsaWggc2F0dSBmYWls")
                "tel" -> return decodeBase64("4LCS4LCVIOCwq+CxhuCxluCwsuCxjeCwqOCxgSDgsI7gsILgsJrgsYHgsJXgsYvgsILgsKHgsL8=")
                "vie" -> return decodeBase64("Q2jhu41uIG3hu5l0IHThuq1wIHRpbg==")
                "kor" -> return decodeBase64("7ZWY64KY7J2YIO2MjOydvOydhCDshKDtg50=")
                "fra" -> return decodeBase64("Q2hvaXNpc3NleiB1biBmaWNoaWVy")
                "mar" -> return decodeBase64("4KSr4KS+4KSH4KSyIOCkqOCkv+CkteCkoeCkvg==")
                "tam" -> return decodeBase64("4K6S4K6w4K+BIOCuleCvh+CuvuCuquCvjeCuquCviCDgrqTgr4fgrrDgr43grrXgr4E=")
                "urd" -> return decodeBase64("2KfbjNqpINmB2KfYptmEINmF24zauiDYs9uSINin2YbYqtiu2KfYqCDaqdix24zaug==")
                "fas" -> return decodeBase64("2LHYpyDYp9mG2KrYrtin2Kgg2qnZhtuM2K8g24zaqSDZgdin24zZhA==")
                "tur" -> return decodeBase64("QmlyIGRvc3lhIHNlw6dpbg==")
                "ita" -> return decodeBase64("U2NlZ2xpIHVuIGZpbGU=")
                "tha" -> return decodeBase64("4LmA4Lil4Li34Lit4LiB4LmE4Lif4Lil4LmM4Lir4LiZ4Li24LmI4LiH")
                "guj" -> return decodeBase64("4KqP4KqVIOCqq+CqvuCqh+CqsuCqqOCrhyDgqqrgqrjgqoLgqqY=")
            }
        } catch (ignored: Exception) {
        }

        // return English translation by default
        return "Choose a file"
    }

    @SuppressLint("NewApi")
    protected fun openFileInput(fileUploadCallbackFirst: ValueCallback<Uri?>?,
                                fileUploadCallbackSecond: ValueCallback<Array<Uri?>?>?,
                                allowMultiple: Boolean) {
        if (mFileUploadCallbackFirst != null) {
            mFileUploadCallbackFirst!!.onReceiveValue(null)
        }
        mFileUploadCallbackFirst = fileUploadCallbackFirst
        if (mFileUploadCallbackSecond != null) {
            mFileUploadCallbackSecond!!.onReceiveValue(null)
        }
        mFileUploadCallbackSecond = fileUploadCallbackSecond
        val i = Intent(Intent.ACTION_GET_CONTENT)
        i.addCategory(Intent.CATEGORY_OPENABLE)
        if (allowMultiple) {
            if (Build.VERSION.SDK_INT >= 18) {
                i.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            }
        }
        i.type = mUploadableFileTypes
        if (mFragment != null && mFragment!!.get() != null) {
            mFragment!!.get()!!.startActivityForResult(Intent.createChooser(i, getFileUploadPromptLabel()), mRequestCodeFilePicker)
        } else if (mActivity != null && mActivity!!.get() != null) {
            mActivity!!.get()!!.startActivityForResult(Intent.createChooser(i, getFileUploadPromptLabel()), mRequestCodeFilePicker)
        }
    }

    /**
     * Wrapper for methods related to alternative browsers that have their own rendering engines
     */
    object Browsers {
        /**
         * Package name of an alternative browser that is installed on this device
         */
        private var mAlternativePackage: String? = null

        /**
         * Returns whether there is an alternative browser with its own rendering engine currently installed
         *
         * @param context a valid `Context` reference
         * @return whether there is an alternative browser or not
         */
        fun hasAlternative(context: Context): Boolean {
            return getAlternative(context) != null
        }

        /**
         * Returns the package name of an alternative browser with its own rendering engine or `null`
         *
         * @param context a valid `Context` reference
         * @return the package name or `null`
         */
        fun getAlternative(context: Context): String? {
            if (mAlternativePackage != null) {
                return mAlternativePackage
            }
            val alternativeBrowsers = Arrays.asList(*ALTERNATIVE_BROWSERS)
            val apps = context.packageManager.getInstalledApplications(PackageManager.GET_META_DATA)
            for (app in apps) {
                if (!app.enabled) {
                    continue
                }
                if (alternativeBrowsers.contains(app.packageName)) {
                    mAlternativePackage = app.packageName
                    return app.packageName
                }
            }
            return null
        }
        /**
         * Opens the given URL in an alternative browser
         *
         * @param context           a valid `Activity` reference
         * @param url               the URL to open
         * @param withoutTransition whether to switch to the browser `Activity` without a transition
         */
        /**
         * Opens the given URL in an alternative browser
         *
         * @param context a valid `Activity` reference
         * @param url     the URL to open
         */
        @JvmOverloads
        fun openUrl(context: Activity, url: String?, withoutTransition: Boolean = false) {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            intent.setPackage(getAlternative(context))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            if (withoutTransition) {
                context.overridePendingTransition(0, 0)
            }
        }
    }

    companion object {
        const val PACKAGE_NAME_DOWNLOAD_MANAGER = "com.android.providers.downloads"
        protected const val REQUEST_CODE_FILE_PICKER = 51426
        protected const val DATABASES_SUB_FOLDER = "/databases"
        protected const val LANGUAGE_DEFAULT_ISO3 = "eng"
        protected val CHARSET_DEFAULT: Charset = Charsets.UTF_8

        /**
         * Alternative browsers that have their own rendering engine and *may* be installed on this device
         */
        protected val ALTERNATIVE_BROWSERS = arrayOf("org.mozilla.firefox",
                "com.android.chrome", "com.opera.browser", "org.mozilla.firefox_beta",
                "com.chrome.beta", "com.opera.browser.beta")

        @SuppressLint("NewApi")
        protected fun setAllowAccessFromFileUrls(webSettings: WebSettings) {
            if (Build.VERSION.SDK_INT >= 16) {
                webSettings.allowFileAccessFromFileURLs = false
                webSettings.allowUniversalAccessFromFileURLs = false
            }
        }

        protected fun makeUrlUnique(url: String): String {
            val unique = StringBuilder()
            unique.append(url)
            if (url.contains("?")) {
                unique.append('&')
            } else {
                if (url.lastIndexOf('/') <= 7) {
                    unique.append('/')
                }
                unique.append('?')
            }
            unique.append(System.currentTimeMillis())
            unique.append('=')
            unique.append(1)
            return unique.toString()
        }

        protected val languageIso3: String
            protected get() = try {
                Locale.getDefault().isO3Language.toLowerCase(Locale.US)
            } catch (e: MissingResourceException) {
                LANGUAGE_DEFAULT_ISO3
            }

        @Throws(IllegalArgumentException::class, UnsupportedEncodingException::class)
        protected fun decodeBase64(base64: String?): String {
            val bytes = Base64.decode(base64, Base64.DEFAULT)
            return String(bytes, CHARSET_DEFAULT)
        }

        /**
         * Returns whether file uploads can be used on the current device (generally all platform versions except for 4.4)
         *
         * @return whether file uploads can be used
         */
        val isFileUploadAvailable: Boolean
            get() = isFileUploadAvailable(false)

        /**
         * Returns whether file uploads can be used on the current device (generally all platform versions except for 4.4)
         *
         *
         * On Android 4.4.3/4.4.4, file uploads may be possible but will come with a wrong MIME type
         *
         * @param needsCorrectMimeType whether a correct MIME type is required for file uploads or `application/octet-stream` is acceptable
         * @return whether file uploads can be used
         */
        fun isFileUploadAvailable(needsCorrectMimeType: Boolean): Boolean {
            return if (Build.VERSION.SDK_INT == 19) {
                val platformVersion = if (Build.VERSION.RELEASE == null) "" else Build.VERSION.RELEASE
                !needsCorrectMimeType && (platformVersion.startsWith("4.4.3") || platformVersion.startsWith("4.4.4"))
            } else {
                true
            }
        }

        /**
         * Handles a download by loading the file from `fromUrl` and saving it to `toFilename` on the external storage
         *
         *
         * This requires the two permissions `android.permission.INTERNET` and `android.permission.WRITE_EXTERNAL_STORAGE`
         *
         *
         * Only supported on API level 9 (Android 2.3) and above
         *
         * @param context    a valid `Context` reference
         * @param fromUrl    the URL of the file to download, e.g. the one from `AdvancedWebView.onDownloadRequested(...)`
         * @param toFilename the name of the destination file where the download should be saved, e.g. `myImage.jpg`
         * @return whether the download has been successfully handled or not
         */
        @SuppressLint("NewApi")
        fun handleDownload(context: Context, fromUrl: String?, toFilename: String?): Boolean {
            val request = DownloadManager.Request(Uri.parse(fromUrl))
            request.allowScanningByMediaScanner()
            request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, toFilename)
            val dm = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
            return try {
                try {
                    dm.enqueue(request)
                } catch (e: SecurityException) {
                    request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE)
                    dm.enqueue(request)
                }
                true
            } // if the download manager app has been disabled on the device
            catch (e: IllegalArgumentException) {
                // show the settings screen where the user can enable the download manager app again
                openAppSettings(context)
                false
            }
        }

        @SuppressLint("NewApi")
        private fun openAppSettings(context: Context): Boolean {
            return try {
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                intent.data = Uri.parse("package:$PACKAGE_NAME_DOWNLOAD_MANAGER")
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                context.startActivity(intent)
                true
            } catch (e: Exception) {
                false
            }
        }
    }
}
