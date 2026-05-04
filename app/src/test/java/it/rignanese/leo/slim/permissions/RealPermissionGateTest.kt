package it.rignanese.leo.slim.permissions

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import it.rignanese.leo.slim.domain.PermissionGrants
import it.rignanese.leo.slim.webview.GateDecision
import it.rignanese.leo.slim.webview.WebPermission
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class RealPermissionGateTest {

    private val context: Context = ApplicationProvider.getApplicationContext()

    private fun gate(
        grants: PermissionGrants,
        osReader: OsPermissionStateReader,
    ) = RealPermissionGate(context, { grants }, osReader)

    private fun reader(status: OsPermissionStatus): OsPermissionStateReader =
        mockk<OsPermissionStateReader>().apply {
            every { read(any(), any(), any()) } answers {
                OsPermissionState(thirdArg<String>(), status)
            }
        }

    // -----------------------------------------------------------------------
    // App-toggle off -> Deny regardless of OS state
    // -----------------------------------------------------------------------

    @Test
    fun `Camera denied when app toggle off even if OS granted`() {
        val g = gate(PermissionGrants(camera = false), reader(OsPermissionStatus.Granted))
        assert(g.decide(WebPermission.Camera) == GateDecision.Deny)
    }

    @Test
    fun `Mic denied when app toggle off even if OS granted`() {
        val g = gate(PermissionGrants(mic = false), reader(OsPermissionStatus.Granted))
        assert(g.decide(WebPermission.Mic) == GateDecision.Deny)
    }

    @Test
    fun `Location denied when app toggle off even if OS granted`() {
        val g = gate(PermissionGrants(gps = false), reader(OsPermissionStatus.Granted))
        assert(g.decide(WebPermission.Location) == GateDecision.Deny)
    }

    @Test
    fun `Photos denied when both app flags off`() {
        val g = gate(
            PermissionGrants(photo = false, photos = false),
            reader(OsPermissionStatus.Granted),
        )
        assert(g.decide(WebPermission.Photos) == GateDecision.Deny)
    }

    // -----------------------------------------------------------------------
    // App-toggle on, OS variations
    // -----------------------------------------------------------------------

    @Test
    fun `Camera granted when app on and OS granted`() {
        val g = gate(PermissionGrants(camera = true), reader(OsPermissionStatus.Granted))
        assert(g.decide(WebPermission.Camera) == GateDecision.Grant)
    }

    @Test
    fun `Camera denied when app on but OS deniable`() {
        val g = gate(PermissionGrants(camera = true), reader(OsPermissionStatus.Deniable))
        assert(g.decide(WebPermission.Camera) == GateDecision.Deny)
    }

    @Test
    fun `Camera denied when app on but OS permanently denied`() {
        val g = gate(PermissionGrants(camera = true), reader(OsPermissionStatus.PermanentlyDenied))
        assert(g.decide(WebPermission.Camera) == GateDecision.Deny)
    }

    @Test
    fun `Mic granted when app on and OS granted`() {
        val g = gate(PermissionGrants(mic = true), reader(OsPermissionStatus.Granted))
        assert(g.decide(WebPermission.Mic) == GateDecision.Grant)
    }

    @Test
    fun `Location granted when gps app flag and OS granted`() {
        val g = gate(PermissionGrants(gps = true), reader(OsPermissionStatus.Granted))
        assert(g.decide(WebPermission.Location) == GateDecision.Grant)
    }

    // -----------------------------------------------------------------------
    // Photos uses SAF — should not consult the OS reader at all
    // -----------------------------------------------------------------------

    @Test
    fun `Photos granted when app photos true does not consult OS reader`() {
        val osReader = mockk<OsPermissionStateReader>()
        val g = gate(PermissionGrants(photos = true), osReader)
        assert(g.decide(WebPermission.Photos) == GateDecision.Grant)
        verify(exactly = 0) { osReader.read(any(), any(), any()) }
    }

    @Test
    fun `Photos granted when only legacy photo flag true`() {
        val osReader = mockk<OsPermissionStateReader>()
        val g = gate(PermissionGrants(photo = true, photos = false), osReader)
        assert(g.decide(WebPermission.Photos) == GateDecision.Grant)
        verify(exactly = 0) { osReader.read(any(), any(), any()) }
    }

    @Test
    fun `Photos granted when both flags true`() {
        val osReader = mockk<OsPermissionStateReader>()
        val g = gate(PermissionGrants(photo = true, photos = true), osReader)
        assert(g.decide(WebPermission.Photos) == GateDecision.Grant)
        verify(exactly = 0) { osReader.read(any(), any(), any()) }
    }
}
