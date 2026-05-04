package it.rignanese.leo.slim

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import androidx.lifecycle.lifecycleScope
import it.rignanese.leo.slim.app.SlimApplication
import it.rignanese.leo.slim.ui.AppRoot
import kotlinx.coroutines.launch

/**
 * Single-activity host. Owns the [MainViewModel] and forwards intent data
 * (deeplinks) into the VM. Compose root is [AppRoot]; no `setContentView`.
 */
class MainActivity : ComponentActivity() {

    private val viewModel: MainViewModel by viewModels {
        MainViewModelFactory((application as SlimApplication).container)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Run Flutter migration once on first launch. Idempotent — subsequent
        // calls are no-ops once the source XML has been renamed to `.migrated`.
        lifecycleScope.launch {
            (application as SlimApplication).container.flutterMigrator.migrateOnce()
        }

        handleIntentUrl(intent)

        setContent {
            MaterialTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    AppRoot(viewModel)
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntentUrl(intent)
    }

    override fun onPause() {
        super.onPause()
        viewModel.flushCookies()
    }

    private fun handleIntentUrl(intent: Intent?) {
        val data = intent?.data?.toString() ?: return
        if (data.isBlank()) return
        viewModel.handleDeeplink(data)
    }
}
