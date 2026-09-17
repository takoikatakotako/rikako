package org.rikako.quiz.ui.mypage

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
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
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.rikako.quiz.R

@Composable
fun ProfileScreen(onBack: () -> Unit, onAccount: () -> Unit, onTransfer: () -> Unit, viewModel: MyPageViewModel) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val accent = MaterialTheme.colorScheme.primary
    var displayName by remember { mutableStateOf("") }
    LaunchedEffect(state.profile?.displayName) { displayName = state.profile?.displayName.orEmpty() }

    Scaffold(
        containerColor = groupedBackground,
        topBar = { ManagementTopBar("プロフィール", onBack) },
    ) { padding ->
        Column(
            modifier = Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Column(
                modifier = Modifier.fillMaxWidth().padding(vertical = 10.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Box(
                    Modifier.size(92.dp).clip(CircleShape).background(accent.copy(alpha = 0.10f)),
                    contentAlignment = Alignment.Center,
                ) {
                    Image(
                        painter = painterResource(R.drawable.rikako_standing),
                        contentDescription = null,
                        modifier = Modifier.size(78.dp),
                    )
                }
                Text(
                    state.profile?.displayName?.takeIf { it.isNotBlank() } ?: "ゲストユーザー",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                )
            }
            Column {
                ManagementSectionTitle("プロフィール")
                ManagementCard(Modifier.fillMaxWidth()) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(16.dp),
                        ) {
                            Text("表示名", style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold)
                            BasicTextField(
                                value = displayName,
                                onValueChange = { displayName = it },
                                singleLine = true,
                                modifier = Modifier.weight(1f),
                                textStyle = TextStyle(fontSize = 16.sp, color = managementSecondary, textAlign = TextAlign.End),
                                cursorBrush = SolidColor(accent),
                                decorationBox = { innerTextField ->
                                    Box(contentAlignment = Alignment.CenterEnd) {
                                        if (displayName.isBlank()) {
                                            Text("未設定", style = MaterialTheme.typography.bodyLarge, color = managementSecondary)
                                        }
                                        innerTextField()
                                    }
                                },
                            )
                        }
                        if (displayName.trim() != state.profile?.displayName.orEmpty()) {
                            TextButton(
                                onClick = { viewModel.saveDisplayName(displayName) },
                                enabled = !state.isSaving,
                                modifier = Modifier.align(Alignment.End),
                            ) { Text(if (state.isSaving) "保存中…" else "表示名を保存") }
                        }
                    }
                }
            }
            state.error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            Column {
                ManagementSectionTitle("データ管理")
                ManagementCard(Modifier.fillMaxWidth()) {
                    Column {
                        ManagementRow(
                            "ログイン・アカウント管理", Icons.Filled.Person, accent,
                            onClick = onAccount,
                        )
                        ManagementDivider()
                        ManagementRow(
                            "データ引き継ぎ", Icons.Filled.Refresh, Color(0xFF3A85C6),
                            onClick = onTransfer,
                        )
                    }
                }
            }
            Column {
                ManagementSectionTitle("学習記録")
                ManagementCard(Modifier.fillMaxWidth()) {
                    Column {
                        ManagementRow(
                            "総解答数", Icons.Filled.Person, accent,
                            trailing = "${state.summary?.totalAnswered ?: 0}",
                        )
                        ManagementDivider()
                        ManagementRow(
                            "正答数", Icons.Filled.CheckCircle, accent,
                            trailing = "${state.summary?.totalCorrect ?: 0}",
                        )
                    }
                }
            }
        }
    }
}
