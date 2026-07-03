package it.rignanese.leo.slim.ui.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import it.rignanese.leo.slim.R
import it.rignanese.leo.slim.platform.ProEntitlement
import it.rignanese.leo.slim.rules.ThemeRuleSource

/**
 * PRO theme picker (full flavor only). One theme active at a time; the
 * "Default" row clears the selection. Non-PRO users see the full catalog
 * with lock icons — tapping any theme (or the banner CTA) deep-links to the
 * Get PRO screen (spec §3.3).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ThemePickerScreen(
    vm: SettingsViewModel,
    proEntitlement: ProEntitlement,
    themeRuleSource: ThemeRuleSource,
    onGetPro: () -> Unit,
    onBack: () -> Unit,
) {
    val settings by vm.settings.collectAsStateWithLifecycle()
    val isPro by proEntitlement.isPro.collectAsStateWithLifecycle()
    val selected = settings.style.selectedTheme

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.themes)) },
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
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            if (!isPro) {
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Text(
                            text = stringResource(R.string.themes_locked_banner),
                            style = MaterialTheme.typography.bodyMedium,
                        )
                        Button(onClick = onGetPro) {
                            Text(stringResource(R.string.get_pro_cta))
                        }
                    }
                }
            }

            ThemeRowItem(
                name = stringResource(R.string.theme_default),
                swatch = MaterialTheme.colorScheme.surfaceVariant,
                selected = selected == null,
                locked = false,
                onClick = {
                    vm.update { it.copy(style = it.style.copy(selectedTheme = null)) }
                },
            )

            for (theme in themeRuleSource.availableThemes) {
                ThemeRowItem(
                    name = stringResource(theme.nameRes),
                    swatch = Color(theme.previewArgb),
                    selected = selected == theme.id,
                    locked = !isPro,
                    onClick = {
                        if (isPro) {
                            vm.update { it.copy(style = it.style.copy(selectedTheme = theme.id)) }
                        } else {
                            onGetPro()
                        }
                    },
                )
            }
        }
    }
}

@Composable
private fun ThemeRowItem(
    name: String,
    swatch: Color,
    selected: Boolean,
    locked: Boolean,
    onClick: () -> Unit,
) {
    SettingsRow(
        title = name,
        subtitle = null,
        trailing = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(24.dp)
                        .background(swatch, CircleShape),
                )
                Spacer(modifier = Modifier.width(8.dp))
                if (locked) {
                    Icon(imageVector = Icons.Filled.Lock, contentDescription = null)
                } else {
                    RadioButton(selected = selected, onClick = onClick)
                }
            }
        },
        onClick = onClick,
    )
}
