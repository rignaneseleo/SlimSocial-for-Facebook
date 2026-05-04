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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import it.rignanese.leo.slim.BuildConfig
import it.rignanese.leo.slim.R
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
                title = { Text(stringResource(R.string.about)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.back),
                        )
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
                Text(
                    stringResource(R.string.about_app_name),
                    style = MaterialTheme.typography.headlineSmall,
                )
                Text(
                    text = stringResource(R.string.about_version, BuildConfig.VERSION_NAME),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            HorizontalDivider()
            NavigationRow(
                title = stringResource(R.string.source_code),
                subtitle = stringResource(R.string.source_code_subtitle),
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
                title = stringResource(R.string.license_gpl3),
                onClick = {
                    runCatching {
                        urlOpener.open(context, "https://www.gnu.org/licenses/gpl-3.0.html")
                    }
                },
            )
            NavigationRow(
                title = stringResource(R.string.changelog),
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
                title = stringResource(R.string.donate_become_hero),
                subtitle = stringResource(R.string.become_hero_desc),
                onClick = { onNavigate("donate") },
            )
        }
    }
}
