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
    fun `UA constants match Flutter consts dart strings verbatim`() {
        UserAgentResolver.UA_FIREFOX shouldBe
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:124.0) Gecko/20100101 Firefox/124.0"
        UserAgentResolver.UA_OPERA_MINI shouldBe
            "Opera/9.80 (Android; Opera Mini/69.0.2254/191.303; U; en) Presto/2.12.423 Version/12.16"
    }
}
