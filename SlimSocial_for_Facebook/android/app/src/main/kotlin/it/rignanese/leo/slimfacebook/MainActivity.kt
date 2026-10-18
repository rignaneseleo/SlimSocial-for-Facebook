package it.rignanese.leo.slimfacebook

import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Background notifications (#269). Dart side: lib/utils/notifications.dart
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "slimsocial/notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enable" -> {
                        val minutes = (call.argument<Int>("minutes") ?: 30).coerceAtLeast(15)
                        NotificationWorker.createChannel(applicationContext)
                        val request = PeriodicWorkRequestBuilder<NotificationWorker>(
                            minutes.toLong(), TimeUnit.MINUTES
                        ).setConstraints(
                            Constraints.Builder()
                                .setRequiredNetworkType(NetworkType.CONNECTED)
                                .build()
                        ).build()
                        WorkManager.getInstance(applicationContext).enqueueUniquePeriodicWork(
                            NotificationWorker.UNIQUE_WORK_NAME,
                            ExistingPeriodicWorkPolicy.UPDATE,
                            request
                        )
                        result.success(null)
                    }
                    "disable" -> {
                        WorkManager.getInstance(applicationContext)
                            .cancelUniqueWork(NotificationWorker.UNIQUE_WORK_NAME)
                        NotificationWorker.clear(applicationContext)
                        result.success(null)
                    }
                    "clear" -> {
                        NotificationWorker.clear(applicationContext)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
