package it.rignanese.leo.slim.ui.settings

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import it.rignanese.leo.slim.BuildConfig
import it.rignanese.leo.slim.webview.UrlOpener

/**
 * Static about screen — version + outbound links handled via [UrlOpener]
 * (Custom Tabs in production).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AboutScreen(
    onBack: () -> Unit,
    urlOpener: UrlOpener,
    onNavigate: (String) -> Unit,
) {
    val context = LocalContext.current

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("About") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState()),
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text("SlimSocial for Facebook", style = MaterialTheme.typography.headlineSmall)
                Text(
                    text = "Version ${BuildConfig.VERSION_NAME}",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            HorizontalDivider()
            NavigationRow(
                title = "Source code",
                subtitle = "GitHub repository",
                onClick = {
                    runCatching {
                        urlOpener.open(context, "https://github.com/rignaneseleo/SlimSocial-for-Facebook")
                    }.recoverCatching {
                        context.startActivity(
                            Intent(
                                Intent.ACTION_VIEW,
                                Uri.parse("https://github.com/rignaneseleo/SlimSocial-for-Facebook"),
                            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                    }
                },
            )
            NavigationRow(
                title = "License (GPL-3.0)",
                onClick = {
                    runCatching {
                        urlOpener.open(context, "https://www.gnu.org/licenses/gpl-3.0.html")
                    }
                },
            )
            NavigationRow(
                title = "Changelog",
                onClick = {
                    runCatching {
                        urlOpener.open(
                            context,
                            "https://raw.githubusercontent.com/rignaneseleo/SlimSocial-for-Facebook/master/Changelog.txt",
                        )
                    }
                },
            )
            NavigationRow(
                title = "Donate / Become a hero",
                subtitle = "Get your name on the list of important supporters",
                onClick = { onNavigate("donate") },
            )
        }
    }
}
