package org.rikako.quiz.ui.quiz

import android.media.AudioManager
import android.os.Build
import android.view.HapticFeedbackConstants
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import org.rikako.quiz.data.model.Question
import org.rikako.quiz.ServiceLocator
import org.rikako.quiz.ui.chat.AIChatSheet
import org.rikako.quiz.ui.workbook.QuestionImageSection

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QuizScreen(
    mode: QuizMode,
    onFinish: () -> Unit,
    viewModel: QuizViewModel = viewModel(
        // 出題モードごとに別の ViewModel を持つ（問題集と解き直しで状態を共有しない）。
        key = mode.toString(),
        factory = QuizViewModel.factory(mode),
    ),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val soundEnabled by ServiceLocator.feedbackPreferences.soundEnabled.collectAsStateWithLifecycle()
    val hapticEnabled by ServiceLocator.feedbackPreferences.hapticEnabled.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val androidView = LocalView.current
    val audioManager = remember(context) { context.getSystemService(AudioManager::class.java) }
    val feedbackPlayer = remember(context) { runCatching { QuizFeedbackPlayer(context) }.getOrNull() }
    DisposableEffect(feedbackPlayer) { onDispose { feedbackPlayer?.release() } }
    var showExitConfirmation by remember { mutableStateOf(false) }
    var chatPrompt by remember { mutableStateOf<Pair<Question, Int>?>(null) }

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
    chatPrompt?.let { (question, choice) ->
        AIChatSheet(question = question, selectedChoice = choice, onClose = { chatPrompt = null })
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
                    onSelectChoice = { index ->
                        if (current.selectedChoice == null) {
                            val correct = index == current.currentQuestion.correctIndex
                            viewModel.selectChoice(index)
                            if (hapticEnabled) {
                                val feedback = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                                    if (correct) HapticFeedbackConstants.CONFIRM else HapticFeedbackConstants.REJECT
                                } else {
                                    if (correct) HapticFeedbackConstants.VIRTUAL_KEY else HapticFeedbackConstants.LONG_PRESS
                                }
                                androidView.performHapticFeedback(feedback)
                            }
                            if (soundEnabled && audioManager?.ringerMode == AudioManager.RINGER_MODE_NORMAL) {
                                feedbackPlayer?.play(correct)
                            }
                        }
                    },
                    onNext = viewModel::goToNext,
                    onAskAI = { chatPrompt = current.currentQuestion to
                        (current.selectedChoice ?: current.currentQuestion.correctIndex) },
                )

                is QuizUiState.Finished -> ResultContent(
                    state = current,
                    onRestart = viewModel::restart,
                    onRetryWrongAnswers = viewModel::retryWrongAnswers,
                    onNextChapter = viewModel::startNextChapter,
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
    onAskAI: () -> Unit,
) {
    val question = state.currentQuestion
    val scrollState = rememberScrollState()

    // 解説を読んで下まで送った位置がそのまま次の問題に引き継がれないよう、問題が変わったら先頭に戻す。
    LaunchedEffect(state.currentIndex) { scrollState.scrollTo(0) }

    Column(
        modifier = Modifier.fillMaxSize().verticalScroll(scrollState).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Card(
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("Q${state.currentIndex + 1}", color = MaterialTheme.colorScheme.primary)
                    Text("${state.currentIndex + 1} / ${state.questions.size}")
                }
                LinearProgressIndicator(
                    progress = { (state.currentIndex + 1).toFloat() / state.questions.size },
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
        Card(
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Column(modifier = Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                Text(question.text, style = MaterialTheme.typography.titleMedium)
                QuestionImageSection(imageUrls = question.images)
            }
        }

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
                border = BorderStroke(
                    1.dp,
                    if (isCorrect) {
                        MaterialTheme.colorScheme.primary
                    } else {
                        MaterialTheme.colorScheme.error
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
                        color = if (isCorrect) {
                            MaterialTheme.colorScheme.primary
                        } else {
                            MaterialTheme.colorScheme.error
                        },
                        fontWeight = FontWeight.Bold,
                    )
                    question.explanation?.takeIf { it.isNotBlank() }?.let {
                        Text(it, style = MaterialTheme.typography.bodyMedium)
                    }
                }
            }

            androidx.compose.material3.OutlinedButton(onClick = onAskAI, modifier = Modifier.fillMaxWidth()) {
                Text("AIに質問する")
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
    val correct = revealed && index == correctIndex
    val wrongSelection = revealed && index == selectedChoice && !correct
    val accent = when {
        correct -> MaterialTheme.colorScheme.primary
        wrongSelection -> MaterialTheme.colorScheme.error
        else -> MaterialTheme.colorScheme.outlineVariant
    }
    val background = when {
        correct -> MaterialTheme.colorScheme.primaryContainer
        wrongSelection -> MaterialTheme.colorScheme.errorContainer
        else -> MaterialTheme.colorScheme.surface
    }
    val badge = if (correct || wrongSelection) accent else MaterialTheme.colorScheme.surfaceVariant
    val badgeText = if (correct || wrongSelection) Color.White else MaterialTheme.colorScheme.onSurface

    Surface(
        color = background,
        shape = RoundedCornerShape(18.dp),
        border = BorderStroke(2.dp, accent),
        modifier = Modifier.fillMaxWidth().clickable(enabled = !revealed, onClick = onClick),
    ) {
        Row(
            modifier = Modifier.padding(18.dp),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier.size(34.dp).background(badge, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Text(if (index < 4) "${'A' + index}" else "${index + 1}", color = badgeText, fontWeight = FontWeight.Bold)
            }
            Text(
                text,
                modifier = Modifier.weight(1f),
                color = if (correct || wrongSelection) accent else MaterialTheme.colorScheme.onSurface,
                style = MaterialTheme.typography.bodyMedium,
            )
        }
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
