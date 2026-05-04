package it.rignanese.leo.slim.permissions

import android.content.Context
import it.rignanese.leo.slim.domain.PermissionGrants
import it.rignanese.leo.slim.webview.GateDecision
import it.rignanese.leo.slim.webview.PermissionGate
import it.rignanese.leo.slim.webview.WebPermission

/**
 * Production [PermissionGate] implementing the two-layer model from spec §6:
 *
 *  1. App-level toggle (user-controlled, persisted as [PermissionGrants])
 *  2. OS-level grant (queried via [OsPermissionStateReader])
 *
 * Both layers must be open for [decide] to return [GateDecision.Grant].
 *
 * The [grantsProvider] indirection lets us read the freshest [PermissionGrants]
 * synchronously from the WebView callback without holding a stale snapshot;
 * Phase 7 wires this to a `runBlocking { settingsRepo.observe().first().permissions }`
 * (or a cached StateFlow value) inside `MainActivity`.
 */
class RealPermissionGate(
    private val context: Context,
    private val grantsProvider: () -> PermissionGrants,
    private val osReader: OsPermissionStateReader,
) : PermissionGate {

    override fun decide(perm: WebPermission): GateDecision {
        val grants = grantsProvider()
        val appAllowed = when (perm) {
            WebPermission.Camera -> grants.camera
            WebPermission.Mic -> grants.mic
            WebPermission.Location -> grants.gps
            // Both flags exist for legacy parity (Flutter shipped both `photo` and
            // `photos` keys); either being true unlocks photo access.
            WebPermission.Photos -> grants.photo || grants.photos
        }
        if (!appAllowed) return GateDecision.Deny

        // Photos uses Storage Access Framework — no OS runtime permission needed.
        if (perm == WebPermission.Photos) return GateDecision.Grant

        val androidPerm = PermissionMapping.WEB_PERMISSION_TO_ANDROID[perm]
            ?: return GateDecision.Deny
        val osState = osReader.read(context, activity = null, androidPerm = androidPerm)
        return if (osState.status == OsPermissionStatus.Granted)
            GateDecision.Grant else GateDecision.Deny
    }
}
