package org.rikako.quiz.ui.root

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.Image
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import org.rikako.quiz.BuildConfig
import org.rikako.quiz.R

@Composable
fun RootScreen(
    viewModel: RootViewModel = viewModel(),
    content: @Composable () -> Unit,
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val uriHandler = LocalUriHandler.current
    when (val current = state) {
        RootUiState.Ready -> content()
        else -> Box(
            modifier = Modifier.fillMaxSize().background(MaterialTheme.colorScheme.primary),
            contentAlignment = Alignment.Center,
        ) {
            Column(
                modifier = Modifier.fillMaxWidth().padding(32.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(20.dp),
            ) {
                when (current) {
                    RootUiState.Loading -> {
                        Image(
                            painter = painterResource(R.drawable.rikako_logo),
                            contentDescription = "理科子",
                            modifier = Modifier.width(255.dp).height(75.dp),
                        )
                        CircularProgressIndicator(color = Color.White)
                        Image(
                            painter = painterResource(R.drawable.rikako_standing),
                            contentDescription = null,
                            modifier = Modifier.height(250.dp),
                        )
                    }
                    is RootUiState.Maintenance -> {
                        Icon(Icons.Filled.Build, contentDescription = null, tint = Color.White)
                        Text("メンテナンス中", style = MaterialTheme.typography.headlineMedium, color = Color.White)
                        Text(
                            current.message.ifBlank { "現在メンテナンス中です。しばらく時間をおいてから再度お試しください。" },
                            color = Color.White, textAlign = TextAlign.Center,
                        )
                        WhiteButton("再確認", viewModel::refresh)
                    }
                    RootUiState.UpdateRequired -> {
                        Icon(Icons.Filled.Refresh, contentDescription = null, tint = Color.White)
                        Text("アップデートが必要です", style = MaterialTheme.typography.headlineMedium, color = Color.White)
                        Text("最新バージョンのアプリをインストールしてご利用ください。", color = Color.White, textAlign = TextAlign.Center)
                        WhiteButton("Google Playを開く") {
                            val packageName = BuildConfig.APPLICATION_ID.removeSuffix(".dev")
                            uriHandler.openUri("https://play.google.com/store/apps/details?id=$packageName")
                        }
                        WhiteButton("再確認", viewModel::refresh)
                    }
                    is RootUiState.Error -> {
                        Text("読み込みエラー", style = MaterialTheme.typography.headlineMedium, color = Color.White)
                        Text(current.message, color = Color.White, textAlign = TextAlign.Center)
                        WhiteButton("再試行", viewModel::refresh)
                    }
                    RootUiState.Ready -> Unit
                }
            }
        }
    }
}

@Composable
private fun WhiteButton(label: String, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        colors = ButtonDefaults.buttonColors(
            containerColor = Color.White,
            contentColor = MaterialTheme.colorScheme.primary,
        ),
        modifier = Modifier.fillMaxWidth(),
    ) { Text(label) }
}
