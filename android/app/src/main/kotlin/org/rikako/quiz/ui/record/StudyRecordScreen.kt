package org.rikako.quiz.ui.record

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.compose.runtime.LaunchedEffect
import org.rikako.quiz.data.model.AnswerLogItem
import org.rikako.quiz.data.model.UserSummary

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StudyRecordScreen(
    modifier: Modifier = Modifier,
    viewModel: StudyRecordViewModel = viewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(
        modifier = modifier,
        topBar = { TopAppBar(title = { Text("学習記録") }) },
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            when (val current = state) {
                is StudyRecordUiState.Loading -> Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center,
                ) { CircularProgressIndicator() }

                is StudyRecordUiState.Error -> Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center,
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        Text(current.message, textAlign = TextAlign.Center)
                        Button(onClick = viewModel::load) { Text("再読み込み") }
                    }
                }

                is StudyRecordUiState.Success -> RecordList(
                    state = current,
                    onLoadMore = viewModel::loadMore,
                )
            }
        }
    }
}

@Composable
private fun RecordList(state: StudyRecordUiState.Success, onLoadMore: () -> Unit) {
    val listState = rememberLazyListState()

    // 末尾が見えたら次のページを取りに行く。
    val shouldLoadMore by remember(state) {
        derivedStateOf {
            val lastVisible = listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
            state.canLoadMore && lastVisible >= listState.layoutInfo.totalItemsCount - 3
        }
    }
    LaunchedEffect(listState, state.logs.size) {
        snapshotFlow { shouldLoadMore }.collect { if (it) onLoadMore() }
    }

    LazyColumn(
        state = listState,
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item { SummaryCard(state.summary) }

        item {
            Text(
                text = "回答履歴（${state.total}件）",
                style = MaterialTheme.typography.titleSmall,
            )
        }

        items(state.logs, key = { it.id }) { log -> AnswerLogRow(log) }

        if (state.isLoadingMore) {
            item {
                Box(
                    modifier = Modifier.fillMaxWidth().padding(16.dp),
                    contentAlignment = Alignment.Center,
                ) { CircularProgressIndicator() }
            }
        }
    }
}

@Composable
private fun SummaryCard(summary: UserSummary) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly,
            ) {
                StatColumn("総回答数", "${summary.totalAnswered}")
                StatColumn("正答率", accuracyText(summary.totalCorrect, summary.totalAnswered))
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly,
            ) {
                StatColumn("今週の回答", "${summary.weeklyAnswered}")
                StatColumn("今週の正答率", accuracyText(summary.weeklyCorrect, summary.weeklyAnswered))
            }
            Text(
                text = "学習した日: ${summary.studyDates.size}日",
                style = MaterialTheme.typography.bodySmall,
            )
        }
    }
}

private fun accuracyText(correct: Int, answered: Int): String =
    if (answered > 0) "${correct * 100 / answered}%" else "--%"

@Composable
private fun StatColumn(label: String, value: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, style = MaterialTheme.typography.headlineMedium)
        Text(label, style = MaterialTheme.typography.labelMedium)
    }
}

@Composable
private fun AnswerLogRow(log: AnswerLogItem) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            text = if (log.isCorrect) "○" else "×",
            style = MaterialTheme.typography.titleMedium,
            color = if (log.isCorrect) {
                MaterialTheme.colorScheme.primary
            } else {
                MaterialTheme.colorScheme.error
            },
        )
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = log.questionText,
                style = MaterialTheme.typography.bodyMedium,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = "${log.workbookTitle}・${formatAnsweredAt(log.answeredAt)}",
                style = MaterialTheme.typography.labelSmall,
            )
        }
    }
}

/** answeredAt は RFC3339。端末のロケール実装に依存させたくないので、日付部分だけ取り出す。 */
internal fun formatAnsweredAt(answeredAt: String): String =
    answeredAt.substringBefore('T').takeIf { it.length == 10 }?.replace('-', '/') ?: answeredAt
