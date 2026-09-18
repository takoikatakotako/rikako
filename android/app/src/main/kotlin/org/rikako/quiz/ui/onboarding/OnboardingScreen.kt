package org.rikako.quiz.ui.onboarding

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import org.rikako.quiz.AppFlavor
import org.rikako.quiz.R
import org.rikako.quiz.ServiceLocator
import org.rikako.quiz.data.model.Workbook

private val secondaryText = Color(0xFF72767B)
private val softCard = Color(0xFFF7F8F6)

@Composable
fun OnboardingScreen() {
    val revision by ServiceLocator.onboardingStore.revision.collectAsStateWithLifecycle()
    val viewModel: OnboardingViewModel = viewModel(key = "onboarding-$revision")
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val isChemistry = AppFlavor.current.slug == "high-school-chemistry"
    val uriHandler = LocalUriHandler.current
    val accent = MaterialTheme.colorScheme.primary
    BackHandler(enabled = state.page > 0) { viewModel.back() }

    Scaffold(
        containerColor = Color.White,
        bottomBar = {
            Column(
                modifier = Modifier.fillMaxWidth().background(Color.White).navigationBarsPadding()
                    .padding(horizontal = 24.dp).padding(top = 12.dp, bottom = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                if (state.page != 2) {
                    Button(
                        onClick = if (state.page == 5) viewModel::start else viewModel::next,
                        enabled = !state.starting && (state.page != 4 || state.acceptedTerms),
                        modifier = Modifier.fillMaxWidth().height(56.dp),
                        shape = RoundedCornerShape(16.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = accent,
                            disabledContainerColor = Color(0xFFD5D8D3),
                            disabledContentColor = Color.White,
                        ),
                    ) {
                        if (state.starting) {
                            CircularProgressIndicator(color = Color.White, modifier = Modifier.size(22.dp), strokeWidth = 2.dp)
                        } else {
                            Text(
                                when (state.page) {
                                    1 -> "問題集を選ぶ"
                                    4 -> "同意して次へ"
                                    5 -> "はじめる"
                                    else -> "次へ"
                                },
                                fontSize = 16.sp,
                                fontWeight = FontWeight.SemiBold,
                            )
                        }
                    }
                    Spacer(Modifier.height(18.dp))
                }
                Row(horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                    repeat(6) { index ->
                        Box(
                            Modifier.size(if (index == state.page) 8.dp else 6.dp)
                                .clip(CircleShape)
                                .background(if (index == state.page) accent else Color(0xFFD2D5D0)),
                        )
                    }
                }
            }
        },
    ) { padding ->
        Box(Modifier.fillMaxSize().padding(padding)) {
            when (state.page) {
                0 -> IntroPage(
                    "こんにちは、理科子です！",
                    if (isChemistry) listOf(
                        "このアプリは高校生向けの化学を楽しく学ぶためのアプリです！",
                        "一緒に楽しく勉強していこうね！",
                    ) else listOf(
                        "ITパスポートの問題を一緒に解いていこうね！",
                        "毎日少しずつ進めていこう！",
                    ),
                ) { CharacterArt() }
                1 -> IntroPage(
                    "君にあった分野を選ぼう！",
                    listOf(
                        "次のページで問題集を選択できます。",
                        "特になければ、おすすめの問題集から始めてみよう！",
                    ),
                ) { SymbolTile(devices = false) }
                2 -> Column(
                    modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState())
                        .padding(start = 24.dp, end = 24.dp, top = 72.dp, bottom = 24.dp),
                    verticalArrangement = Arrangement.spacedBy(20.dp),
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text("最初の問題集を選ぼう", fontSize = 28.sp, fontWeight = FontWeight.Bold)
                        Text(
                            "おすすめの1冊を用意したよ。まずはここから始めてみよう！",
                            color = secondaryText,
                            lineHeight = 23.sp,
                        )
                    }
                    when {
                        state.loadingWorkbooks -> CircularProgressIndicator(modifier = Modifier.align(Alignment.CenterHorizontally))
                        state.workbookError != null -> {
                            Text(state.workbookError ?: "", color = MaterialTheme.colorScheme.error)
                            Button(onClick = viewModel::loadWorkbooks) { Text("再読み込み") }
                        }
                        state.workbooks.isEmpty() -> Text("問題集がありません", color = secondaryText)
                        else -> state.workbooks.forEachIndexed { index, workbook ->
                            WorkbookOption(
                                workbook,
                                recommended = index == 0,
                                heading = when (index) { 0 -> "おすすめ"; 1 -> "その他"; else -> null },
                            ) {
                                viewModel.chooseWorkbook(workbook.id)
                            }
                        }
                    }
                }
                3 -> IntroPage(
                    "選びおわったね！",
                    listOf(
                        "他の機能は使いながら覚えていこうね！",
                        "機種変更のときは、マイページから学習記録を引き継げます。",
                    ),
                ) { SymbolTile(devices = true) }
                4 -> TermsPage(
                    accepted = state.acceptedTerms,
                    onAcceptedChange = viewModel::setTermsAccepted,
                    onTerms = { uriHandler.openUri("https://rikako.org/terms") },
                    onPrivacy = { uriHandler.openUri("https://rikako.org/privacy") },
                )
                else -> IntroPage(
                    "それではさっそく勉強していこう！",
                    listOf(state.startError ?: "一緒に頑張ろうね！"),
                    error = state.startError != null,
                ) { CharacterArt() }
            }
            if (state.page > 0) {
                IconButton(
                    onClick = viewModel::back,
                    modifier = Modifier.align(Alignment.TopStart).padding(start = 12.dp, top = 8.dp),
                ) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "戻る") }
            }
        }
    }
}

