package it.rignanese.leo.slim.ui.settings

import android.content.Intent
import android.net.Uri
import android.provider.Settings as AndroidSettings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import it.rignanese.leo.slim.BuildConfig
import it.rignanese.leo.slim.R
import it.rignanese.leo.slim.permissions.OsPermissionStateReader
import it.rignanese.leo.slim.permissions.OsPermissionStatus

/**
 * Top-level Settings screen. Material 3 sectioned list. Each toggle reads
 * directly from the live [SettingsViewModel.settings] flow and writes through
 * [SettingsViewModel.update].
 *
 * Permission rows show a tri-state status (off / on / on-denied-by-OS) and
 * provide a one-tap escape hatch into the system settings page when the OS
 * grant is permanently denied — see spec §6.4.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    vm: SettingsViewModel,
    onNavigate: (route: String) -> Unit,
    onBack: () -> Unit,
    osReader: OsPermissionStateReader,
) {
    val settings by vm.settings.collectAsStateWithLifecycle()
    val context = LocalContext.current

    val openAppSettings = remember(context) {
        {
            val intent = Intent(AndroidSettings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.fromParts("package", context.packageName, null)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
        }
    }

    // Permissions are off-by-default; toggling on dispatches an OS request via
    // a launcher whose result we map back to the app-level grant. We stash the
    // pending toggle so the result handler knows which app field to update.
    var pending by remember { mutableStateOf<PendingPermission?>(null) }
    val launcher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission(),
    ) { granted ->
        val target = pending ?: return@rememberLauncherForActivityResult
        pending = null
        vm.update { current ->
            val perms = current.permissions
            val newPerms = when (target) {
                PendingPermission.Gps -> perms.copy(gps = granted)
                PendingPermission.Camera -> perms.copy(camera = granted)
            }
            current.copy(permissions = newPerms)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.settings)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
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
            verticalArrangement = Arrangement.spacedBy(0.dp),
        ) {
            // ---------------- Facebook ----------------
            SectionHeader(stringResource(R.string.section_facebook))
            ToggleRow(
                title = stringResource(R.string.enable_messenger),
                checked = settings.features.enableMessenger,
                onCheckedChange = { v ->
                    vm.update { it.copy(features = it.features.copy(enableMessenger = v)) }
                },
            )
            ToggleRow(
                title = stringResource(R.string.hide_ads),
                checked = settings.features.hideAds,
                onCheckedChange = { v ->
                    vm.update { it.copy(features = it.features.copy(hideAds = v)) }
                },
            )
            ToggleRow(
                title = stringResource(R.string.recent_first),
                checked = settings.features.recentFirst,
                onCheckedChange = { v ->
                    vm.update { it.copy(features = it.features.copy(recentFirst = v)) }
                },
            )
            ToggleRow(
                title = stringResource(R.string.use_mbasic),
                subtitle = stringResource(R.string.use_mbasic_desc),
                checked = settings.features.useMbasic,
                onCheckedChange = { v ->
                    vm.update { it.copy(features = it.features.copy(useMbasic = v)) }
                },
            )

            HorizontalDivider()

            // ---------------- Style ----------------
            SectionHeader(stringResource(R.string.section_style))
            ToggleRow(
                title = stringResource(R.string.dark_theme),
                checked = settings.style.darkTheme,
                onCheckedChange = { v ->
                    vm.update { it.copy(style = it.style.copy(darkTheme = v)) }
                },
            )
            ToggleRow(
                title = stringResource(R.string.fixed_bar),
                checked = settings.style.fixedBar,
                onCheckedChange = { v ->
                    vm.update { it.copy(style = it.style.copy(fixedBar = v)) }
                },
            )
            ToggleRow(
                title = stringResource(R.string.hide_stories),
                checked = settings.style.hideStories,
                onCheckedChange = { v ->
                    vm.update { it.copy(style = it.style.copy(hideStories = v)) }
                },
            )
            ToggleRow(
                title = stringResource(R.string.center_text),
                checked = settings.style.centerText,
                onCheckedChange = { v ->
                    vm.update { it.copy(style = it.style.copy(centerText = v)) }
                },
            )
            ToggleRow(
                title = stringResource(R.string.add_space),
                checked = settings.style.addSpace,
                onCheckedChange = { v ->
                    vm.update { it.copy(style = it.style.copy(addSpace = v)) }
                },
            )
            ToggleRow(
                title = stringResource(R.string.hide_messenger_sidebar),
                checked = settings.style.hideMessengerSidebar,
                onCheckedChange = { v ->
                    vm.update { it.copy(style = it.style.copy(hideMessengerSidebar = v)) }
                },
            )
            ToggleRow(
                title = stringResource(R.string.dark_theme_messenger),
                checked = settings.style.darkThemeMessenger,
                onCheckedChange = { v ->
                    vm.update { it.copy(style = it.style.copy(darkThemeMessenger = v)) }
                },
            )
            ToggleRow(
                title = stringResource(R.string.remove_messenger_download),
                checked = settings.style.removeMessengerDownload,
                onCheckedChange = { v ->
                    vm.update { it.copy(style = it.style.copy(removeMessengerDownload = v)) }
                },
            )
            ToggleRow(
                title = stringResource(R.string.remove_browser_not_supported),
                checked = settings.style.removeBrowserNotSupported,
                onCheckedChange = { v ->
                    vm.update { it.copy(style = it.style.copy(removeBrowserNotSupported = v)) }
                },
            )
            ToggleRow(
                title = stringResource(R.string.hide_ads_and_pymk),
                checked = settings.style.hideAdsAndPeopleYouMayKnow,
                onCheckedChange = { v ->
                    vm.update { it.copy(style = it.style.copy(hideAdsAndPeopleYouMayKnow = v)) }
                },
            )
            ToggleRow(
                title = stringResource(R.string.fab_btn),
                checked = settings.style.fabBtn,
                onCheckedChange = { v ->
                    vm.update { it.copy(style = it.style.copy(fabBtn = v)) }
                },
            )
            ToggleRow(
                title = stringResource(R.string.adapt_messenger),
                checked = settings.style.adaptMessenger,
                onCheckedChange = { v ->
                    vm.update { it.copy(style = it.style.copy(adaptMessenger = v)) }
                },
            )

            HorizontalDivider()

            // ---------------- Permissions ----------------
            SectionHeader(stringResource(R.string.section_permissions))
            PermissionRow(
                title = stringResource(R.string.gps_permission),
                description = stringResource(R.string.gps_permission_desc),
                appEnabled = settings.permissions.gps,
                osStatus = osReader.read(
                    context = context,
                    activity = null,
                    androidPerm = android.Manifest.permission.ACCESS_FINE_LOCATION,
                ).status,
                onToggle = { enabling ->
                    if (!enabling) {
                        vm.update { it.copy(permissions = it.permissions.copy(gps = false)) }
                    } else {
                        pending = PendingPermission.Gps
                        launcher.launch(android.Manifest.permission.ACCESS_FINE_LOCATION)
                    }
                },
                onOpenSystemSettings = openAppSettings,
            )
            PermissionRow(
                title = stringResource(R.string.camera_permission),
                description = stringResource(R.string.camera_permission_desc),
                appEnabled = settings.permissions.camera,
                osStatus = osReader.read(
                    context = context,
                    activity = null,
                    androidPerm = android.Manifest.permission.CAMERA,
                ).status,
                onToggle = { enabling ->
                    if (!enabling) {
                        vm.update { it.copy(permissions = it.permissions.copy(camera = false)) }
                    } else {
                        pending = PendingPermission.Camera
                        launcher.launch(android.Manifest.permission.CAMERA)
                    }
                },
                onOpenSystemSettings = openAppSettings,
            )
            PermissionRow(
                title = stringResource(R.string.photo_permission),
                description = stringResource(R.string.gallery_permission_desc),
                appEnabled = settings.permissions.photo,
                // Photos uses the Storage Access Framework — no OS runtime perm.
                osStatus = if (settings.permissions.photo) OsPermissionStatus.Granted
                else OsPermissionStatus.Deniable,
                onToggle = { enabling ->
                    vm.update { it.copy(permissions = it.permissions.copy(photo = enabling)) }
                },
                onOpenSystemSettings = openAppSettings,
            )
            PermissionRow(
                title = stringResource(R.string.photos_permission_legacy),
                description = stringResource(R.string.photos_permission_legacy_desc),
                appEnabled = settings.permissions.photos,
                osStatus = if (settings.permissions.photos) OsPermissionStatus.Granted
                else OsPermissionStatus.Deniable,
                onToggle = { enabling ->
                    vm.update { it.copy(permissions = it.permissions.copy(photos = enabling)) }
                },
                onOpenSystemSettings = openAppSettings,
            )

            HorizontalDivider()

            // ---------------- Advanced ----------------
            SectionHeader(stringResource(R.string.section_advanced))
            NavigationRow(
                title = stringResource(R.string.custom_css),
                onClick = { onNavigate("editor/css") },
            )
            NavigationRow(
                title = stringResource(R.string.custom_js),
                onClick = { onNavigate("editor/js") },
            )
            NavigationRow(
                title = stringResource(R.string.custom_useragent),
                onClick = { onNavigate("settings/useragent") },
            )
            NavigationRow(
                title = stringResource(R.string.custom_proxy),
                onClick = { onNavigate("settings/proxy") },
            )
            val sendToDevSubject = stringResource(R.string.send_to_dev_subject)
            SettingsRow(
                title = stringResource(R.string.send_to_dev),
                subtitle = stringResource(R.string.send_to_dev_desc_v2),
                trailing = {},
                onClick = {
                    val intent = Intent(Intent.ACTION_SENDTO).apply {
                        data = Uri.parse("mailto:rignanese.leo@gmail.com")
                        putExtra(Intent.EXTRA_SUBJECT, sendToDevSubject)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    runCatching { context.startActivity(intent) }
                },
            )

            HorizontalDivider()

            // ---------------- Privacy ----------------
            SectionHeader(stringResource(R.string.section_privacy))
            if (BuildConfig.IS_FULL_FLAVOR) {
                ToggleRow(
                    title = stringResource(R.string.send_anonymous_crash_reports),
                    subtitle = stringResource(R.string.send_anonymous_crash_reports_desc),
                    checked = settings.privacy.sentryEnabled,
                    onCheckedChange = { v ->
                        vm.update { it.copy(privacy = it.privacy.copy(sentryEnabled = v)) }
                    },
                )
            }
            ToggleRow(
                title = stringResource(R.string.debug_mode),
                subtitle = stringResource(R.string.debug_mode_desc),
                checked = settings.privacy.debugMode,
                onCheckedChange = { v ->
                    vm.update { it.copy(privacy = it.privacy.copy(debugMode = v)) }
                },
            )

            HorizontalDivider()

            // ---------------- Debug ----------------
            SectionHeader(stringResource(R.string.section_debug))
            NavigationRow(
                title = stringResource(R.string.log_viewer),
                subtitle = stringResource(R.string.log_viewer_desc),
                onClick = { onNavigate("debug") },
            )

            HorizontalDivider()

            // ---------------- About ----------------
            SectionHeader(stringResource(R.string.section_about))
            NavigationRow(
                title = stringResource(R.string.about_slimsocial),
                subtitle = stringResource(R.string.about_version, BuildConfig.VERSION_NAME),
                onClick = { onNavigate("about") },
            )
        }
    }
}

private enum class PendingPermission { Gps, Camera }
