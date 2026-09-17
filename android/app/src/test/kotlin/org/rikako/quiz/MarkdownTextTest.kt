package org.rikako.quiz

import androidx.compose.ui.graphics.Color
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test
import org.rikako.quiz.ui.mypage.MarkdownKind
import org.rikako.quiz.ui.mypage.parseInlineMarkdown
import org.rikako.quiz.ui.mypage.parseMarkdown

class MarkdownTextTest {
    @Test fun `見出しと箇条書きを分けて表示する`() {
        val blocks = parseMarkdown("# お知らせ\n\n- ひとつ\n2. ふたつ\n本文")
        assertEquals(MarkdownKind.HEADING, blocks[0].kind)
        assertEquals(1, blocks[0].level)
        assertEquals(MarkdownKind.LIST_ITEM, blocks[1].kind)
        assertEquals("ふたつ", blocks[2].content)
        assertEquals(MarkdownKind.PARAGRAPH, blocks[3].kind)
    }

    @Test fun `リンクはhttp系だけクリック可能にする`() {
        val text = parseInlineMarkdown("**重要** [詳細](https://rikako.org) [危険](javascript:alert)", Color.Green)
        assertEquals("重要 詳細 [危険](javascript:alert)", text.text)
        assertEquals("https://rikako.org", text.getStringAnnotations("URL", 4, 5).single().item)
        assertFalse(text.getStringAnnotations("URL", text.length - 10, text.length).any())
    }
}