@Composable
private fun IntroPage(
    title: String,
    lines: List<String>,
    error: Boolean = false,
    artwork: @Composable () -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxSize().padding(horizontal = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.weight(0.8f))
        artwork()
        Spacer(Modifier.height(24.dp))
        Text(title, fontSize = 30.sp, lineHeight = 37.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
        Spacer(Modifier.height(14.dp))
        lines.forEachIndexed { index, line ->
            if (index > 0) Spacer(Modifier.height(8.dp))
            Text(
                line,
                color = if (error) MaterialTheme.colorScheme.error else secondaryText,
                fontSize = 16.sp,
                lineHeight = 25.sp,
                textAlign = TextAlign.Center,
            )
        }
        Spacer(Modifier.weight(1.2f))
    }
}

@Composable
private fun CharacterArt() {
    Image(
        painter = painterResource(R.drawable.rikako_standing),
        contentDescription = null,
        modifier = Modifier.fillMaxWidth().height(260.dp),
    )
}

@Composable
private fun SymbolTile(devices: Boolean) {
    val accent = MaterialTheme.colorScheme.primary
    Box(
        modifier = Modifier.size(208.dp).clip(RoundedCornerShape(24.dp))
            .background(if (devices) Color(0xFFEEF4FB) else Color(0xFFEFF8E9)),
        contentAlignment = Alignment.Center,
    ) {
        Canvas(Modifier.size(98.dp)) {
            val stroke = 5.dp.toPx()
            if (devices) {
                drawRoundRect(
                    accent, Offset(size.width * 0.05f, size.height * 0.12f),
                    Size(size.width * 0.57f, size.height * 0.68f),
                    CornerRadius(8.dp.toPx()), style = Stroke(stroke),
                )
                drawRoundRect(
                    accent, Offset(size.width * 0.63f, size.height * 0.28f),
                    Size(size.width * 0.3f, size.height * 0.58f),
                    CornerRadius(7.dp.toPx()), style = Stroke(stroke),
                )
            } else {
                listOf(0.12f, 0.38f, 0.64f).forEach { x ->
                    drawRoundRect(
                        accent, Offset(size.width * x, size.height * 0.12f),
                        Size(size.width * 0.2f, size.height * 0.72f),
                        CornerRadius(5.dp.toPx()), style = Stroke(stroke),
                    )
                }
                drawLine(
                    accent, Offset(size.width * 0.08f, size.height * 0.88f),
                    Offset(size.width * 0.88f, size.height * 0.88f),
                    stroke, cap = StrokeCap.Round,
                )
            }
        }
    }
}

