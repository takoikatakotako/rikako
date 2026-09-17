package org.rikako.quiz.ui.onboarding

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.clickable
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import org.rikako.quiz.AppFlavor
import org.rikako.quiz.ServiceLocator
import org.rikako.quiz.R
import org.rikako.quiz.data.model.Workbook

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OnboardingScreen() {
    val revision by ServiceLocator.onboardingStore.revision.collectAsStateWithLifecycle()
    val viewModel: OnboardingViewModel = viewModel(key = "onboarding-$revision")
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val isChemistry = AppFlavor.current.slug == "high-school-chemistry"
    val uriHandler = LocalUriHandler.current
    BackHandler(enabled = state.page > 0) { viewModel.back() }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("初期設定") },
                navigationIcon = {
                    if (state.page > 0) {
                        IconButton(onClick = viewModel::back) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "戻る")
                        }
                    }
                },
            )
        },
        bottomBar = {
            if (state.page != 2) {
                Button(
                    onClick = if (state.page == 5) viewModel::start else viewModel::next,
                    enabled = !state.starting && (state.page != 4 || state.acceptedTerms),
                    modifier = Modifier.fillMaxWidth().padding(start = 24.dp, end = 24.dp, bottom = 24.dp),
                ) {
                    if (state.starting) CircularProgressIndicator()
                    else Text(when (state.page) {
                        1 -> "問題集を選ぶ"
                        4 -> "同意して次へ"
                        5 -> "はじめる"
                        else -> "次へ"
                    })
                }
            }
        },
    ) { padding ->
        Column(
            modifier = Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            LinearProgressIndicator(progress = { (state.page + 1) / 6f }, modifier = Modifier.fillMaxWidth())
            Text("${state.page + 1} / 6", style = MaterialTheme.typography.labelMedium)
            when (state.page) {
                0 -> IntroPage(
                    title = "こんにちは、理科子です！",
                    lines = if (isChemistry) listOf(
                        "このアプリは高校生向けの化学を楽しく学ぶためのアプリです！",
                        "一緒に楽しく勉強していこうね！",
                    ) else listOf(
                        "ITパスポートの問題を一緒に解いていこうね！",
                        "毎日少しずつ進めていこう！",
                    ),
                )
                1 -> IntroPage(
                    title = "君にあった分野を選ぼう！",
                    lines = listOf(
                        "次のページで問題集を選択できます。",
                        "特になければ、おすすめの問題集から始めてみよう！",
                    ),
                )
                2 -> {
                    Text("最初の問題集を選ぼう", style = MaterialTheme.typography.headlineSmall)
                    Text("おすすめの1冊を用意したよ。まずはここから始めてみよう！", textAlign = TextAlign.Center)
                    when {
                        state.loadingWorkbooks -> CircularProgressIndicator()
                        state.workbookError != null -> {
                            Text(state.workbookError ?: "", color = MaterialTheme.colorScheme.error)
                            Button(onClick = viewModel::loadWorkbooks) { Text("再読み込み") }
                        }
                        state.workbooks.isEmpty() -> Text("問題集がありません")
                        else -> state.workbooks.forEachIndexed { index, workbook ->
                            WorkbookOption(workbook, recommended = index == 0) {
                                viewModel.chooseWorkbook(workbook.id)
                            }
                        }
                    }
                }
                3 -> IntroPage(
                    title = "選びおわったね！",
                    lines = listOf(
                        "他の機能は使いながら覚えていこうね！",
                        "機種変更のときは、マイページからメールアカウントにログインすると学習記録を引き継げます。",
                    ),
                )
                4 -> {
                    Icon(Icons.Filled.CheckCircle, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                    Text("利用規約に同意して始めよう", style = MaterialTheme.typography.headlineSmall, textAlign = TextAlign.Center)
                    Text("内容を確認したうえで、同意して次へ進んでください。", textAlign = TextAlign.Center)
                    Card(modifier = Modifier.fillMaxWidth()) {
                        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            TextButton(onClick = { uriHandler.openUri("https://rikako.org/terms") }) {
                                Text("利用規約を確認する")
                            }
                            TextButton(onClick = { uriHandler.openUri("https://rikako.org/privacy") }) {
                                Text("プライバシーポリシーを確認する")
                            }
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Checkbox(
                                    checked = state.acceptedTerms,
                                    onCheckedChange = viewModel::setTermsAccepted,
                                )
                                Text("利用規約に同意します", modifier = Modifier.clickable {
                                    viewModel.setTermsAccepted(!state.acceptedTerms)
                                })
                            }
                        }
                    }
                }
                else -> {
                    IntroPage(
                        title = "それではさっそく勉強していこう！",
                        lines = listOf("一緒に頑張ろうね！"),
                    )
                    state.startError?.let { Text(it, color = MaterialTheme.colorScheme.error) }
                }
            }
        }
    }
}

@Composable
private fun IntroPage(title: String, lines: List<String>) {
    Image(
        painter = painterResource(R.drawable.rikako_standing),
        contentDescription = null,
        modifier = Modifier.height(220.dp),
    )
    Text(title, style = MaterialTheme.typography.headlineSmall, textAlign = TextAlign.Center, fontWeight = FontWeight.Bold)
    lines.forEach { Text(it, textAlign = TextAlign.Center, style = MaterialTheme.typography.bodyLarge) }
}

@Composable
private fun WorkbookOption(workbook: Workbook, recommended: Boolean, onClick: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
        colors = CardDefaults.cardColors(
            containerColor = if (recommended) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant,
        ),
    ) {
        Column(modifier = Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            if (recommended) Text("おすすめ", color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
            Text(workbook.title, style = MaterialTheme.typography.titleMedium)
            if (workbook.description.isNotBlank()) Text(workbook.description, style = MaterialTheme.typography.bodySmall)
            Text("${workbook.questionCount}問  ·  この問題集で始める", color = MaterialTheme.colorScheme.primary)
        }
    }
}
