package org.rikako.quiz.ui.workbook

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
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
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
import org.rikako.quiz.data.model.Workbook

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WorkbookListScreen(
    onWorkbookClick: (Long) -> Unit,
    viewModel: WorkbookListViewModel = viewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(topBar = { TopAppBar(title = { Text("問題集") }) }) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
            when (val current = state) {
                is WorkbookListUiState.Loading -> CircularProgressIndicator()

                is WorkbookListUiState.Error -> Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Text(current.message, style = MaterialTheme.typography.bodyMedium)
                    Button(onClick = viewModel::load) { Text("再読み込み") }
                }

                is WorkbookListUiState.Success -> LazyColumn(
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                    modifier = Modifier.fillMaxSize(),
                ) {
                    items(current.workbooks, key = { it.id }) { workbook ->
                        WorkbookRow(workbook = workbook, onClick = { onWorkbookClick(workbook.id) })
                    }
                }
            }
        }
    }
}

@Composable
private fun WorkbookRow(workbook: Workbook, onClick: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth().clickable(onClick = onClick)) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(workbook.title, style = MaterialTheme.typography.titleMedium)
            if (workbook.description.isNotBlank()) {
                Text(workbook.description, style = MaterialTheme.typography.bodySmall)
            }
            Text("${workbook.questionCount}問", style = MaterialTheme.typography.labelMedium)
        }
    }
}
