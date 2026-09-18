package org.rikako.quiz.ui.wrong

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
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
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import org.rikako.quiz.data.model.WrongAnswerQuestion
import org.rikako.quiz.ui.workbook.QuestionImageSection

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WrongAnswersScreen(
    onStartReview: () -> Unit,
    onBack: () -> Unit = {},
    modifier: Modifier = Modifier,
    viewModel: WrongAnswersViewModel = viewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(
        modifier = modifier,
        topBar = { TopAppBar(
            title = { Text("間違えた問題") },
            navigationIcon = { IconButton(onClick = onBack) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "戻る")
            } },
        ) },
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            when (val current = state) {
                is WrongAnswersUiState.Loading -> Centered { CircularProgressIndicator() }

                is WrongAnswersUiState.Error -> Centered {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        Text(current.message, textAlign = TextAlign.Center)
                        Button(onClick = viewModel::load) { Text("再読み込み") }
                    }
                }

                is WrongAnswersUiState.Success -> if (current.questions.isEmpty()) {
                    Centered {
                        Text(
                            text = "間違えた問題はありません",
                            style = MaterialTheme.typography.bodyMedium,
                        )
                    }
                } else {
                    WrongAnswerList(
                        state = current,
                        onToggle = viewModel::toggleExpanded,
                        onLoadMore = viewModel::loadMore,
                        onStartReview = onStartReview,
                    )
                }
            }
        }
    }
}

@Composable
private fun Centered(content: @Composable () -> Unit) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { content() }
}

@Composable
private fun WrongAnswerList(
    state: WrongAnswersUiState.Success,
    onToggle: (Long) -> Unit,
    onLoadMore: () -> Unit,
    onStartReview: () -> Unit,
) {
    val listState = rememberLazyListState()
    val shouldLoadMore by remember(state) {
        derivedStateOf {
            val lastVisible = listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
            state.canLoadMore && lastVisible >= listState.layoutInfo.totalItemsCount - 3
        }
    }
    LaunchedEffect(listState, state.questions.size) {
        snapshotFlow { shouldLoadMore }.collect { if (it) onLoadMore() }
    }

    LazyColumn(
        state = listState,
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Text("${state.total}問", style = MaterialTheme.typography.titleSmall)
        }

        item {
            Button(onClick = onStartReview, modifier = Modifier.fillMaxWidth()) {
                Text("まとめて解き直す")
            }
        }

        items(state.questions, key = { it.id }) { question ->
            WrongAnswerCard(
                question = question,
                expanded = question.id in state.expandedIds,
                onClick = { onToggle(question.id) },
            )
        }

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
private fun WrongAnswerCard(
    question: WrongAnswerQuestion,
    expanded: Boolean,
    onClick: () -> Unit,
) {
    Card(modifier = Modifier.fillMaxWidth().clickable(onClick = onClick)) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(question.text, style = MaterialTheme.typography.bodyLarge)
            QuestionImageSection(imageUrls = question.images)

            if (expanded) {
                question.choices.forEachIndexed { index, choice ->
                    Text(
                        text = "${index + 1}. $choice",
                        style = MaterialTheme.typography.bodyMedium,
                        color = if (index == question.correct) {
                            MaterialTheme.colorScheme.primary
                        } else {
                            MaterialTheme.colorScheme.onSurface
                        },
                    )
                }
                question.explanation?.takeIf { it.isNotBlank() }?.let {
                    Text(it, style = MaterialTheme.typography.bodyMedium)
                }
            } else {
                Text(
                    text = "タップして解説を見る",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.primary,
                )
            }
        }
    }
}
