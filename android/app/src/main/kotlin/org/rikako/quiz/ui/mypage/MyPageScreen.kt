package org.rikako.quiz.ui.mypage

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import org.rikako.quiz.R
import org.rikako.quiz.ServiceLocator

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
    val accent = MaterialTheme.colorScheme.primary
    LaunchedEffect(account.isLoggedIn, account.email) { viewModel.refresh() }

    Scaffold(
        modifier = modifier,
        containerColor = groupedBackground,
        topBar = { ManagementTopBar("マイページ") },
    ) { padding ->
        Column(
            modifier = Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            if (state.isLoading && state.profile == null) {
                CircularProgressIndicator(modifier = Modifier.align(Alignment.CenterHorizontally))
            }
            state.error?.let { error ->
                Text(error, color = MaterialTheme.colorScheme.error)
                Button(onClick = viewModel::refresh) { Text("再読み込み") }
            }
            Row(
                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp))
                    .background(Brush.linearGradient(listOf(Color.White, Color(0xFFF3FAEF))))
                    .border(1.dp, accent.copy(alpha = 0.12f), RoundedCornerShape(20.dp))
                    .clickable(onClick = onProfile).padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Box(
                    Modifier.size(58.dp).clip(CircleShape).background(accent.copy(alpha = 0.10f)),
                    contentAlignment = Alignment.Center,
                ) {
                    Image(
                        painter = painterResource(R.drawable.rikako_standing),
                        contentDescription = null,
                        modifier = Modifier.size(49.dp),
                    )
                }
                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(
                        state.profile?.displayName?.takeIf { it.isNotBlank() } ?: "ゲストユーザー",
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.Bold,
                    )
                    Text(
                        account.email ?: "無料会員",
                        style = MaterialTheme.typography.bodyMedium,
                        color = managementSecondary,
                    )
                }
                Text("›", color = managementSecondary, style = MaterialTheme.typography.titleLarge)
            }
            ManagementCard(Modifier.fillMaxWidth()) {
                Column {
                    ManagementRow("設定", Icons.Filled.Settings, accent, onClick = onSettings)
                    ManagementDivider()
                    ManagementRow(
                        "お知らせ", Icons.Filled.Notifications, Color(0xFFEF8A24),
                        onClick = onNotifications,
                        badge = state.unreadCount.takeIf { it > 0 }?.toString(),
                    )
                    ManagementDivider()
                    ManagementRow("よくある質問・お問い合わせ", Icons.Filled.Info, Color(0xFF3A85C6), onClick = onHelp)
                }
            }
        }
    }
}
