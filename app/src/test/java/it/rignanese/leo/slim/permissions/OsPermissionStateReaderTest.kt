package it.rignanese.leo.slim.permissions

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import androidx.test.core.app.ApplicationProvider
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class OsPermissionStateReaderTest {

    private val context: Context = ApplicationProvider.getApplicationContext()
    private val activity: Activity = mockk(relaxed = true)
    private val perm = Manifest.permission.CAMERA

    @Before
    fun setUp() {
        mockkStatic(ContextCompat::class)
        mockkStatic(ActivityCompat::class)
    }

    @After
    fun tearDown() {
        unmockkStatic(ContextCompat::class)
        unmockkStatic(ActivityCompat::class)
    }

    @Test
    fun `granted when checkSelfPermission returns PERMISSION_GRANTED`() {
        every { ContextCompat.checkSelfPermission(any(), perm) } returns
            PackageManager.PERMISSION_GRANTED

        val reader = OsPermissionStateReader(hasBeenAsked = { false })
        val state = reader.read(context, activity, perm)

        assert(state.status == OsPermissionStatus.Granted)
        assert(state.androidPerm == perm)
    }

    @Test
    fun `deniable when not granted and rationale true`() {
        every { ContextCompat.checkSelfPermission(any(), perm) } returns
            PackageManager.PERMISSION_DENIED
        every { ActivityCompat.shouldShowRequestPermissionRationale(activity, perm) } returns true

        val reader = OsPermissionStateReader(hasBeenAsked = { true })
        val state = reader.read(context, activity, perm)

        assert(state.status == OsPermissionStatus.Deniable)
    }

    @Test
    fun `deniable when not granted, rationale false, and never asked`() {
        every { ContextCompat.checkSelfPermission(any(), perm) } returns
            PackageManager.PERMISSION_DENIED
        every { ActivityCompat.shouldShowRequestPermissionRationale(activity, perm) } returns false

        val reader = OsPermissionStateReader(hasBeenAsked = { false })
        val state = reader.read(context, activity, perm)

        assert(state.status == OsPermissionStatus.Deniable)
    }

    @Test
    fun `permanently denied when not granted, rationale false, and previously asked`() {
        every { ContextCompat.checkSelfPermission(any(), perm) } returns
            PackageManager.PERMISSION_DENIED
        every { ActivityCompat.shouldShowRequestPermissionRationale(activity, perm) } returns false

        val reader = OsPermissionStateReader(hasBeenAsked = { true })
        val state = reader.read(context, activity, perm)

        assert(state.status == OsPermissionStatus.PermanentlyDenied)
    }

    @Test
    fun `null activity treats rationale as false (first-run path stays Deniable)`() {
        every { ContextCompat.checkSelfPermission(any(), perm) } returns
            PackageManager.PERMISSION_DENIED

        val reader = OsPermissionStateReader(hasBeenAsked = { false })
        val state = reader.read(context, activity = null, androidPerm = perm)

        assert(state.status == OsPermissionStatus.Deniable)
    }

    @Test
    fun `null activity with previously asked falls into PermanentlyDenied`() {
        every { ContextCompat.checkSelfPermission(any(), perm) } returns
            PackageManager.PERMISSION_DENIED

        val reader = OsPermissionStateReader(hasBeenAsked = { true })
        val state = reader.read(context, activity = null, androidPerm = perm)

        assert(state.status == OsPermissionStatus.PermanentlyDenied)
    }
}
