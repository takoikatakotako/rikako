package org.rikako.quiz

import org.junit.Assert.assertEquals
import org.junit.Test
import org.rikako.quiz.ui.record.formatAnsweredAt

class AnsweredAtFormatTest {

    @Test
    fun `UTC の時刻を JST の日付にして返す`() {
        // JST では翌日の 8:30。
        assertEquals("2026/09/14", formatAnsweredAt("2026-09-13T23:30:00Z"))
        assertEquals("2026/09/13", formatAnsweredAt("2026-09-13T14:59:59Z"))
    }

    @Test
    fun `オフセット付きでも正しく変換する`() {
        assertEquals("2026/09/14", formatAnsweredAt("2026-09-14T09:00:00+09:00"))
    }

    @Test
    fun `解釈できない値はそのまま返す`() {
        assertEquals("不明", formatAnsweredAt("不明"))
    }
}
