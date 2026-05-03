package it.rignanese.leo.slim.data

import io.kotest.matchers.collections.shouldHaveSize
import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import io.kotest.matchers.string.shouldNotContain
import org.junit.jupiter.api.Test

class LogBufferTest {

    @Test
    fun `ring buffer drops oldest entries past capacity`() {
        val buffer = LogBuffer(capacity = 500)
        repeat(600) { i ->
            buffer.record(LogCategory.OTHER, "msg-$i", now = i.toLong())
        }
        val snap = buffer.snapshot()
        snap shouldHaveSize 500
        snap.first().message shouldBe "msg-100"
        snap.last().message shouldBe "msg-599"
    }

    @Test
    fun `Facebook session cookie name=value is redacted on record`() {
        val buffer = LogBuffer()
        buffer.record(LogCategory.CONSOLE, "headers: c_user=12345; xs=abcd; other=keep")
        val msg = buffer.snapshot().single().message
        msg shouldContain "c_user=<redacted>"
        msg shouldContain "xs=<redacted>"
        msg shouldContain "other=keep"
        msg shouldNotContain "12345"
        msg shouldNotContain "abcd"
    }

    @Test
    fun `URL query strings are stripped entirely on record`() {
        val buffer = LogBuffer()
        buffer.record(
            LogCategory.NAV,
            "navigate https://m.facebook.com/foo?xs=abc&id=1",
        )
        val msg = buffer.snapshot().single().message
        msg shouldContain "https://m.facebook.com/foo"
        msg shouldNotContain "?"
        msg shouldNotContain "xs="
        msg shouldNotContain "id=1"
    }

    @Test
    fun `exportRedacted formats as bracketed timestamp + category + message`() {
        val buffer = LogBuffer()
        buffer.record(LogCategory.LIFECYCLE, "started", now = 1234L)
        buffer.record(LogCategory.NAV, "tapped", now = 5678L)
        val text = buffer.exportRedacted()
        text shouldContain "[1234] LIFECYCLE: started"
        text shouldContain "[5678] NAV: tapped"
    }

    @Test
    fun `clear empties the buffer`() {
        val buffer = LogBuffer()
        buffer.record(LogCategory.OTHER, "a")
        buffer.record(LogCategory.OTHER, "b")
        buffer.clear()
        buffer.snapshot() shouldHaveSize 0
    }
}
