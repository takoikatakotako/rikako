package org.rikako.quiz.ui.mypage

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileScreen(onBack: () -> Unit, onAccount: () -> Unit, onTransfer: () -> Unit, viewModel: MyPageViewModel) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    var displayName by remember { mutableStateOf("") }
    LaunchedEffect(state.profile?.displayName) { displayName = state.profile?.displayName.orEmpty() }

    Scaffold(topBar = {
        TopAppBar(
            title = { Text("プロフィール") },
            navigationIcon = { IconButton(onClick = onBack) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "戻る")
            } },
        )
    }) { padding ->
        Column(
            modifier = Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(state.profile?.displayName?.takeIf { it.isNotBlank() } ?: "ゲストユーザー", style = MaterialTheme.typography.titleLarge)
                    OutlinedTextField(
                        value = displayName,
                        onValueChange = { displayName = it },
                        label = { Text("表示名") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Button(
                        onClick = { viewModel.saveDisplayName(displayName) },
                        enabled = !state.isSaving && displayName.trim() != state.profile?.displayName.orEmpty(),
                    ) { Text(if (state.isSaving) "保存中…" else "保存") }
                }
            }
            state.error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text("データ管理", style = MaterialTheme.typography.titleMedium)
                    Text("メールアドレスでログインすると、機種変更後も学習記録を引き継げます。")
                    Button(onClick = onAccount) { Text("ログイン・アカウント管理") }
                    Button(onClick = onTransfer) { Text("QRコードで引き継ぐ") }
                }
            }
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("学習記録", style = MaterialTheme.typography.titleMedium)
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text("総解答数")
                        Text("${state.summary?.totalAnswered ?: 0}")
                    }
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text("正答数")
                        Text("${state.summary?.totalCorrect ?: 0}")
                    }
                }
            }
        }
    }
}
