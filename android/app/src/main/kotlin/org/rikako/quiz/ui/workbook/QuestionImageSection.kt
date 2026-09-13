package org.rikako.quiz.ui.workbook

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil3.compose.AsyncImagePainter
import coil3.compose.SubcomposeAsyncImage
import coil3.compose.SubcomposeAsyncImageContent

/**
 * 設問に紐づく画像。アローダイアグラムなど、画像が無いと解けない設問があるため
 * 本文・選択肢と一緒に必ず描画する。iOS の QuestionImageSection と同じ扱い。
 */
@Composable
fun QuestionImageSection(imageUrls: List<String>, modifier: Modifier = Modifier) {
    if (imageUrls.isEmpty()) return

    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        imageUrls.forEach { url ->
            SubcomposeAsyncImage(
                model = url,
                contentDescription = null,
                contentScale = ContentScale.FillWidth,
                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)),
            ) {
                val state by painter.state.collectAsStateWithLifecycle()
                when (state) {
                    is AsyncImagePainter.State.Loading -> Placeholder(height = 220.dp) {
                        CircularProgressIndicator()
                    }

                    is AsyncImagePainter.State.Error -> Placeholder(height = 180.dp) {
                        Text(
                            text = "画像を読み込めません",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }

                    else -> SubcomposeAsyncImageContent()
                }
            }
        }
    }
}

@Composable
private fun Placeholder(height: Dp, content: @Composable () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(height)
            .clip(RoundedCornerShape(16.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant),
        contentAlignment = Alignment.Center,
    ) {
        content()
    }
}
