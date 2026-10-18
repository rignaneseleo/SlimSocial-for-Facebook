package it.rignanese.leo.slimfacebook

import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.webkit.CookieManager
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.core.app.NotificationCompat
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONObject
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Background check for new Facebook notifications / messages / friend
 * requests (#269).
 *
 * Facebook offers a webview no push channel, so the only way to learn about
 * new activity without the app open is to look. Every [intervalMinutes] (the
 * WorkManager floor is 15) this loads the touch site in a hidden WebView that
 * shares the cookie jar with the one the app uses - so it is already signed
 * in - waits for the jewel counters to render, reads them, and posts one
 * notification when the total went up since the last one shown.
 *
 * The WebView is never attached to a window, so no overlay permission is
 * needed. It lives for at most [TOTAL_TIMEOUT_S] seconds and is destroyed in
 * every path.
 */
class NotificationWorker(
    context: Context,
    params: WorkerParameters,
) : Worker(context, params) {

    companion object {
        const val TAG = "SlimNotif"
        const val CHANNEL_ID = "fb_activity"
        const val NOTIFICATION_ID = 4101
        const val UNIQUE_WORK_NAME = "slim_notification_poll"
        private const val PREFS = "slim_notifications"
        private const val KEY_LAST_TOTAL = "last_total"

        // Same layout the app's feed uses by default (touch site, Firefox UA),
        // so the counters the script reads are the ones the app shows.
        private const val URL = "https://touch.facebook.com/home.php"
        private const val UA =
            "Mozilla/5.0 (Android 10; Mobile; rv:70.0) Gecko/70.0 Firefox/70.0"
        private const val TOTAL_TIMEOUT_S = 45L
        private const val MAX_READS = 8
        private const val READ_EVERY_MS = 1500L

        // Reads the jewel badges. Several sources because the touch layout
        // has changed before: the jewel containers, then the "(3)" prefix
        // Facebook puts in the page title.
        private const val READ_JS = """(function(){
            function num(t){var m=(t||'').match(/\d+/);return m?parseInt(m[0],10):0;}
            function jewel(id){
                var j=document.getElementById(id);
                if(!j)return -1;
                var c=j.querySelector('[data-sigil="count"],.jewelCount,[class*="count"]');
                if(c)return num(c.textContent);
                return num(j.getAttribute('aria-label')||'');
            }
            var r={login:false,n:jewel('notifications_jewel'),m:jewel('messages_jewel'),
                   f:jewel('requests_jewel'),t:0,ready:false};
            if(/login|checkpoint|recover/.test(location.pathname)||
               document.querySelector('input[name="pass"]'))r.login=true;
            var t=document.title.match(/^\((\d+)\+?\)/);
            if(t)r.t=parseInt(t[1],10);
            r.ready=r.login||r.n>=0||r.m>=0||r.f>=0||/Facebook/i.test(document.title);
            return JSON.stringify(r);
        })()"""

        fun createChannel(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID, "Facebook activity", NotificationManager.IMPORTANCE_DEFAULT
                ).apply { description = "New notifications, messages and friend requests" }
            )
        }

        fun clear(context: Context) {
            (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .cancel(NOTIFICATION_ID)
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putInt(KEY_LAST_TOTAL, 0).apply()
        }
    }

    private class Counts(
        val login: Boolean, val notifications: Int, val messages: Int,
        val friends: Int, val title: Int,
    ) {
        val total: Int
            get() {
                val sum = notifications + messages + friends
                return if (sum > 0) sum else title
            }
    }

    @Volatile private var result: Counts? = null
    @Volatile private var webView: WebView? = null

    override fun doWork(): Result {
        val latch = CountDownLatch(1)
        val main = Handler(Looper.getMainLooper())
        main.post {
            try {
                startCheck(main, latch)
            } catch (e: Throwable) {
                Log.w(TAG, "could not start check", e)
                latch.countDown()
            }
        }
        val finished = latch.await(TOTAL_TIMEOUT_S, TimeUnit.SECONDS)
        main.post {
            webView?.apply { stopLoading(); destroy() }
            webView = null
        }

        val counts = result
        if (!finished || counts == null) {
            Log.d(TAG, "no reading (finished=$finished)")
            return Result.retry()
        }
        if (counts.login) {
            Log.d(TAG, "signed out - nothing to report")
            return Result.success()
        }
        publish(counts)
        return Result.success()
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun startCheck(main: Handler, latch: CountDownLatch) {
        CookieManager.getInstance().setAcceptCookie(true)
        val wv = WebView(applicationContext)
        webView = wv
        wv.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            userAgentString = UA
            blockNetworkImage = true
            cacheMode = WebSettings.LOAD_DEFAULT
        }
        wv.resumeTimers() // the app may have paused the shared timers
        wv.webViewClient = object : WebViewClient() {
            private var started = false
            override fun onPageFinished(view: WebView, url: String?) {
                if (started) return
                started = true
                readLoop(main, view, latch, 0)
            }
        }
        wv.loadUrl(URL)
    }

    private fun readLoop(main: Handler, view: WebView, latch: CountDownLatch, attempt: Int) {
        view.evaluateJavascript(READ_JS) { raw ->
            var done = false
            try {
                // evaluateJavascript hands back a JSON-encoded string
                val inner = JSONObject("{\"v\":$raw}").optString("v", "")
                val j = JSONObject(inner)
                val ready = j.optBoolean("ready", false)
                if (ready || attempt >= MAX_READS) {
                    result = Counts(
                        login = j.optBoolean("login", false),
                        notifications = maxOf(0, j.optInt("n", 0)),
                        messages = maxOf(0, j.optInt("m", 0)),
                        friends = maxOf(0, j.optInt("f", 0)),
                        title = j.optInt("t", 0),
                    )
                    // counters render a moment after the shell: give them a
                    // couple of reads before trusting a zero
                    done = attempt >= 2 || (result?.total ?: 0) > 0 || result?.login == true
                }
            } catch (e: Exception) {
                Log.w(TAG, "bad reading: $raw", e)
                done = attempt >= MAX_READS
            }
            if (done || attempt >= MAX_READS) {
                latch.countDown()
            } else {
                main.postDelayed({ readLoop(main, view, latch, attempt + 1) }, READ_EVERY_MS)
            }
        }
    }

    private fun publish(c: Counts) {
        val ctx = applicationContext
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val last = prefs.getInt(KEY_LAST_TOTAL, 0)
        val total = c.total
        Log.d(TAG, "n=${c.notifications} m=${c.messages} f=${c.friends} t=${c.title} last=$last")
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (total <= 0) {
            nm.cancel(NOTIFICATION_ID)
            prefs.edit().putInt(KEY_LAST_TOTAL, 0).apply()
            return
        }
        // Only interrupt for something new; an unchanged count keeps whatever
        // notification is already showing.
        if (total <= last) return

        createChannel(ctx)
        val parts = mutableListOf<String>()
        if (c.notifications > 0) parts += "${c.notifications} notification${if (c.notifications > 1) "s" else ""}"
        if (c.messages > 0) parts += "${c.messages} message${if (c.messages > 1) "s" else ""}"
        if (c.friends > 0) parts += "${c.friends} friend request${if (c.friends > 1) "s" else ""}"
        val text = if (parts.isNotEmpty()) parts.joinToString(", ")
        else "You have $total new notification${if (total > 1) "s" else ""}"

        val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
            ?.apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP }
            ?: return
        val pi = PendingIntent.getActivity(
            ctx, 0, launch, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val n = NotificationCompat.Builder(ctx, CHANNEL_ID)
            .setSmallIcon(ctx.applicationInfo.icon)
            .setContentTitle("SlimSocial")
            .setContentText(text)
            .setContentIntent(pi)
            .setAutoCancel(true)
            .build()
        try {
            nm.notify(NOTIFICATION_ID, n)
            prefs.edit().putInt(KEY_LAST_TOTAL, total).apply()
        } catch (e: SecurityException) {
            Log.w(TAG, "notification permission not granted", e) // POST_NOTIFICATIONS
        }
    }
}
