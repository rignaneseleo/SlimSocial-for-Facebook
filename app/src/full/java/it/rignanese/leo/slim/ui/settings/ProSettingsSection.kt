package it.rignanese.leo.slim.ui.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import it.rignanese.leo.slim.R
import it.rignanese.leo.slim.platform.ProEntitlement

/**
 * Full-flavor Settings entry for the PRO theme picker, with the PRO badge
 * when the entitlement is active (spec §3.2) and a lock hint when it isn't.
 * The same composable is declared as an empty body in `src/fdroid` so no
 * PRO UI is compiled into the F-Droid build.
 */
@Composable
fun ProSettingsSection(
    proEntitlement: ProEntitlement,
    onNavigate: (route: String) -> Unit,
) {
    val isPro by proEntitlement.isPro.collectAsStateWithLifecycle()
    SettingsRow(
        title = stringResource(R.string.themes),
        subtitle = stringResource(
            if (isPro) R.string.themes_desc else R.string.themes_locked_subtitle
        ),
        trailing = {
            if (isPro) {
                ProBadge()
            } else {
                Icon(imageVector = Icons.Filled.Lock, contentDescription = null)
            }
        },
        onClick = { onNavigate("themes") },
    )
}

/** Small "PRO" chip shown in Settings while the entitlement is active. */
@Composable
internal fun ProBadge() {
    Text(
        text = stringResource(R.string.pro_badge),
        style = MaterialTheme.typography.labelSmall,
        color = MaterialTheme.colorScheme.onPrimary,
        modifier = Modifier
            .background(MaterialTheme.colorScheme.primary, RoundedCornerShape(6.dp))
            .padding(horizontal = 8.dp, vertical = 2.dp),
    )
}
