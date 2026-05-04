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
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import it.rignanese.leo.slim.BuildConfig
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
                title = { Text("Settings") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back",
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
            SectionHeader("Facebook")
            ToggleRow(
                title = "Enable Messenger",
                checked = settings.features.enableMessenger,
                onCheckedChange = { v ->
                    vm.update { it.copy(features = it.features.copy(enableMessenger = v)) }
                },
            )
            ToggleRow(
                title = "Hide some ads (experimental)",
                checked = settings.features.hideAds,
                onCheckedChange = { v ->
                    vm.update { it.copy(features = it.features.copy(hideAds = v)) }
                },
            )
            ToggleRow(
                title = "Show recent posts first",
                checked = settings.features.recentFirst,
                onCheckedChange = { v ->
                    vm.update { it.copy(features = it.features.copy(recentFirst = v)) }
                },
            )
            ToggleRow(
                title = "Use basic version of Facebook",
                subtitle = "It works better on older devices or slower connections",
                checked = settings.features.useMbasic,
                onCheckedChange = { v ->
                    vm.update { it.copy(features = it.features.copy(useMbasic = v)) }
                },
            )

            HorizontalDivider()

            // ---------------- Style ----------------
            SectionHeader("Style")
            ToggleRow(
                title = "Enable dark theme",
                checked = settings.style.darkTheme,
                onCheckedChange = { v ->
                    vm.update { it.copy(style = it.style.copy(darkTheme = v)) }
                },
            )
            ToggleRow(
                title = "Fixed top bar",
                checked = settings.style.fixedBar,
                onCheckedChange = { v ->
                    vm.update { it.copy(style = it.style.copy(fixedBar = v)) }
                },
            )
            ToggleRow(
                title = "Hide stories",
                checked = settings.style.hideStories,
                onCheckedChange = { v ->
                    vm.update { it.copy(style = it.style.copy(hideStories = v)) }
                },
            )
            ToggleRow(
                title = "Center text on posts",
                checked = settings.style.centerText,
                onCheckedChange = { v ->
                    vm.update { it.copy(style = it.style.copy(centerText = v)) }
                },
            )
            ToggleRow(
                title = "Add space between posts",
                checked = settings.style.addSpace,
                onCheckedChange = { v ->
                    vm.update { it.copy(style = it.style.copy(addSpace = v)) }
                },
            )
            ToggleRow(
                title = "Hide Messenger sidebar",
                checked = settings.style.hideMessengerSidebar,
                onCheckedChange = { v ->
                    vm.update { it.copy(style = it.style.copy(hideMessengerSidebar = v)) }
                },
            )
            ToggleRow(
                title = "Dark theme for Messenger",
                checked = settings.style.darkThemeMessenger,
                onCheckedChange = { v ->
                    vm.update { it.copy(style = it.style.copy(darkThemeMessenger = v)) }
                },
            )
            ToggleRow(
                title = "Remove Messenger download prompt",
                checked = settings.style.removeMessengerDownload,
                onCheckedChange = { v ->
                    vm.update { it.copy(style = it.style.copy(removeMessengerDownload = v)) }
                },
            )
            ToggleRow(
                title = "Remove \"browser not supported\" notice",
                checked = settings.style.removeBrowserNotSupported,
                onCheckedChange = { v ->
                    vm.update { it.copy(style = it.style.copy(removeBrowserNotSupported = v)) }
                },
            )
            ToggleRow(
                title = "Hide ads and \"People You May Know\"",
                checked = settings.style.hideAdsAndPeopleYouMayKnow,
                onCheckedChange = { v ->
                    vm.update { it.copy(style = it.style.copy(hideAdsAndPeopleYouMayKnow = v)) }
                },
            )
            ToggleRow(
                title = "Floating action button",
                checked = settings.style.fabBtn,
                onCheckedChange = { v ->
                    vm.update { it.copy(style = it.style.copy(fabBtn = v)) }
                },
            )
            ToggleRow(
                title = "Adapt Messenger layout",
                checked = settings.style.adaptMessenger,
                onCheckedChange = { v ->
                    vm.update { it.copy(style = it.style.copy(adaptMessenger = v)) }
                },
            )

            HorizontalDivider()

            // ---------------- Permissions ----------------
            SectionHeader("Permissions")
            PermissionRow(
                title = "GPS permission",
                description = "Allow Facebook to access your location",
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
                title = "Camera permission",
                description = "Allow Facebook to access the camera",
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
                title = "Gallery permission",
                description = "Allow Facebook to read photos from your gallery",
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
                title = "Photos permission (legacy alias)",
                description = "Legacy duplicate of the gallery permission used by older flows",
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
            SectionHeader("Advanced")
            NavigationRow(
                title = "Use custom CSS style",
                onClick = { onNavigate("editor/css") },
            )
            NavigationRow(
                title = "Run custom JS code",
                onClick = { onNavigate("editor/js") },
            )
            NavigationRow(
                title = "Set a custom user agent",
                onClick = { onNavigate("settings/useragent") },
            )
            NavigationRow(
                title = "Custom proxy",
                onClick = { onNavigate("settings/proxy") },
            )
            SettingsRow(
                title = "Send the code to the developer",
                subtitle = "If the code is safe and useful, it will be included in the next release",
                trailing = {},
                onClick = {
                    val intent = Intent(Intent.ACTION_SENDTO).apply {
                        data = Uri.parse("mailto:rignanese.leo@gmail.com")
                        putExtra(Intent.EXTRA_SUBJECT, "SlimSocial custom code submission")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    runCatching { context.startActivity(intent) }
                },
            )

            HorizontalDivider()

            // ---------------- Privacy ----------------
            SectionHeader("Privacy")
            if (BuildConfig.IS_FULL_FLAVOR) {
                ToggleRow(
                    title = "Send anonymous crash reports (Sentry)",
                    subtitle = "No personal or device information is ever collected",
                    checked = settings.privacy.sentryEnabled,
                    onCheckedChange = { v ->
                        vm.update { it.copy(privacy = it.privacy.copy(sentryEnabled = v)) }
                    },
                )
            }
            ToggleRow(
                title = "Debug mode",
                subtitle = "Show extra logging in the log viewer",
                checked = settings.privacy.debugMode,
                onCheckedChange = { v ->
                    vm.update { it.copy(privacy = it.privacy.copy(debugMode = v)) }
                },
            )

            HorizontalDivider()

            // ---------------- Debug ----------------
            SectionHeader("Debug")
            NavigationRow(
                title = "Log viewer",
                subtitle = "View recent navigation, console, and rule events",
                onClick = { onNavigate("debug") },
            )

            HorizontalDivider()

            // ---------------- About ----------------
            SectionHeader("About")
            NavigationRow(
                title = "About SlimSocial",
                subtitle = "Version ${BuildConfig.VERSION_NAME}",
                onClick = { onNavigate("about") },
            )
        }
    }
}

private enum class PendingPermission { Gps, Camera }
