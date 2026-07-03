package it.rignanese.leo.slim.rules

import io.kotest.matchers.collections.shouldHaveSize
import io.kotest.matchers.nulls.shouldNotBeNull
import io.kotest.matchers.shouldBe
import org.junit.jupiter.api.Test

class FullThemeRuleSourceTest {
    private val source = provideThemeRuleSource()

    @Test
    fun `catalog has five themes with unique ids`() {
        source.availableThemes shouldHaveSize 5
        source.availableThemes.map { it.id }.toSet() shouldHaveSize 5
    }

    @Test
    fun `every descriptor resolves to a rule with a matching id`() {
        for (descriptor in source.availableThemes) {
            val rule = source.ruleFor(descriptor.id).shouldNotBeNull()
            rule.id shouldBe descriptor.id
        }
    }

    @Test
    fun `unknown ids resolve to null`() {
        source.ruleFor("theme_that_does_not_exist") shouldBe null
    }

    @Test
    fun `every theme emits css on facebook and nothing elsewhere`() {
        for (descriptor in source.availableThemes) {
            val rule = source.ruleFor(descriptor.id)!!
            (rule.cssFor("https://m.facebook.com/")!!.isNotBlank()) shouldBe true
            rule.cssFor("https://example.com/") shouldBe null
        }
    }
}
