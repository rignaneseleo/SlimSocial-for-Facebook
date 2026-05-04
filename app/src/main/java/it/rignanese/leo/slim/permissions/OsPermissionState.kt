package it.rignanese.leo.slim.permissions

import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

/**
 * Tri-state model for the OS-level grant of a single Android runtime permission.
 *
 * - [Granted]: user has granted; the app may proceed.
 * - [Deniable]: not granted yet, but the OS will still show the system dialog if requested.
 *   Either it's never been asked, or it's been denied once non-permanently.
 * - [PermanentlyDenied]: user denied with "don't ask again" — only Settings can recover.
 */
enum class OsPermissionStatus { Granted, Deniable, PermanentlyDenied }

data class OsPermissionState(val androidPerm: String, val status: OsPermissionStatus)

/**
 * Reads the current OS-level state for a given Android runtime permission.
 *
 * Distinguishes "permanently denied" from "deniable" by combining
 * [ActivityCompat.shouldShowRequestPermissionRationale] with a persisted
 * `hasBeenAsked(androidPerm)` flag (which Phase 8 backs by DataStore).
 */
class OsPermissionStateReader(
    private val hasBeenAsked: (String) -> Boolean,
) {
    fun read(context: Context, activity: Activity?, androidPerm: String): OsPermissionState {
        val granted = ContextCompat.checkSelfPermission(context, androidPerm) ==
            PackageManager.PERMISSION_GRANTED
        if (granted) return OsPermissionState(androidPerm, OsPermissionStatus.Granted)

        val rationale = activity?.let {
            ActivityCompat.shouldShowRequestPermissionRationale(it, androidPerm)
        } ?: false

        // First-time: rationale=false AND not asked yet -> Deniable (the OS will show the dialog)
        // Denied once: rationale=true -> Deniable
        // Permanently denied: rationale=false AND asked before
        return if (rationale || !hasBeenAsked(androidPerm)) {
            OsPermissionState(androidPerm, OsPermissionStatus.Deniable)
        } else {
            OsPermissionState(androidPerm, OsPermissionStatus.PermanentlyDenied)
        }
    }
}
