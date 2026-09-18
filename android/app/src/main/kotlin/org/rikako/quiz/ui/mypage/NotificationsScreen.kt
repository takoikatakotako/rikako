package org.rikako.quiz.ui.mypage

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.Surface
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.rikako.quiz.data.model.Announcement

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotificationsScreen(onBack: () -> Unit, viewModel: MyPageViewModel) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    var selected by remember { mutableStateOf<Announcement?>(null) }
    Scaffold(topBar = {
        TopAppBar(
            title = { Text(if (selected == null) "お知らせ" else "お知らせ詳細") },
            navigationIcon = { IconButton(onClick = { if (selected != null) selected = null else onBack() }) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "戻る")
            } },
        )
    }) { padding ->
        if (selected == null) {
            if (state.announcements.isEmpty()) {
                Text(
                    if (state.isLoading) "読み込み中…" else "お知らせはありません",
                    modifier = Modifier.padding(padding).padding(20.dp),
                )
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize().padding(padding),
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    items(state.announcements, key = { it.id }) { announcement ->
                        Card(modifier = Modifier.fillMaxWidth().clickable {
                            viewModel.markRead(announcement.id)
                            selected = announcement
                        }) {
                            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                if (viewModel.isUnread(announcement)) {
                                    Surface(color = MaterialTheme.colorScheme.primary, shape = MaterialTheme.shapes.small) {
                                        Text("NEW", modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp), color = MaterialTheme.colorScheme.onPrimary, style = MaterialTheme.typography.labelSmall)
                                    }
                                }
                                Text(announcement.title, style = MaterialTheme.typography.titleSmall)
                                Text(announcement.publishedAt.take(10), style = MaterialTheme.typography.labelSmall)
                                Text(announcement.body.take(100), maxLines = 2)
                            }
                        }
                    }
                }
            }
        } else {
            val announcement = selected ?: return@Scaffold
            Column(
                modifier = Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState()).padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Text(announcement.title, style = MaterialTheme.typography.titleLarge)
                Text(announcement.publishedAt.take(10), style = MaterialTheme.typography.labelSmall)
                MarkdownText(announcement.body)
            }
        }
    }
}
