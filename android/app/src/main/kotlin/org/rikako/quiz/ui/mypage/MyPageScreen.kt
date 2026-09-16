package org.rikako.quiz.ui.mypage

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Info
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import org.rikako.quiz.ServiceLocator

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MyPageScreen(
    onProfile: () -> Unit,
    onSettings: () -> Unit,
    onNotifications: () -> Unit,
    onHelp: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: MyPageViewModel = viewModel(factory = MyPageViewModel.factory()),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val account by ServiceLocator.accountSession.state.collectAsStateWithLifecycle()
    LaunchedEffect(account.isLoggedIn, account.email) { viewModel.refresh() }
    Scaffold(modifier = modifier, topBar = { TopAppBar(title = { Text("マイページ") }) }) { padding ->
        Column(
            modifier = Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            if (state.isLoading && state.profile == null) {
                CircularProgressIndicator(modifier = Modifier.align(Alignment.CenterHorizontally))
            }
            state.error?.let { error ->
                Text(error, color = MaterialTheme.colorScheme.error)
                Button(onClick = viewModel::refresh) { Text("再読み込み") }
            }
            Card(modifier = Modifier.fillMaxWidth().clickable(onClick = onProfile)) {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(20.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    Icon(Icons.Filled.Person, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                    Column(modifier = Modifier.weight(1f)) {
                        Text(state.profile?.displayName?.takeIf { it.isNotBlank() } ?: "ゲストユーザー", fontWeight = FontWeight.Bold)
                        Text(account.email ?: "無料会員", style = MaterialTheme.typography.bodySmall)
                    }
                    Text("›", style = MaterialTheme.typography.titleLarge)
                }
            }
            Card(modifier = Modifier.fillMaxWidth()) {
                Column {
                    MyPageRow("設定", { Icon(Icons.Filled.Settings, null) }, onSettings)
                    MyPageRow(
                        "お知らせ${if (state.unreadCount > 0) "（${state.unreadCount}）" else ""}",
                        { Icon(Icons.Filled.Notifications, null) },
                        onNotifications,
                    )
                    MyPageRow("よくある質問・お問い合わせ", { Icon(Icons.Filled.Info, null) }, onHelp)
                }
            }
        }
    }
}

@Composable
private fun MyPageRow(title: String, icon: @Composable () -> Unit, onClick: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick).padding(18.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        icon()
        Text(title, modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge)
        Text("›", style = MaterialTheme.typography.titleLarge)
    }
}
