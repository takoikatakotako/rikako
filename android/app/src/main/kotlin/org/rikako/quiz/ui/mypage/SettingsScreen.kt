package org.rikako.quiz.ui.mypage

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.rikako.quiz.BuildConfig
import org.rikako.quiz.ServiceLocator

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(onBack: () -> Unit, onAccount: () -> Unit, onNotifications: () -> Unit) {
    val account by ServiceLocator.accountSession.state.collectAsStateWithLifecycle()
    val soundEnabled by ServiceLocator.feedbackPreferences.soundEnabled.collectAsStateWithLifecycle()
    val hapticEnabled by ServiceLocator.feedbackPreferences.hapticEnabled.collectAsStateWithLifecycle()
    var confirmReset by remember { mutableStateOf(false) }

    if (confirmReset) {
        AlertDialog(
            onDismissRequest = { confirmReset = false },
            title = { Text("初期設定をやり直す") },
            text = { Text("学習記録とログイン状態は残したまま、問題集を選び直します。") },
            confirmButton = { TextButton(onClick = {
                confirmReset = false
                ServiceLocator.selectedWorkbookStore.clear()
                ServiceLocator.onboardingStore.reset()
            }) { Text("やり直す") } },
            dismissButton = { TextButton(onClick = { confirmReset = false }) { Text("キャンセル") } },
        )
    }

    Scaffold(topBar = {
        TopAppBar(
            title = { Text("設定") },
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
                    Text("アカウント", style = MaterialTheme.typography.titleMedium)
                    Text(account.email ?: "ログインしていません")
                    Button(onClick = onAccount) { Text(if (account.isLoggedIn) "アカウントを管理" else "ログイン / アカウント作成") }
                }
            }
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    Text("サウンド・フィードバック", style = MaterialTheme.typography.titleMedium)
                    Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
                        Text("効果音")
                        Switch(checked = soundEnabled, onCheckedChange = ServiceLocator.feedbackPreferences::setSoundEnabled)
                    }
                    Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
                        Text("触覚フィードバック")
                        Switch(checked = hapticEnabled, onCheckedChange = ServiceLocator.feedbackPreferences::setHapticEnabled)
                    }
                }
            }
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text("アプリについて", style = MaterialTheme.typography.titleMedium)
                    Text("バージョン ${BuildConfig.VERSION_NAME}")
                    OutlinedButton(onClick = onNotifications) { Text("お知らせ") }
                }
            }
            OutlinedButton(onClick = { confirmReset = true }, modifier = Modifier.fillMaxWidth()) {
                Text("初期設定をやり直す")
            }
        }
    }
}
