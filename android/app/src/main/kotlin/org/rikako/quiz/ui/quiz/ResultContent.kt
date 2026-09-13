package org.rikako.quiz.ui.quiz

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp

@Composable
fun ResultContent(
    state: QuizUiState.Finished,
    onRestart: () -> Unit,
    onBack: () -> Unit,
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item { ScoreCard(state) }
        item { SubmissionRow(state.submission) }

        itemsIndexed(state.questions, key = { _, question -> question.id }) { index, question ->
            val selected = state.answers.getOrNull(index)
            val isCorrect = QuizScoring.isCorrect(question, selected)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = if (isCorrect) "○" else "×",
                    style = MaterialTheme.typography.titleMedium,
                    color = if (isCorrect) {
                        MaterialTheme.colorScheme.primary
                    } else {
                        MaterialTheme.colorScheme.error
                    },
                )
                Text(
                    text = "${index + 1}. ${question.text}",
                    style = MaterialTheme.typography.bodyMedium,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }

        item {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = onRestart, modifier = Modifier.fillMaxWidth()) {
                    Text("もう一度解く")
                }
                OutlinedButton(onClick = onBack, modifier = Modifier.fillMaxWidth()) {
                    Text("問題集に戻る")
                }
            }
        }
    }
}

@Composable
private fun ScoreCard(state: QuizUiState.Finished) {
    val total = state.questions.size
    val accuracy = if (total > 0) state.correctCount * 100 / total else 0

    Card(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(state.title, style = MaterialTheme.typography.titleMedium)
            Text(
                text = "${state.correctCount} / $total",
                style = MaterialTheme.typography.displaySmall,
            )
            Text("正答率 $accuracy%", style = MaterialTheme.typography.bodyMedium)
        }
    }
}

/**
 * 送信状態。再送ボタンは出さない。POST /answers に冪等化が無く、レスポンスだけ失われた
 * ケースで再送すると回答と集計が二重計上されるため（#377）。
 */
@Composable
private fun SubmissionRow(submission: SubmissionState) {
    when (submission) {
        is SubmissionState.Submitting -> Text(
            text = "学習記録を送信中…",
            style = MaterialTheme.typography.bodySmall,
        )

        is SubmissionState.Success -> Text(
            text = "学習記録を送信しました",
            style = MaterialTheme.typography.bodySmall,
        )

        is SubmissionState.Failed -> Text(
            text = "学習記録を送信できませんでした",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.error,
        )
    }
}
