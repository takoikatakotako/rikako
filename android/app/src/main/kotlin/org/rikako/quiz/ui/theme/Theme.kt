package org.rikako.quiz.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

/**
 * 配色は iOS（Assets.xcassets/colors）に合わせている。
 *
 * - main        #48AC01 … ブランド色。正解の表示にも使う
 * - correctPink #EE7B77 … 誤答の表示
 *
 * いまはライトテーマ固定。端末がダークでもこの配色で表示する。
 * ダークモード対応は後回しにしている（色を2系統用意して検証する手間に対し、
 * 現時点では優先度が低いため）。iOS も同じくライト前提の配色になっている。
 */
private val Main = Color(0xFF48AC01)
private val MainContainer = Color(0xFFEDF7E6)
private val Wrong = Color(0xFFEE7B77)
private val WrongContainer = Color(0xFFFDEDEC)
private val TextPrimary = Color(0xFF1B1C18)
private val TextSecondary = Color(0xFF45483F)
private val Background = Color(0xFFFBFDF7)
private val Surface = Color(0xFFFFFFFF)
private val SurfaceVariant = Color(0xFFEFF1EA)

private val LightColors = lightColorScheme(
    primary = Main,
    onPrimary = Color.White,
    primaryContainer = MainContainer,
    onPrimaryContainer = Color(0xFF204100),
    secondary = Main,
    onSecondary = Color.White,
    secondaryContainer = MainContainer,
    onSecondaryContainer = Color(0xFF204100),
    error = Wrong,
    onError = Color.White,
    errorContainer = WrongContainer,
    onErrorContainer = Color(0xFF5F1412),
    background = Background,
    onBackground = TextPrimary,
    surface = Surface,
    onSurface = TextPrimary,
    surfaceVariant = SurfaceVariant,
    onSurfaceVariant = TextSecondary,
    outline = Color(0xFF757869),
    outlineVariant = Color(0xFFC5C8BA),
)

@Composable
fun RikakoTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = LightColors, content = content)
}
