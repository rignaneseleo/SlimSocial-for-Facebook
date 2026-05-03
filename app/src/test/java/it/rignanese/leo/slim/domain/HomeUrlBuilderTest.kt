package it.rignanese.leo.slim.domain

import io.kotest.matchers.shouldBe
import org.junit.jupiter.api.Test

class HomeUrlBuilderTest {

    private val builder = HomeUrlBuilder()

    @Test
    fun `default touch host with default suffix`() {
        builder.build(useMbasic = false, recentFirst = false) shouldBe
            FbConstants.URL_TOUCH + FbConstants.SUFFIX_DEFAULT
    }

    @Test
    fun `touch host with recent-first suffix`() {
        builder.build(useMbasic = false, recentFirst = true) shouldBe
            FbConstants.URL_TOUCH + FbConstants.SUFFIX_RECENT
    }

    @Test
    fun `mbasic host with default suffix`() {
        builder.build(useMbasic = true, recentFirst = false) shouldBe
            FbConstants.URL_MBASIC + FbConstants.SUFFIX_DEFAULT
    }

    @Test
    fun `mbasic host with recent-first suffix`() {
        builder.build(useMbasic = true, recentFirst = true) shouldBe
            FbConstants.URL_MBASIC + FbConstants.SUFFIX_RECENT
    }

    @Test
    fun `constants match Flutter consts dart values`() {
        FbConstants.URL_TOUCH shouldBe "https://touch.facebook.com/home.php"
        FbConstants.URL_MBASIC shouldBe "https://mbasic.facebook.com/home.php"
        FbConstants.SUFFIX_RECENT shouldBe "?sk=h_chr"
        FbConstants.SUFFIX_DEFAULT shouldBe "?sk=h_nor"
    }
}
