package it.rignanese.leo.slim.permissions

import android.Manifest
import androidx.activity.result.ActivityResultLauncher
import io.mockk.coVerify
import io.mockk.coVerifyOrder
import io.mockk.mockk
import io.mockk.verify
import it.rignanese.leo.slim.webview.WebPermission
import org.junit.jupiter.api.Test

class PermissionToggleControllerTest {

    private fun controller(
        launcher: ActivityResultLauncher<String>,
        updateGrant: suspend (WebPermission, Boolean) -> Unit,
        markAsked: suspend (String) -> Unit,
    ): PermissionToggleController = PermissionToggleController(launcher, updateGrant, markAsked)

    @Test
    fun `toggle on Photos updates grant directly without launcher`() {
        val launcher = mockk<ActivityResultLauncher<String>>(relaxed = true)
        val updateGrant = mockk<suspend (WebPermission, Boolean) -> Unit>(relaxed = true)
        val markAsked = mockk<suspend (String) -> Unit>(relaxed = true)
        val c = controller(launcher, updateGrant, markAsked)

        c.toggle(WebPermission.Photos, enabling = true)

        coVerify(exactly = 1) { updateGrant.invoke(WebPermission.Photos, true) }
        verify(exactly = 0) { launcher.launch(any()) }
        coVerify(exactly = 0) { markAsked.invoke(any()) }
    }

    @Test
    fun `toggle on Camera launches OS request without immediate grant update`() {
        val launcher = mockk<ActivityResultLauncher<String>>(relaxed = true)
        val updateGrant = mockk<suspend (WebPermission, Boolean) -> Unit>(relaxed = true)
        val markAsked = mockk<suspend (String) -> Unit>(relaxed = true)
        val c = controller(launcher, updateGrant, markAsked)

        c.toggle(WebPermission.Camera, enabling = true)

        verify(exactly = 1) { launcher.launch(Manifest.permission.CAMERA) }
        coVerify(exactly = 0) { updateGrant.invoke(any(), any()) }
        coVerify(exactly = 0) { markAsked.invoke(any()) }
    }

    @Test
    fun `onResult granted true marks asked and updates grant true`() {
        val launcher = mockk<ActivityResultLauncher<String>>(relaxed = true)
        val updateGrant = mockk<suspend (WebPermission, Boolean) -> Unit>(relaxed = true)
        val markAsked = mockk<suspend (String) -> Unit>(relaxed = true)
        val c = controller(launcher, updateGrant, markAsked)

        c.toggle(WebPermission.Camera, enabling = true)
        c.onResult(granted = true)

        coVerifyOrder {
            markAsked.invoke(Manifest.permission.CAMERA)
            updateGrant.invoke(WebPermission.Camera, true)
        }
    }

    @Test
    fun `onResult granted false marks asked and reverts app grant to false`() {
        val launcher = mockk<ActivityResultLauncher<String>>(relaxed = true)
        val updateGrant = mockk<suspend (WebPermission, Boolean) -> Unit>(relaxed = true)
        val markAsked = mockk<suspend (String) -> Unit>(relaxed = true)
        val c = controller(launcher, updateGrant, markAsked)

        c.toggle(WebPermission.Mic, enabling = true)
        c.onResult(granted = false)

        coVerifyOrder {
            markAsked.invoke(Manifest.permission.RECORD_AUDIO)
            updateGrant.invoke(WebPermission.Mic, false)
        }
    }

    @Test
    fun `toggle off clears app grant and does not invoke launcher`() {
        val launcher = mockk<ActivityResultLauncher<String>>(relaxed = true)
        val updateGrant = mockk<suspend (WebPermission, Boolean) -> Unit>(relaxed = true)
        val markAsked = mockk<suspend (String) -> Unit>(relaxed = true)
        val c = controller(launcher, updateGrant, markAsked)

        c.toggle(WebPermission.Camera, enabling = false)

        coVerify(exactly = 1) { updateGrant.invoke(WebPermission.Camera, false) }
        verify(exactly = 0) { launcher.launch(any()) }
        coVerify(exactly = 0) { markAsked.invoke(any()) }
    }

    @Test
    fun `onResult is a no-op when no toggle is pending`() {
        val launcher = mockk<ActivityResultLauncher<String>>(relaxed = true)
        val updateGrant = mockk<suspend (WebPermission, Boolean) -> Unit>(relaxed = true)
        val markAsked = mockk<suspend (String) -> Unit>(relaxed = true)
        val c = controller(launcher, updateGrant, markAsked)

        c.onResult(granted = true)

        coVerify(exactly = 0) { updateGrant.invoke(any(), any()) }
        coVerify(exactly = 0) { markAsked.invoke(any()) }
    }
}
