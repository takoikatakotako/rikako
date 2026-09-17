package org.rikako.quiz.ui.mypage

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Info
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.codescanner.GmsBarcodeScannerOptions
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.rikako.quiz.ServiceLocator

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TransferScreen(
    onBack: () -> Unit,
    onAccount: () -> Unit,
    onTransferred: () -> Unit,
    viewModel: TransferViewModel = viewModel(factory = TransferViewModel.factory()),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val account by ServiceLocator.accountSession.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    LaunchedEffect(account.isLoggedIn) {
        if (!account.isLoggedIn && state.token == null && !state.loadingToken) viewModel.loadToken()
    }
    var receiving by remember { mutableStateOf(false) }
    var typedToken by remember { mutableStateOf("") }
    var pendingToken by remember { mutableStateOf<String?>(null) }
    val photoPicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) {
            scope.launch {
                val token = withContext(Dispatchers.IO) {
                    runCatching { readTransferQrFromImage(context.contentResolver, uri) }.getOrNull()
                }
                if (token == null) viewModel.showError("画像からQRコードを読み取れませんでした")
                else pendingToken = token
            }
        }
    }

    pendingToken?.let { token ->
        AlertDialog(
            onDismissRequest = { pendingToken = null },
            title = { Text("この端末に引き継ぎますか？") },
            text = { Text("この端末で表示する学習データが、引き継ぎ元のデータに切り替わります。現在の匿名データは表示されなくなります。") },
            confirmButton = {
                TextButton(onClick = { pendingToken = null; viewModel.applyToken(token) }) { Text("引き継ぐ") }
            },
            dismissButton = { TextButton(onClick = { pendingToken = null }) { Text("キャンセル") } },
        )
    }
    if (state.completed) {
        AlertDialog(
            onDismissRequest = {},
            title = { Text("引き継ぎ完了") },
            text = { Text("学習データを引き継ぎました。画面を更新して反映します。") },
            confirmButton = { TextButton(onClick = {
                ServiceLocator.selectedWorkbookStore.clear()
                onTransferred()
            }) { Text("OK") } },
        )
    }

    Scaffold(topBar = {
        TopAppBar(
            title = { Text("データ引き継ぎ") },
            navigationIcon = { IconButton(onClick = onBack) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "戻る")
            } },
        )
    }) { padding ->
        Column(
            modifier = Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Card(
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Row(modifier = Modifier.padding(16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Icon(Icons.Filled.Info, null, tint = MaterialTheme.colorScheme.primary)
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text("アカウントでの引き継ぎがおすすめ", fontWeight = FontWeight.SemiBold)
                        Text("ログインすると、QRコードなしで複数端末に学習記録を同期できます。", style = MaterialTheme.typography.bodySmall)
                        TextButton(onClick = onAccount) { Text("ログイン・アカウント管理") }
                    }
                }
            }
            if (account.isLoggedIn) {
                Text("ログイン中はQRコードで引き継げません。アカウントからログアウトするか、同じアカウントで新しい端末にログインしてください。")
                Button(onClick = onAccount) { Text("アカウントを開く") }
                return@Column
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                if (receiving) OutlinedButton(onClick = { receiving = false }, modifier = Modifier.weight(1f)) {
                    Text("この端末から")
                } else Button(onClick = { receiving = false }, modifier = Modifier.weight(1f)) { Text("この端末から") }
                if (receiving) Button(onClick = { receiving = true }, modifier = Modifier.weight(1f)) {
                    Text("この端末へ")
                } else OutlinedButton(onClick = { receiving = true }, modifier = Modifier.weight(1f)) { Text("この端末へ") }
            }
            if (receiving) {
                Text("引き継ぎ元のQRコードを読み取る", style = MaterialTheme.typography.titleMedium)
                Text("カメラでスキャンするか、保存済みのQR画像を選んでください。", color = MaterialTheme.colorScheme.onSurfaceVariant)
                Button(
                    onClick = {
                        val options = GmsBarcodeScannerOptions.Builder()
                            .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
                            .enableAutoZoom()
                            .build()
                        GmsBarcodeScanning.getClient(context, options).startScan()
                            .addOnSuccessListener { barcode ->
                                val token = barcode.rawValue?.let(::normalizedTransferToken)
                                if (token == null) viewModel.showError("引き継ぎ用のQRコードではありません")
                                else pendingToken = token
                            }
                            .addOnFailureListener { viewModel.showError("スキャンできませんでした。画像またはコード入力をお試しください") }
                    },
                    enabled = !state.applying,
                    modifier = Modifier.fillMaxWidth(),
                ) { Text("QRコードをスキャン") }
                OutlinedButton(
                    onClick = { photoPicker.launch("image/*") },
                    enabled = !state.applying,
                    modifier = Modifier.fillMaxWidth(),
                ) { Text("画像から読み込む") }
                OutlinedTextField(
                    value = typedToken,
                    onValueChange = { typedToken = it },
                    label = { Text("引き継ぎコードを入力") },
                    supportingText = { Text("共有された64文字のコードを貼り付けられます") },
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedButton(
                    onClick = {
                        val token = normalizedTransferToken(typedToken)
                        if (token == null) viewModel.showError("64文字の引き継ぎコードを入力してください")
                        else pendingToken = token
                    },
                    enabled = !state.applying,
                    modifier = Modifier.fillMaxWidth(),
                ) { Text("コードで引き継ぐ") }
                if (state.applying) CircularProgressIndicator(modifier = Modifier.align(Alignment.CenterHorizontally))
            } else {
                Text("新しい端末でこのQRコードを読み取ってください", style = MaterialTheme.typography.titleMedium)
                if (state.loadingToken) {
                    Box(modifier = Modifier.fillMaxWidth().height(260.dp), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                } else state.token?.let { token ->
                    val bitmap = remember(token.token) { transferQrBitmap(token.token) }
                    Card(modifier = Modifier.align(Alignment.CenterHorizontally)) {
                        Image(
                            bitmap = bitmap.asImageBitmap(),
                            contentDescription = "データ引き継ぎ用QRコード",
                            modifier = Modifier.padding(12.dp).size(230.dp),
                        )
                    }
                    Text(
                        "有効期限: ${formatTransferExpiry(token.expiresAt)}",
                        modifier = Modifier.fillMaxWidth(),
                        textAlign = TextAlign.Center,
                        style = MaterialTheme.typography.bodySmall,
                    )
                    Text(
                        token.token,
                        modifier = Modifier.fillMaxWidth(),
                        textAlign = TextAlign.Center,
                        style = MaterialTheme.typography.labelSmall,
                    )
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedButton(onClick = {
                            val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                            clipboard.setPrimaryClip(ClipData.newPlainText("引き継ぎコード", token.token))
                        }, modifier = Modifier.weight(1f)) { Text("コピー") }
                        OutlinedButton(onClick = {
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(Intent.EXTRA_TEXT, token.token)
                            }
                            context.startActivity(Intent.createChooser(intent, "引き継ぎコードを共有"))
                        }, modifier = Modifier.weight(1f)) { Text("共有") }
                    }
                }
                OutlinedButton(
                    onClick = { viewModel.loadToken(refresh = true) },
                    enabled = !state.loadingToken,
                    modifier = Modifier.fillMaxWidth(),
                ) { Text("コードを更新する") }
                Text("コードを更新すると、以前のQRコードは使えなくなります。", style = MaterialTheme.typography.bodySmall)
            }
            state.error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
        }
    }
}

internal fun formatTransferExpiry(value: String): String = runCatching {
    OffsetDateTime.parse(value).atZoneSameInstant(ZoneId.of("Asia/Tokyo"))
        .format(DateTimeFormatter.ofPattern("yyyy年M月d日 HH:mm"))
}.getOrDefault(value)
