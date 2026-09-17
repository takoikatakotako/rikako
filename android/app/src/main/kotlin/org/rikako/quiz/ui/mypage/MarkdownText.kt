package org.rikako.quiz.ui.mypage

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp

internal enum class MarkdownKind { HEADING, PARAGRAPH, LIST_ITEM }
internal data class MarkdownBlock(val kind: MarkdownKind, val content: String, val level: Int = 0)

internal fun parseMarkdown(text: String): List<MarkdownBlock> = text.lines().mapNotNull { line ->
    val value = line.trim()
    when {
        value.isEmpty() -> null
        value.startsWith("### ") -> MarkdownBlock(MarkdownKind.HEADING, value.drop(4), 3)
        value.startsWith("## ") -> MarkdownBlock(MarkdownKind.HEADING, value.drop(3), 2)
        value.startsWith("# ") -> MarkdownBlock(MarkdownKind.HEADING, value.drop(2), 1)
        value.startsWith("- ") || value.startsWith("* ") -> MarkdownBlock(MarkdownKind.LIST_ITEM, value.drop(2))
        value.matches(Regex("^[0-9]+\\. .+")) -> MarkdownBlock(MarkdownKind.LIST_ITEM, value.substringAfter(". "))
        else -> MarkdownBlock(MarkdownKind.PARAGRAPH, value)
    }
}

internal fun parseInlineMarkdown(text: String, linkColor: Color): AnnotatedString = buildAnnotatedString {
    var index = 0
    while (index < text.length) {
        when {
            text.startsWith("**", index) -> {
                val end = text.indexOf("**", index + 2)
                if (end > index + 2) {
                    pushStyle(SpanStyle(fontWeight = FontWeight.Bold))
                    append(text.substring(index + 2, end))
                    pop()
                    index = end + 2
                } else { append(text[index]); index++ }
            }
            text[index] == '`' -> {
                val end = text.indexOf('`', index + 1)
                if (end > index + 1) {
                    pushStyle(SpanStyle(fontFamily = FontFamily.Monospace))
                    append(text.substring(index + 1, end))
                    pop()
                    index = end + 1
                } else { append(text[index]); index++ }
            }
            text[index] == '[' -> {
                val close = text.indexOf("](", index + 1)
                val end = if (close >= 0) text.indexOf(')', close + 2) else -1
                if (end > close + 2) {
                    val url = text.substring(close + 2, end)
                    if (url.startsWith("https://") || url.startsWith("http://")) {
                        val start = length
                        pushStringAnnotation("URL", url)
                        pushStyle(SpanStyle(color = linkColor, textDecoration = TextDecoration.Underline))
                        append(text.substring(index + 1, close))
                        pop()
                        pop()
                        addLink(LinkAnnotation.Url(url), start, length)
                        index = end + 1
                    } else { append(text[index]); index++ }
                } else { append(text[index]); index++ }
            }
            else -> { append(text[index]); index++ }
        }
    }
}

@Composable
internal fun MarkdownText(body: String, modifier: Modifier = Modifier) {
    val color = MaterialTheme.colorScheme.onSurface
    val linkColor = MaterialTheme.colorScheme.primary
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(10.dp)) {
        parseMarkdown(body).forEach { block ->
            val text = parseInlineMarkdown(
                if (block.kind == MarkdownKind.LIST_ITEM) "•  ${block.content}" else block.content,
                linkColor,
            )
            val typography = when (block.level) {
                1 -> MaterialTheme.typography.titleLarge
                2 -> MaterialTheme.typography.titleMedium
                3 -> MaterialTheme.typography.titleSmall
                else -> MaterialTheme.typography.bodyMedium
            }
            Text(
                text = text,
                style = typography.merge(TextStyle(color = color)),
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}
