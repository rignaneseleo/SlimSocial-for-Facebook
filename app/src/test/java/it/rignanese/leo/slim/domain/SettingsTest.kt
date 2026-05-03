package it.rignanese.leo.slim.domain

import io.kotest.matchers.shouldBe
import org.junit.jupiter.api.Test

class SettingsTest {

    @Test
    fun `DEFAULT features mirror legacy true defaults`() {
        val features = Settings.DEFAULT.features
        features.enableMessenger shouldBe true
        features.hideAds shouldBe true
        features.recentFirst shouldBe false
        features.useMbasic shouldBe false
    }

    @Test
    fun `DEFAULT style toggles mirror legacy true and false defaults`() {
        val style = Settings.DEFAULT.style
        // Legacy TRUE
        style.fixedBar shouldBe true
        style.hideMessengerSidebar shouldBe true
        // Legacy FALSE — at least 5 false defaults asserted
        style.darkTheme shouldBe false
        style.centerText shouldBe false
        style.addSpace shouldBe false
        style.hideStories shouldBe false
        style.darkThemeMessenger shouldBe false
        style.removeMessengerDownload shouldBe false
        style.removeBrowserNotSupported shouldBe false
        style.hideAdsAndPeopleYouMayKnow shouldBe false
        style.fabBtn shouldBe false
        style.adaptMessenger shouldBe false
    }

    @Test
    fun `DEFAULT permissions are all false`() {
        val perms = Settings.DEFAULT.permissions
        perms.gps shouldBe false
        perms.camera shouldBe false
        perms.photo shouldBe false
        perms.photos shouldBe false
        perms.mic shouldBe false
        perms.notifications shouldBe false
    }

    @Test
    fun `DEFAULT customization is empty`() {
        val custom = Settings.DEFAULT.customization
        custom.cssEntries.isEmpty() shouldBe true
        custom.jsEntries.isEmpty() shouldBe true
        custom.activeCssIds.isEmpty() shouldBe true
        custom.activeJsIds.isEmpty() shouldBe true
    }

    @Test
    fun `DEFAULT privacy has sentry opt-out and clean flags`() {
        val privacy = Settings.DEFAULT.privacy
        privacy.sentryEnabled shouldBe true
        privacy.debugMode shouldBe false
        privacy.customJsAcknowledged shouldBe false
    }

    @Test
    fun `DEFAULT webview has empty proxy and null custom UA`() {
        val wv = Settings.DEFAULT.webView
        wv.customUserAgent shouldBe null
        wv.customProxyEnabled shouldBe false
        wv.customProxyHost shouldBe ""
        wv.customProxyPort shouldBe ""
    }

    @Test
    fun `nested data classes use plan-mandated defaults when constructed directly`() {
        FeatureToggles().enableMessenger shouldBe true
        FeatureToggles().hideAds shouldBe true
        StyleToggles().fixedBar shouldBe true
        StyleToggles().hideMessengerSidebar shouldBe true
        PrivacySettings().sentryEnabled shouldBe true
    }
}
