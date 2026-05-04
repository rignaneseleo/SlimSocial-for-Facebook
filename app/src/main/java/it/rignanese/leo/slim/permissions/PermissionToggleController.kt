package it.rignanese.leo.slim.permissions

import androidx.activity.result.ActivityResultLauncher
import it.rignanese.leo.slim.webview.WebPermission

/**
 * Coordinates the user flipping an app-level permission switch in Settings.
 *
 * Flow when enabling a perm whose Android runtime grant is required:
 *   1. UI calls [toggle] (perm, enabling=true)
 *   2. We remember the pending [WebPermission] and ask the OS via [launcher]
 *   3. The host wires the launcher result back to [onResult]
 *   4. We persist `markAsked(androidPerm)` and update the app-level grant to
 *      the user's actual decision (denying at the OS dialog -> app grant stays false)
 *
 * Disabling is symmetrical but synchronous: we clear the app-level grant only;
 * we do not (and cannot) revoke the OS grant.
 *
 * This class is intentionally activity-agnostic — it takes a pre-registered
 * [ActivityResultLauncher] from the caller. Phase 7 wires it.
 */
class PermissionToggleController(
    private val launcher: ActivityResultLauncher<String>,
    private val updateGrant: suspend (WebPermission, Boolean) -> Unit,
    private val markAsked: suspend (String) -> Unit,
) {
    private var pending: WebPermission? = null

    fun toggle(perm: WebPermission, enabling: Boolean) {
        if (!enabling) {
            // User disabled in app — clear app-level grant; do NOT revoke OS grant.
            ioLaunch { updateGrant(perm, false) }
            return
        }
        val androidPerm = PermissionMapping.WEB_PERMISSION_TO_ANDROID[perm]
        if (androidPerm == null) {
            // Photos: no runtime perm needed (SAF handles consent inline).
            ioLaunch { updateGrant(perm, true) }
            return
        }
        pending = perm
        launcher.launch(androidPerm)
    }

    fun onResult(granted: Boolean) {
        val perm = pending ?: return
        pending = null
        val androidPerm = PermissionMapping.WEB_PERMISSION_TO_ANDROID[perm]!!
        ioLaunch {
            markAsked(androidPerm)
            // OS denied -> app-level reverts to false (no orphan app grant
            // pointing at a denied OS permission).
            updateGrant(perm, granted)
        }
    }

    /**
     * Test seam: production wiring replaces this with a coroutine scope launch.
     * Default uses runBlocking so unit tests can verify ordering deterministically.
     */
    var ioLaunch: (suspend () -> Unit) -> Unit = { block ->
        kotlinx.coroutines.runBlocking { block() }
    }
}
