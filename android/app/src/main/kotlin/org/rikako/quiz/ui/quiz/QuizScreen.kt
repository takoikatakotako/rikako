package org.rikako.quiz.ui.quiz

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.activity.compose.BackHandler
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import org.rikako.quiz.ui.workbook.QuestionImageSection

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QuizScreen(
    workbookId: Long,
    onFinish: () -> Unit,
    viewModel: QuizViewModel = viewModel(factory = QuizViewModel.factory(workbookId)),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    var showExitConfirmation by remember { mutableStateOf(false) }

    // 回答済みの問題があるまま抜けると記録が消えるので、システム Back も確認を挟む。
    val needsExitConfirmation = (state as? QuizUiState.Playing)?.hasAnswers == true
    BackHandler(enabled = needsExitConfirmation) { showExitConfirmation = true }

    val requestExit = {
        if (needsExitConfirmation) showExitConfirmation = true else onFinish()
    }

    if (showExitConfirmation) {
        ExitConfirmationDialog(
            onDismiss = { showExitConfirmation = false },
            onDiscard = {
                showExitConfirmation = false
                onFinish()
            },
            onSave = {
                showExitConfirmation = false
                viewModel.submitAnswersAndExit(onFinish)
            },
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(state.title()) },
                navigationIcon = {
                    IconButton(onClick = requestExit) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "戻る")
                    }
                },
            )
        },
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            when (val current = state) {
                is QuizUiState.Loading -> CenterBox { CircularProgressIndicator() }

                is QuizUiState.Error -> CenterBox {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        Text(current.message, textAlign = TextAlign.Center)
                        Button(onClick = viewModel::load) { Text("再読み込み") }
                    }
                }

                is QuizUiState.Playing -> PlayingContent(
                    state = current,
                    onSelectChoice = viewModel::selectChoice,
                    onNext = viewModel::goToNext,
                )

                is QuizUiState.Finished -> ResultContent(
                    state = current,
                    onRetrySubmit = viewModel::submitAnswers,
                    onRestart = viewModel::restart,
                    onBack = onFinish,
                )
            }
        }
    }
}

private fun QuizUiState.title(): String = when (this) {
    is QuizUiState.Playing -> title
    is QuizUiState.Finished -> "結果"
    else -> "問題"
}

@Composable
private fun CenterBox(content: @Composable () -> Unit) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { content() }
}

@Composable
private fun PlayingContent(
    state: QuizUiState.Playing,
    onSelectChoice: (Int) -> Unit,
    onNext: () -> Unit,
) {
    val question = state.currentQuestion
    val scrollState = rememberScrollState()

    // 解説を読んで下まで送った位置がそのまま次の問題に引き継がれないよう、問題が変わったら先頭に戻す。
    LaunchedEffect(state.currentIndex) { scrollState.scrollTo(0) }

    Column(
        modifier = Modifier.fillMaxSize().verticalScroll(scrollState).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        LinearProgressIndicator(
            progress = { (state.currentIndex + 1).toFloat() / state.questions.size },
            modifier = Modifier.fillMaxWidth(),
        )
        Text(
            text = "${state.currentIndex + 1} / ${state.questions.size}",
            style = MaterialTheme.typography.labelMedium,
        )
        Text(question.text, style = MaterialTheme.typography.bodyLarge)
        QuestionImageSection(imageUrls = question.images)

        question.choices.forEachIndexed { index, choice ->
            ChoiceButton(
                text = choice,
                index = index,
                selectedChoice = state.selectedChoice,
                correctIndex = question.correctIndex,
                revealed = state.showExplanation,
                onClick = { onSelectChoice(index) },
            )
        }

        if (state.showExplanation) {
            val isCorrect = QuizScoring.isCorrect(question, state.selectedChoice)
            Card(
                colors = CardDefaults.cardColors(
                    containerColor = if (isCorrect) {
                        MaterialTheme.colorScheme.primaryContainer
                    } else {
                        MaterialTheme.colorScheme.errorContainer
                    },
                ),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(
                        text = if (isCorrect) "正解" else "不正解",
                        style = MaterialTheme.typography.titleMedium,
                    )
                    question.explanation?.takeIf { it.isNotBlank() }?.let {
                        Text(it, style = MaterialTheme.typography.bodyMedium)
                    }
                }
            }

            Button(onClick = onNext, modifier = Modifier.fillMaxWidth()) {
                Text(if (state.isLastQuestion) "結果を見る" else "次の問題へ")
            }
        }
    }
}

@Composable
private fun ChoiceButton(
    text: String,
    index: Int,
    selectedChoice: Int?,
    correctIndex: Int,
    revealed: Boolean,
    onClick: () -> Unit,
) {
    val label = "${index + 1}. $text"

    if (!revealed) {
        OutlinedButton(onClick = onClick, modifier = Modifier.fillMaxWidth()) { Text(label) }
        return
    }

    // 正誤を出した後は押せなくするが、無効化しただけだと Material の disabled 色に
    // 引きずられて正解が見分けられなくなるので、色は明示する。
    when {
        index == correctIndex -> DisabledChoiceButton(
            label = label,
            container = MaterialTheme.colorScheme.primaryContainer,
            content = MaterialTheme.colorScheme.onPrimaryContainer,
        )

        index == selectedChoice -> DisabledChoiceButton(
            label = label,
            container = MaterialTheme.colorScheme.errorContainer,
            content = MaterialTheme.colorScheme.onErrorContainer,
        )

        else -> OutlinedButton(
            onClick = {},
            enabled = false,
            modifier = Modifier.fillMaxWidth(),
        ) { Text(label) }
    }
}

@Composable
private fun DisabledChoiceButton(label: String, container: Color, content: Color) {
    Button(
        onClick = {},
        enabled = false,
        colors = ButtonDefaults.buttonColors(
            disabledContainerColor = container,
            disabledContentColor = content,
        ),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Text(label)
    }
}

/** iOS の「クイズを終了しますか？」と同じ選択肢を出す。 */
@Composable
private fun ExitConfirmationDialog(
    onDismiss: () -> Unit,
    onDiscard: () -> Unit,
    onSave: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("クイズを終了しますか？") },
        text = { Text("ここまでの回答は保存されません。") },
        confirmButton = { TextButton(onClick = onSave) { Text("履歴を保存して戻る") } },
        dismissButton = {
            Row {
                TextButton(onClick = onDiscard) { Text("保存せず戻る") }
                TextButton(onClick = onDismiss) { Text("キャンセル") }
            }
        },
    )
}
