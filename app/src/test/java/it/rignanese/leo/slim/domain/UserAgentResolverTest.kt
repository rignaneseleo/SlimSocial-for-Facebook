package it.rignanese.leo.slim.domain

import io.kotest.matchers.shouldBe
import org.junit.jupiter.api.Test

class UserAgentResolverTest {

    private val resolver = UserAgentResolver()

    @Test
    fun `custom-enabled with non-blank custom returns custom`() {
        resolver.resolve(
            customEnabled = true,
            customUa = "MyCustomUA/1.0",
            useMbasic = false,
        ) shouldBe "MyCustomUA/1.0"
    }

    @Test
    fun `custom-enabled with non-blank custom wins even when useMbasic is true`() {
        resolver.resolve(
            customEnabled = true,
            customUa = "MyCustomUA/1.0",
            useMbasic = true,
        ) shouldBe "MyCustomUA/1.0"
    }

    @Test
    fun `custom-enabled with blank custom falls through to firefox when not mbasic`() {
        resolver.resolve(
            customEnabled = true,
            customUa = "",
            useMbasic = false,
        ) shouldBe UserAgentResolver.UA_FIREFOX
    }

    @Test
    fun `custom-enabled with whitespace-only custom is treated as blank`() {
        resolver.resolve(
            customEnabled = true,
            customUa = "   ",
            useMbasic = false,
        ) shouldBe UserAgentResolver.UA_FIREFOX
    }

    @Test
    fun `custom-enabled with blank custom falls through to opera mini when mbasic`() {
        resolver.resolve(
            customEnabled = true,
            customUa = "",
            useMbasic = true,
        ) shouldBe UserAgentResolver.UA_OPERA_MINI
    }

    @Test
    fun `custom-enabled with null custom falls through`() {
        resolver.resolve(
            customEnabled = true,
            customUa = null,
            useMbasic = false,
        ) shouldBe UserAgentResolver.UA_FIREFOX

        resolver.resolve(
            customEnabled = true,
            customUa = null,
            useMbasic = true,
        ) shouldBe UserAgentResolver.UA_OPERA_MINI
    }

    @Test
    fun `not custom-enabled and useMbasic returns opera mini`() {
        resolver.resolve(
            customEnabled = false,
            customUa = "ignored-custom",
            useMbasic = true,
        ) shouldBe UserAgentResolver.UA_OPERA_MINI
    }

    @Test
    fun `not custom-enabled and not useMbasic returns firefox`() {
        resolver.resolve(
            customEnabled = false,
            customUa = "ignored-custom",
            useMbasic = false,
        ) shouldBe UserAgentResolver.UA_FIREFOX
    }

    @Test
    fun `strips the Android WebView wv token from the device UA`() {
        // The whole point of the resolver. Measured on-device 2026-08-03:
        // Facebook serves a bundle whose notification popover computes to
        // height 0 for anything advertising `; wv)`.
        val deviceUa =
            "Mozilla/5.0 (Linux; Android 17; Pixel 10 Pro Build/CP2A.260705.006; wv) " +
                "AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 " +
                "Chrome/150.0.7871.181 Mobile Safari/537.36"
        val resolved = UserAgentResolver(deviceUa)
            .resolve(customEnabled = false, customUa = null, useMbasic = false)

        resolved shouldBe
            "Mozilla/5.0 (Linux; Android 17; Pixel 10 Pro Build/CP2A.260705.006) " +
            "AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 " +
            "Chrome/150.0.7871.181 Mobile Safari/537.36"
    }

    @Test
    fun `stripping is a no-op on a UA that has no wv token`() {
        UserAgentResolver.stripWebViewToken(UserAgentResolver.UA_FIREFOX) shouldBe
            UserAgentResolver.UA_FIREFOX
    }

    @Test
    fun `device model and chrome version are preserved, only the marker goes`() {
        val stripped = UserAgentResolver.stripWebViewToken(
            "Mozilla/5.0 (Linux; Android 15; Pixel 9; wv) Chrome/150.0.0.0 Mobile Safari/537.36",
        )
        stripped shouldBe
            "Mozilla/5.0 (Linux; Android 15; Pixel 9) Chrome/150.0.0.0 Mobile Safari/537.36"
    }

    @Test
    fun `UA constants are the Flutter app's desktop Firefox UA and Opera Mini`() {
        // Desktop Firefox, byte-identical to the shipped Flutter app. This is
        // only the JVM/test fallback now — on a device the resolver derives the
        // UA from WebSettings.getDefaultUserAgent and strips the `wv` token
        // (see UserAgentResolver KDoc for the on-device measurements).
        UserAgentResolver.UA_FIREFOX shouldBe
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:124.0) " +
            "Gecko/20100101 Firefox/124.0"
        UserAgentResolver.UA_OPERA_MINI shouldBe
            "Opera/9.80 (Android; Opera Mini/69.0.2254/191.303; U; en) Presto/2.12.423 Version/12.16"
    }
}
