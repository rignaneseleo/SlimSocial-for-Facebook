package it.rignanese.leo.slim.domain

import io.kotest.matchers.shouldBe
import io.kotest.matchers.types.shouldBeInstanceOf
import org.junit.jupiter.api.Test

class UrlRouterTest {

    private val router = UrlRouter()

    @Test
    fun `m facebook subdomain routes InApp`() {
        router.route("https://m.facebook.com/foo").shouldBeInstanceOf<Route.InApp>()
    }

    @Test
    fun `www facebook subdomain routes InApp`() {
        router.route("https://www.facebook.com").shouldBeInstanceOf<Route.InApp>()
    }

    @Test
    fun `bare facebook host routes InApp`() {
        router.route("https://facebook.com").shouldBeInstanceOf<Route.InApp>()
    }

    @Test
    fun `mbasic facebook routes InApp`() {
        router.route("https://mbasic.facebook.com/home.php").shouldBeInstanceOf<Route.InApp>()
    }

    @Test
    fun `touch facebook routes InApp`() {
        router.route("https://touch.facebook.com/home.php").shouldBeInstanceOf<Route.InApp>()
    }

    @Test
    fun `fb dot me routes InApp`() {
        router.route("https://fb.me/x").shouldBeInstanceOf<Route.InApp>()
    }

    @Test
    fun `www fb dot com routes InApp`() {
        router.route("https://www.fb.com/foo").shouldBeInstanceOf<Route.InApp>()
    }

    @Test
    fun `messenger dot com routes Messenger`() {
        router.route("https://messenger.com/inbox").shouldBeInstanceOf<Route.Messenger>()
    }

    @Test
    fun `m dot me routes Messenger`() {
        router.route("https://m.me/abc").shouldBeInstanceOf<Route.Messenger>()
    }

    @Test
    fun `unrelated host routes External`() {
        router.route("https://example.com/").shouldBeInstanceOf<Route.External>()
    }

    @Test
    fun `notfacebook dot com routes External (suffix safety)`() {
        router.route("https://notfacebook.com/").shouldBeInstanceOf<Route.External>()
    }

    @Test
    fun `host containing facebook substring without dot routes External`() {
        router.route("https://fakefacebook.com/").shouldBeInstanceOf<Route.External>()
    }

    @Test
    fun `unparseable string routes External`() {
        router.route("not a url").shouldBeInstanceOf<Route.External>()
    }

    @Test
    fun `empty string routes External`() {
        router.route("").shouldBeInstanceOf<Route.External>()
    }

    @Test
    fun `route preserves the original URL string`() {
        val original = "https://m.facebook.com/path?q=1"
        val route = router.route(original) as Route.InApp
        route.url shouldBe original
    }

    @Test
    fun `custom hosts via constructor still route InApp`() {
        val custom = UrlRouter(
            fbHosts = setOf("custom-fb.example"),
            messengerHosts = setOf("custom-msg.example"),
        )
        custom.route("https://custom-fb.example/").shouldBeInstanceOf<Route.InApp>()
        custom.route("https://sub.custom-fb.example/").shouldBeInstanceOf<Route.InApp>()
        custom.route("https://custom-msg.example/").shouldBeInstanceOf<Route.Messenger>()
        custom.route("https://facebook.com/").shouldBeInstanceOf<Route.External>()
    }
}
