package org.rikako.quiz.ui.mypage

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.rikako.quiz.BuildConfig
import org.rikako.quiz.ServiceLocator

@Composable
fun SettingsScreen(onBack: () -> Unit, onAccount: () -> Unit, onNotifications: () -> Unit) {
    val account by ServiceLocator.accountSession.state.collectAsStateWithLifecycle()
    val soundEnabled by ServiceLocator.feedbackPreferences.soundEnabled.collectAsStateWithLifecycle()
    val hapticEnabled by ServiceLocator.feedbackPreferences.hapticEnabled.collectAsStateWithLifecycle()
    val accent = MaterialTheme.colorScheme.primary
    var confirmReset by remember { mutableStateOf(false) }

    if (confirmReset) {
        AlertDialog(
            onDismissRequest = { confirmReset = false },
            title = { Text("初期設定をやり直す") },
            text = { Text("学習記録とログイン状態は残したまま、問題集を選び直します。") },
            confirmButton = {
                TextButton(onClick = {
                    confirmReset = false
                    ServiceLocator.selectedWorkbookStore.clear()
                    ServiceLocator.onboardingStore.reset()
                }) { Text("やり直す") }
            },
            dismissButton = { TextButton(onClick = { confirmReset = false }) { Text("キャンセル") } },
        )
    }

    Scaffold(
        containerColor = groupedBackground,
        topBar = { ManagementTopBar("設定", onBack) },
    ) { padding ->
        Column(
            modifier = Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Column {
                ManagementSectionTitle("アカウント")
                ManagementCard(Modifier.fillMaxWidth()) {
                    Column {
                        ManagementRow(
                            title = if (account.isLoggedIn) "メールアドレス" else "ログイン / アカウント作成",
                            icon = Icons.Filled.Person,
                            tint = accent,
                            onClick = onAccount,
                            trailing = account.email,
                        )
                        if (!account.isLoggedIn) {
                            Text(
                                "ログインすると、機種変更しても学習記録を引き継げます。",
                                style = MaterialTheme.typography.bodySmall,
                                color = managementSecondary,
                                modifier = Modifier.padding(start = 16.dp, end = 16.dp, bottom = 14.dp),
                            )
                        }
                    }
                }
            }
            Column {
                ManagementSectionTitle("サウンド・フィードバック")
                ManagementCard(Modifier.fillMaxWidth()) {
                    Column {
                        SettingsToggleRow(
                            "効果音", Icons.Filled.PlayArrow, Color(0xFF8B67B8),
                            soundEnabled, ServiceLocator.feedbackPreferences::setSoundEnabled,
                        )
                        ManagementDivider()
                        SettingsToggleRow(
                            "触覚フィードバック", Icons.Filled.CheckCircle, Color(0xFFEF8A24),
                            hapticEnabled, ServiceLocator.feedbackPreferences::setHapticEnabled,
                        )
                    }
                }
            }
            Column {
                ManagementSectionTitle("アプリについて")
                ManagementCard(Modifier.fillMaxWidth()) {
                    Column {
                        ManagementRow(
                            "バージョン", Icons.Filled.Info, Color(0xFF3A85C6),
                            trailing = BuildConfig.VERSION_NAME,
                        )
                        ManagementDivider()
                        ManagementRow(
                            "お知らせ", Icons.Filled.Notifications, Color(0xFFEF8A24),
                            onClick = onNotifications,
                        )
                    }
                }
            }
            Surface(
                onClick = { confirmReset = true },
                modifier = Modifier.fillMaxWidth(),
                color = Color(0xFFE7E8EA),
                shape = RoundedCornerShape(18.dp),
            ) {
                Row(
                    modifier = Modifier.padding(vertical = 16.dp),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    ManagementIcon(Icons.Filled.Refresh, accent)
                    Spacer(Modifier.width(10.dp))
                    Text("初期設定をやり直す", color = accent, fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

@Composable
private fun SettingsToggleRow(
    title: String,
    icon: ImageVector,
    tint: Color,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        ManagementIcon(icon, tint)
        Text(
            title,
            modifier = Modifier.weight(1f),
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.SemiBold,
        )
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}
