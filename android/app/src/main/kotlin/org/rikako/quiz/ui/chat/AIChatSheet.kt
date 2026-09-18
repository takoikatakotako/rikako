package org.rikako.quiz.ui.chat

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import org.rikako.quiz.data.model.Question

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AIChatSheet(
    question: Question,
    selectedChoice: Int,
    onClose: () -> Unit,
    viewModel: AIChatViewModel = viewModel(
        key = "ai-chat-${question.id}-$selectedChoice",
        factory = AIChatViewModel.factory(question, selectedChoice),
    ),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val listState = rememberLazyListState()
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    LaunchedEffect(state.messages.size, state.isLoading) {
        listState.animateScrollToItem(state.messages.size + if (state.isLoading) 1 else 0)
    }

    ModalBottomSheet(onDismissRequest = onClose, sheetState = sheetState) {
        Column(modifier = Modifier.fillMaxWidth().fillMaxHeight(0.85f)) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text("AIに質問する", style = MaterialTheme.typography.titleMedium)
                    Text("残り${state.remainingTurns}回", style = MaterialTheme.typography.labelSmall)
                }
                TextButton(onClick = onClose) { Text("閉じる") }
            }

            LazyColumn(
                state = listState,
                modifier = Modifier.weight(1f).fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item { QuestionContext(question, selectedChoice) }
                itemsIndexed(state.messages) { _, message ->
                    Card(
                        colors = CardDefaults.cardColors(
                            containerColor = if (message.role == "user") {
                                MaterialTheme.colorScheme.primaryContainer
                            } else MaterialTheme.colorScheme.surfaceVariant,
                        ),
                        modifier = Modifier.fillMaxWidth(0.88f)
                            .padding(start = if (message.role == "user") 40.dp else 12.dp,
                                end = if (message.role == "user") 12.dp else 40.dp),
                    ) {
                        Text(message.content, modifier = Modifier.padding(14.dp))
                    }
                }
                if (state.isLoading) {
                    item { CircularProgressIndicator(modifier = Modifier.padding(16.dp)) }
                }
                state.errorMessage?.let { message ->
                    item { Text(message, modifier = Modifier.padding(16.dp), color = MaterialTheme.colorScheme.error) }
                }
            }

            Row(
                modifier = Modifier.fillMaxWidth().padding(12.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.Bottom,
            ) {
                if (state.remainingTurns == 0) {
                    Text("最大回数に達しました", modifier = Modifier.weight(1f).padding(12.dp))
                } else {
                    OutlinedTextField(
                        value = state.inputText,
                        onValueChange = viewModel::updateInput,
                        label = { Text("質問を入力...") },
                        minLines = 1,
                        maxLines = 4,
                        enabled = !state.isLoading,
                        modifier = Modifier.weight(1f),
                    )
                    Button(onClick = viewModel::sendMessage, enabled = state.canSend) { Text("送信") }
                }
            }
        }
    }
}

@Composable
private fun QuestionContext(question: Question, selectedChoice: Int) {
    Card(modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp)) {
        Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(question.text, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Bold)
            if (selectedChoice != question.correctIndex) {
                question.choices.getOrNull(selectedChoice)?.let {
                    Text("あなたの回答: $it", color = MaterialTheme.colorScheme.error)
                }
            }
            question.choices.getOrNull(question.correctIndex)?.let {
                Text("正解: $it", color = MaterialTheme.colorScheme.primary)
            }
            question.explanation?.takeIf { it.isNotBlank() }?.let {
                Text("解説: $it", style = MaterialTheme.typography.bodySmall)
            }
            Text("AIの回答は誤りを含む場合があります", style = MaterialTheme.typography.labelSmall)
        }
    }
}