@Composable
private fun WorkbookOption(workbook: Workbook, recommended: Boolean, heading: String?, onClick: () -> Unit) {
    val accent = MaterialTheme.colorScheme.primary
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        heading?.let {
            Text(it, fontWeight = FontWeight.Bold, color = if (recommended) accent else secondaryText)
        }
        Surface(
            onClick = onClick,
            modifier = Modifier.fillMaxWidth(),
            color = softCard,
            shape = RoundedCornerShape(24.dp),
            border = BorderStroke(1.dp, accent.copy(alpha = if (recommended) 0.22f else 0.12f)),
        ) {
            Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(workbook.title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                if (workbook.description.isNotBlank()) {
                    Text(workbook.description, color = secondaryText, lineHeight = 22.sp)
                }
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Text("${workbook.questionCount}問", color = secondaryText, style = MaterialTheme.typography.labelMedium)
                    Spacer(Modifier.weight(1f))
                    Text(
                        "この問題集で始める",
                        color = accent,
                        fontWeight = FontWeight.SemiBold,
                        style = MaterialTheme.typography.labelMedium,
                        modifier = Modifier.clip(RoundedCornerShape(50)).background(accent.copy(alpha = 0.1f))
                            .padding(horizontal = 12.dp, vertical = 8.dp),
                    )
                }
            }
        }
    }
}

@Composable
private fun TermsPage(
    accepted: Boolean,
    onAcceptedChange: (Boolean) -> Unit,
    onTerms: () -> Unit,
    onPrivacy: () -> Unit,
) {
    val accent = MaterialTheme.colorScheme.primary
    Column(
        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState())
            .padding(start = 24.dp, end = 24.dp, top = 70.dp, bottom = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(22.dp),
    ) {
        Box(
            Modifier.size(112.dp).clip(RoundedCornerShape(22.dp)).background(accent.copy(alpha = 0.10f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Filled.CheckCircle, null, tint = accent, modifier = Modifier.size(48.dp))
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(
                "利用規約に同意して始めよう",
                fontSize = 25.sp, lineHeight = 32.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center,
            )
            Text(
                "アプリを使い始める前に、利用規約への同意をお願いしています。",
                color = secondaryText, textAlign = TextAlign.Center, lineHeight = 24.sp,
            )
            Text(
                "内容を確認したうえで、同意して次へ進んでください。",
                color = secondaryText, textAlign = TextAlign.Center, lineHeight = 24.sp,
            )
        }
        Surface(Modifier.fillMaxWidth(), color = softCard, shape = RoundedCornerShape(24.dp)) {
            Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Text("以下の内容を確認できます。", style = MaterialTheme.typography.bodySmall, color = secondaryText)
                TextButton(onClick = onTerms, contentPadding = PaddingValues(0.dp)) {
                    Text("利用規約を確認する", fontWeight = FontWeight.SemiBold)
                }
                TextButton(onClick = onPrivacy, contentPadding = PaddingValues(0.dp)) {
                    Text("プライバシーポリシーを確認する", fontWeight = FontWeight.SemiBold)
                }
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        "利用規約に同意します",
                        modifier = Modifier.weight(1f).clickable { onAcceptedChange(!accepted) },
                        fontWeight = FontWeight.SemiBold,
                    )
                    Spacer(Modifier.width(8.dp))
                    Switch(checked = accepted, onCheckedChange = onAcceptedChange)
                }
                Text(
                    "リンク先を確認したうえで、同意して次へ進んでください。",
                    style = MaterialTheme.typography.bodySmall, color = secondaryText, lineHeight = 20.sp,
                )
            }
        }
    }
}
