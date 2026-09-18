package org.rikako.quiz.ui.mypage

import android.os.Build
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.Checkbox
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.rikako.quiz.BuildConfig
import org.rikako.quiz.ServiceLocator
import org.rikako.quiz.data.model.ContactRequest

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HelpScreen(onBack: () -> Unit) {
    var showForm by remember { mutableStateOf(false) }
    var subject by remember { mutableStateOf("") }
    var body by remember { mutableStateOf("") }
    var wantsReply by remember { mutableStateOf(false) }
    var email by remember { mutableStateOf("") }
    var sending by remember { mutableStateOf(false) }
    var sent by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    if (sent) {
        AlertDialog(
            onDismissRequest = { sent = false },
            title = { Text("送信完了") },
            text = { Text("お問い合わせを受け付けました。") },
            confirmButton = { TextButton(onClick = { sent = false; showForm = false }) { Text("OK") } },
        )
    }

    Scaffold(topBar = {
        TopAppBar(
            title = { Text(if (showForm) "お問い合わせ" else "よくある質問・お問い合わせ") },
            navigationIcon = { IconButton(onClick = { if (showForm) showForm = false else onBack() }) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "戻る")
            } },
        )
    }) { padding ->
        Column(
            modifier = Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            if (showForm) {
                OutlinedTextField(subject, { subject = it }, label = { Text("件名（任意）") }, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(
                    body, { body = it }, label = { Text("お問い合わせ内容") },
                    minLines = 6, modifier = Modifier.fillMaxWidth(),
                )
                androidx.compose.foundation.layout.Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                    Checkbox(checked = wantsReply, onCheckedChange = { wantsReply = it })
                    Text("返信を希望する")
                }
                if (wantsReply) {
                    OutlinedTextField(email, { email = it }, label = { Text("メールアドレス") }, modifier = Modifier.fillMaxWidth())
                }
                error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
                Button(
                    onClick = {
                        sending = true
                        error = null
                        scope.launch {
                            try {
                                ServiceLocator.learningRepository.submitContact(
                                    ContactRequest(
                                        body = body.trim(),
                                        subject = subject.trim().ifEmpty { null },
                                        email = if (wantsReply) email.trim() else null,
                                        deviceModel = Build.MODEL,
                                        osVersion = "Android ${Build.VERSION.RELEASE}",
                                        appVersion = BuildConfig.VERSION_NAME,
                                    ),
                                )
                                sent = true
                            } catch (cause: CancellationException) {
                                throw cause
                            } catch (_: Exception) {
                                error = "送信に失敗しました。時間をおいて再度お試しください。"
                            } finally {
                                sending = false
                            }
                        }
                    },
                    enabled = !sending && body.isNotBlank() && (!wantsReply || email.isNotBlank()),
                    modifier = Modifier.fillMaxWidth(),
                ) { Text(if (sending) "送信中…" else "送信") }
            } else {
                Text("よくある質問", style = MaterialTheme.typography.titleMedium)
                listOf(
                    "学習記録はどこで見られますか？" to "下部タブの「学習記録」から確認できます。",
                    "選ぶ問題集は後から変更できますか？" to "学習タブの「教材を切り替える」から変更できます。",
                    "ログインしなくても使えますか？" to "はい。ログインなしでも基本的な学習機能を使えます。",
                ).forEach { (question, answer) ->
                    Card(modifier = Modifier.fillMaxWidth()) {
                        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text(question, style = MaterialTheme.typography.titleSmall)
                            Text(answer)
                        }
                    }
                }
                Button(onClick = { showForm = true }, modifier = Modifier.fillMaxWidth()) {
                    Text("お問い合わせフォーム")
                }
            }
        }
    }
}
