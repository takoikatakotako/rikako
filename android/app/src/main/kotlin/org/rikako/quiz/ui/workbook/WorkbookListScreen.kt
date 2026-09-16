package org.rikako.quiz.ui.workbook

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import org.rikako.quiz.data.model.Workbook

/** 問題集選択・10問チャプターを一画面にまとめた iOS の学習ホーム相当。 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WorkbookListScreen(
    onChapterClick: (Long, Int) -> Unit,
    modifier: Modifier = Modifier,
    viewModel: WorkbookListViewModel = viewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    var showPicker by remember { mutableStateOf(false) }

    Scaffold(
        modifier = modifier,
        topBar = {
            TopAppBar(
                title = { Text("学習") },
                actions = {
                    if ((state as? WorkbookListUiState.Success)?.workbooks?.isNotEmpty() == true) {
                        IconButton(onClick = { showPicker = true }) {
                            Icon(Icons.AutoMirrored.Filled.List, contentDescription = "問題集を変更")
                        }
                    }
                },
            )
        },
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
            when (val current = state) {
                is WorkbookListUiState.Loading -> CircularProgressIndicator()
                is WorkbookListUiState.Error -> Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Text(current.message)
                    Button(onClick = viewModel::load) { Text("再読み込み") }
                }
                is WorkbookListUiState.Success -> StudyHomeContent(
                    state = current,
                    onChapterClick = onChapterClick,
                    onRetry = viewModel::load,
                )
            }
        }
    }

    val current = state as? WorkbookListUiState.Success
    if (showPicker && current != null) {
        ModalBottomSheet(onDismissRequest = { showPicker = false }) {
            LazyColumn(
                contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 32.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                item { Text("問題集を変更", style = MaterialTheme.typography.titleLarge) }
                items(current.workbooks, key = { it.id }) { workbook ->
                    WorkbookPickerRow(
                        workbook = workbook,
                        selected = workbook.id == current.selectedId,
                        onClick = {
                            viewModel.selectWorkbook(workbook.id)
                            showPicker = false
                        },
                    )
                }
            }
        }
    }
}

@Composable
private fun StudyHomeContent(
    state: WorkbookListUiState.Success,
    onChapterClick: (Long, Int) -> Unit,
    onRetry: () -> Unit,
) {
    val workbook = state.selectedWorkbook
    val detail = state.detail
    val sections = detail?.let { WorkbookSections.split(it.questions) }.orEmpty()

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        if (workbook != null) item { WorkbookHero(workbook) }
        if (state.workbooks.isEmpty()) {
            item { Text("このアプリの問題集はまだありません") }
        } else if (state.isDetailLoading) {
            item {
                Box(modifier = Modifier.fillMaxWidth().padding(24.dp), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
            }
        } else if (state.detailError != null) {
            item {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(state.detailError)
                    Button(onClick = onRetry) { Text("再読み込み") }
                }
            }
        } else if (detail != null) {
            item {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text("チャプター", style = MaterialTheme.typography.titleLarge)
                    if (sections.isNotEmpty()) {
                        Button(
                            onClick = { onChapterClick(detail.id, 0) },
                            modifier = Modifier.fillMaxWidth(),
                        ) { Text("はじめる  ·  Section 1") }
                    }
                }
            }
            itemsIndexed(sections) { index, questions ->
                val correct = WorkbookSections.correctCount(questions, state.progress)
                Card(
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
                    modifier = Modifier.fillMaxWidth().clickable { onChapterClick(detail.id, index) },
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(16.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            "${index + 1}",
                            color = MaterialTheme.colorScheme.primary,
                            fontWeight = FontWeight.Bold,
                            style = MaterialTheme.typography.titleMedium,
                        )
                        Text("Section ${index + 1}", modifier = Modifier.weight(1f))
                        Text("$correct / ${questions.size}", color = MaterialTheme.colorScheme.primary)
                    }
                }
            }
        }
    }
}

@Composable
private fun WorkbookHero(workbook: Workbook) {
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primary),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(modifier = Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(
                workbook.title,
                style = MaterialTheme.typography.titleLarge,
                color = MaterialTheme.colorScheme.onPrimary,
                fontWeight = FontWeight.Bold,
            )
            if (workbook.description.isNotBlank()) {
                Text(workbook.description, color = MaterialTheme.colorScheme.onPrimary)
            }
            Text("${workbook.questionCount}問", color = MaterialTheme.colorScheme.onPrimary)
        }
    }
}

@Composable
private fun WorkbookPickerRow(workbook: Workbook, selected: Boolean, onClick: () -> Unit) {
    Card(
        colors = CardDefaults.cardColors(
            containerColor = if (selected) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surface,
        ),
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(workbook.title, style = MaterialTheme.typography.titleMedium)
            Text("${workbook.questionCount}問", style = MaterialTheme.typography.bodySmall)
        }
    }
}
