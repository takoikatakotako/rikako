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
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WorkbookDetailScreen(
    workbookId: Long,
    onBack: () -> Unit,
    onStartQuiz: (Int) -> Unit,
    viewModel: WorkbookDetailViewModel = viewModel(factory = WorkbookDetailViewModel.factory(workbookId)),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val title = (state as? WorkbookDetailUiState.Success)?.detail?.title ?: "問題集"

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(title) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "戻る")
                    }
                },
            )
        },
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
            when (val current = state) {
                is WorkbookDetailUiState.Loading -> CircularProgressIndicator()
                is WorkbookDetailUiState.Error -> Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Text(current.message)
                    Button(onClick = viewModel::load) { Text("再読み込み") }
                }
                is WorkbookDetailUiState.Success -> {
                    val sections = WorkbookSections.split(current.detail.questions)
                    LazyColumn(
                        contentPadding = PaddingValues(16.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                        modifier = Modifier.fillMaxSize(),
                    ) {
                        item {
                            Card(
                                colors = CardDefaults.cardColors(
                                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                                ),
                                modifier = Modifier.fillMaxWidth(),
                            ) {
                                Column(
                                    modifier = Modifier.padding(20.dp),
                                    verticalArrangement = Arrangement.spacedBy(8.dp),
                                ) {
                                    Text(current.detail.title, style = MaterialTheme.typography.titleLarge)
                                    if (current.detail.description.isNotBlank()) {
                                        Text(current.detail.description, style = MaterialTheme.typography.bodyMedium)
                                    }
                                    Text("${current.detail.questions.size}問・${sections.size}チャプター")
                                }
                            }
                        }
                        if (sections.isNotEmpty()) {
                            item {
                                Button(onClick = { onStartQuiz(0) }, modifier = Modifier.fillMaxWidth()) {
                                    Text("はじめる  ·  Chapter 1")
                                }
                            }
                        }
                        item {
                            Text("チャプター", style = MaterialTheme.typography.titleMedium)
                        }
                        itemsIndexed(sections) { index, questions ->
                            ChapterRow(
                                number = index + 1,
                                questionCount = questions.size,
                                correctCount = WorkbookSections.correctCount(questions, current.progress),
                                onClick = { onStartQuiz(index) },
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ChapterRow(
    number: Int,
    questionCount: Int,
    correctCount: Int,
    onClick: () -> Unit,
) {
    Card(
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Text(
                "$number",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.primary,
                fontWeight = FontWeight.Bold,
            )
            Text("Section $number", modifier = Modifier.weight(1f), style = MaterialTheme.typography.titleMedium)
            Text("$correctCount / $questionCount", color = MaterialTheme.colorScheme.primary)
        }
    }
}
