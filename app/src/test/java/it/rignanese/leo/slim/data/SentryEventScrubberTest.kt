package it.rignanese.leo.slim.data

import io.kotest.matchers.maps.shouldContainKey
import io.kotest.matchers.maps.shouldNotContainKey
import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import io.kotest.matchers.string.shouldNotContain
import org.junit.jupiter.api.Test

class SentryEventScrubberTest {

    @Test
    fun `cookies field is cleared`() {
        val out = SentryEventScrubber.scrub(ScrubInput(cookies = "c_user=12345; xs=abcd"))
        out.cookies shouldBe null
    }

    @Test
    fun `queryString field is cleared`() {
        val out = SentryEventScrubber.scrub(ScrubInput(queryString = "xs=abc&id=1"))
        out.queryString shouldBe null
    }

    @Test
    fun `headers Authorization removed but User-Agent preserved`() {
        val input = ScrubInput(
            headers = mapOf(
                "Authorization" to "Bearer xyz",
                "User-Agent" to "SlimSocial/1.0",
            ),
        )
        val out = SentryEventScrubber.scrub(input)
        out.headers shouldNotContainKey "Authorization"
        out.headers shouldContainKey "User-Agent"
        out.headers["User-Agent"] shouldBe "SlimSocial/1.0"
    }

    @Test
    fun `extras with Token in key removed case-insensitively`() {
        val input = ScrubInput(
            extras = mapOf(
                "AccessToken" to "secret-value",
                "ApiToken" to "another",
                "harmless" to "keep",
            ),
        )
        val out = SentryEventScrubber.scrub(input)
        out.extras shouldNotContainKey "AccessToken"
        out.extras shouldNotContainKey "ApiToken"
        out.extras shouldContainKey "harmless"
    }

    @Test
    fun `extras with password or secret keys removed`() {
        val input = ScrubInput(
            extras = mapOf(
                "user_password" to "p@ss",
                "Secret_Key" to "ssh",
                "kept" to "ok",
            ),
        )
        val out = SentryEventScrubber.scrub(input)
        out.extras shouldNotContainKey "user_password"
        out.extras shouldNotContainKey "Secret_Key"
        out.extras shouldContainKey "kept"
    }

    @Test
    fun `Facebook session cookie pattern redacted from any value string`() {
        val input = ScrubInput(
            tags = mapOf("crumb" to "stuff c_user=12345; more"),
            extras = mapOf("ctx" to "xs=abcd; data datr=ok"),
        )
        val out = SentryEventScrubber.scrub(input)
        out.tags["crumb"]!! shouldContain "<redacted>"
        out.tags["crumb"]!! shouldNotContain "12345"
        out.extras["ctx"]!! shouldContain "<redacted>"
        out.extras["ctx"]!! shouldNotContain "abcd"
    }

    @Test
    fun `cookie-named header keys are dropped`() {
        val input = ScrubInput(headers = mapOf("Cookie" to "c_user=12345"))
        val out = SentryEventScrubber.scrub(input)
        out.headers shouldNotContainKey "Cookie"
    }
}
