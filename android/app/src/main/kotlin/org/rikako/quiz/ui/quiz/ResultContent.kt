package org.rikako.quiz.ui.quiz

import androidx.compose.foundation.clickable
import androidx.compose.foundation.Image
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import org.rikako.quiz.data.model.Question
import org.rikako.quiz.R
import org.rikako.quiz.ui.chat.AIChatSheet
import org.rikako.quiz.ui.workbook.QuestionImageSection

@Composable
fun ResultContent(
    state: QuizUiState.Finished,
    onRestart: () -> Unit,
    onRetryWrongAnswers: () -> Unit,
    onNextChapter: () -> Unit,
    onBack: () -> Unit,
) {
    var selectedResult by remember(state.questions) { mutableStateOf<Int?>(null) }
    var chatPrompt by remember { mutableStateOf<Pair<Question, Int>?>(null) }
    chatPrompt?.let { (question, choice) ->
        AIChatSheet(question = question, selectedChoice = choice, onClose = { chatPrompt = null })
    }
    selectedResult?.let { index ->
        ResultQuestionDetail(
            question = state.questions[index],
            selectedChoice = state.answers.getOrNull(index),
            onDismiss = { selectedResult = null },
            onAskAI = {
                val question = state.questions[index]
                chatPrompt = question to (state.answers.getOrNull(index) ?: question.correctIndex)
                selectedResult = null
            },
        )
    }

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
            Card(modifier = Modifier.fillMaxWidth().clickable { selectedResult = index }) {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(14.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = if (isCorrect) "○" else "×",
                        style = MaterialTheme.typography.titleMedium,
                        color = if (isCorrect) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error,
                    )
                    Text(
                        text = "Q${index + 1}  ${question.text}",
                        style = MaterialTheme.typography.bodyMedium,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }

        item {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                // 間違えた問題があるときは、そこだけ解き直せるようにする（iOS と同じ導線）。
                if (state.wrongQuestions.isNotEmpty()) {
                    Button(onClick = onRetryWrongAnswers, modifier = Modifier.fillMaxWidth()) {
                        Text("間違えた問題を解き直す（${state.wrongQuestions.size}問）")
                    }
                }
                state.nextChapterNumber?.let { number ->
                    Button(onClick = onNextChapter, modifier = Modifier.fillMaxWidth()) {
                        Text("Chapter $number を勉強する")
                    }
                }
                OutlinedButton(onClick = onRestart, modifier = Modifier.fillMaxWidth()) {
                    Text("もう一度解く")
                }
                OutlinedButton(onClick = onBack, modifier = Modifier.fillMaxWidth()) {
                    Text("問題集に戻る")
                }
            }
        }
    }
}

/** iOS の ResultQuestionDetailView 相当。結果から正解・選択肢・解説を見直せる。 */
@Composable
private fun ResultQuestionDetail(
    question: Question,
    selectedChoice: Int?,
    onDismiss: () -> Unit,
    onAskAI: () -> Unit,
) {
    Dialog(onDismissRequest = onDismiss) {
        Surface(shape = MaterialTheme.shapes.large) {
            Column(
                modifier = Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Text(
                    if (QuizScoring.isCorrect(question, selectedChoice)) "正解した問題" else "復習したい問題",
                    style = MaterialTheme.typography.titleMedium,
                )
                Text(question.text, style = MaterialTheme.typography.bodyLarge)
                QuestionImageSection(imageUrls = question.images)
                Text("選択肢", style = MaterialTheme.typography.titleSmall)
                question.choices.forEachIndexed { index, choice ->
                    val correct = index == question.correctIndex
                    val selected = index == selectedChoice
                    val color = when {
                        correct -> MaterialTheme.colorScheme.primary
                        selected -> MaterialTheme.colorScheme.error
                        else -> Color.Unspecified
                    }
                    Text(
                        "${('A' + index)}  $choice${if (correct) "  ✓ 正解" else if (selected) "  選択した回答" else ""}",
                        color = color,
                        style = MaterialTheme.typography.bodyMedium,
                    )
                }
                question.explanation?.takeIf { it.isNotBlank() }?.let {
                    Text("解説", style = MaterialTheme.typography.titleSmall)
                    Text(it, style = MaterialTheme.typography.bodyMedium)
                }
                OutlinedButton(onClick = onAskAI, modifier = Modifier.fillMaxWidth()) {
                    Text("AIに質問する")
                }
                TextButton(onClick = onDismiss, modifier = Modifier.align(Alignment.End)) {
                    Text("閉じる")
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
            val artwork = when {
                accuracy == 100 -> R.drawable.result_100
                accuracy >= 80 -> R.drawable.result_80
                accuracy >= 60 -> R.drawable.result_60
                accuracy >= 40 -> R.drawable.result_40
                else -> R.drawable.result_20
            }
            Image(painterResource(artwork), contentDescription = null, modifier = Modifier.height(150.dp))
            Text(state.title, style = MaterialTheme.typography.titleMedium)
            Text(
                text = "${state.correctCount} / $total",
                style = MaterialTheme.typography.displaySmall,
            )
            Text("正答率 $accuracy%", style = MaterialTheme.typography.bodyMedium)
            Text(
                when {
                    accuracy == 100 -> "完璧です！"
                    accuracy >= 80 -> "よくできました！"
                    accuracy >= 60 -> "もう少しです！"
                    else -> "復習しましょう！"
                },
                color = MaterialTheme.colorScheme.primary,
                style = MaterialTheme.typography.titleMedium,
            )
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
