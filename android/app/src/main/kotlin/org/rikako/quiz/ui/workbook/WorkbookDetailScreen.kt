package org.rikako.quiz.ui.workbook

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Card
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
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import org.rikako.quiz.data.model.Question

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WorkbookDetailScreen(
    workbookId: Long,
    onBack: () -> Unit,
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
                is WorkbookDetailUiState.Error -> Text(current.message)
                is WorkbookDetailUiState.Success -> LazyColumn(
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                    modifier = Modifier.fillMaxSize(),
                ) {
                    itemsIndexed(current.detail.questions, key = { _, q -> q.id }) { index, question ->
                        QuestionCard(number = index + 1, question = question)
                    }
                }
            }
        }
    }
}

@Composable
private fun QuestionCard(number: Int, question: Question) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Q$number", style = MaterialTheme.typography.labelMedium)
            Text(question.text, style = MaterialTheme.typography.bodyLarge)
            QuestionImageSection(imageUrls = question.images)
            question.choices.forEachIndexed { index, choice ->
                Text("${index + 1}. $choice", style = MaterialTheme.typography.bodyMedium)
            }
        }
    }
}
