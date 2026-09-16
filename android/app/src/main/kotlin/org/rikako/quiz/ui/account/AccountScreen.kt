package org.rikako.quiz.ui.account

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AccountScreen(
    modifier: Modifier = Modifier,
    onBack: () -> Unit = {},
    viewModel: AccountViewModel = viewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(
        modifier = modifier,
        topBar = { TopAppBar(
            title = { Text("アカウント") },
            navigationIcon = { IconButton(onClick = onBack) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "戻る")
            } },
        ) },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            state.errorMessage?.let {
                Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodyMedium)
            }
            state.infoMessage?.let {
                Text(it, style = MaterialTheme.typography.bodyMedium)
            }

            if (state.isLoggedIn) {
                SignedIn(state = state, viewModel = viewModel)
            } else {
                SignedOut(state = state, viewModel = viewModel)
            }
        }
    }
}

@Composable
private fun SignedIn(state: AccountUiState, viewModel: AccountViewModel) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text("ログイン中", style = MaterialTheme.typography.titleMedium)
            Text(state.email ?: "", style = MaterialTheme.typography.bodyMedium)
            Text(
                text = "機種変更のときは、新しい端末で同じメールアドレスでログインすると学習記録を引き継げます。",
                style = MaterialTheme.typography.bodySmall,
            )
        }
    }

    if (state.linkFailed) {
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(
                modifier = Modifier.padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(
                    text = "この端末の学習記録をアカウントに引き継げていません。",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.error,
                )
                Button(onClick = viewModel::retryLink, enabled = !state.isBusy) {
                    Text("引き継ぎを再試行")
                }
            }
        }
    }

    OutlinedButton(
        onClick = viewModel::signOut,
        enabled = !state.isBusy,
        modifier = Modifier.fillMaxWidth(),
    ) { Text("ログアウト") }
}

@Composable
private fun SignedOut(state: AccountUiState, viewModel: AccountViewModel) {
    var email by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }
    var code by rememberSaveable { mutableStateOf("") }

    Text(
        text = "普段はログインなしで使えます。機種変更で学習記録を引き継ぐときにログインしてください。",
        style = MaterialTheme.typography.bodySmall,
    )

    EmailField(email) { email = it }

    when (state.form) {
        AccountForm.SignIn -> {
            PasswordField(password, "パスワード") { password = it }
            Button(
                onClick = { viewModel.signIn(email.trim(), password) },
                enabled = !state.isBusy && email.isNotBlank() && password.isNotBlank(),
                modifier = Modifier.fillMaxWidth(),
            ) { Text("ログイン") }
            TextButton(onClick = { viewModel.showForm(AccountForm.SignUp) }) { Text("新規登録") }
            TextButton(onClick = { viewModel.showForm(AccountForm.ForgotPassword) }) {
                Text("パスワードを忘れた場合")
            }
        }

        AccountForm.SignUp -> {
            PasswordField(password, "パスワード（8文字以上・大小英字・数字・記号）") { password = it }
            Button(
                onClick = { viewModel.signUp(email.trim(), password) },
                enabled = !state.isBusy && email.isNotBlank() && password.isNotBlank(),
                modifier = Modifier.fillMaxWidth(),
            ) { Text("新規登録") }
            TextButton(onClick = { viewModel.showForm(AccountForm.SignIn) }) { Text("ログインに戻る") }
        }

        AccountForm.ConfirmSignUp -> {
            CodeField(code) { code = it }
            Button(
                onClick = { viewModel.confirmSignUp(email.trim(), code.trim()) },
                enabled = !state.isBusy && code.isNotBlank(),
                modifier = Modifier.fillMaxWidth(),
            ) { Text("確認コードを送信") }
            TextButton(
                onClick = { viewModel.resendConfirmationCode(email.trim()) },
                enabled = !state.isBusy,
            ) { Text("確認コードを再送") }
            TextButton(onClick = { viewModel.showForm(AccountForm.SignIn) }) { Text("ログインに戻る") }
        }

        AccountForm.ForgotPassword -> {
            Button(
                onClick = { viewModel.forgotPassword(email.trim()) },
                enabled = !state.isBusy && email.isNotBlank(),
                modifier = Modifier.fillMaxWidth(),
            ) { Text("確認コードを送る") }
            TextButton(onClick = { viewModel.showForm(AccountForm.SignIn) }) { Text("ログインに戻る") }
        }

        AccountForm.ConfirmForgotPassword -> {
            CodeField(code) { code = it }
            PasswordField(password, "新しいパスワード") { password = it }
            Button(
                onClick = { viewModel.confirmForgotPassword(email.trim(), code.trim(), password) },
                enabled = !state.isBusy && code.isNotBlank() && password.isNotBlank(),
                modifier = Modifier.fillMaxWidth(),
            ) { Text("パスワードを変更") }
            TextButton(onClick = { viewModel.showForm(AccountForm.SignIn) }) { Text("ログインに戻る") }
        }
    }
}

@Composable
private fun EmailField(value: String, onValueChange: (String) -> Unit) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text("メールアドレス") },
        singleLine = true,
        keyboardOptions = KeyboardOptions(
            keyboardType = KeyboardType.Email,
            imeAction = ImeAction.Next,
        ),
        modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
private fun PasswordField(value: String, label: String, onValueChange: (String) -> Unit) {
    var visible by remember { mutableStateOf(false) }
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        singleLine = true,
        visualTransformation = if (visible) {
            androidx.compose.ui.text.input.VisualTransformation.None
        } else {
            PasswordVisualTransformation()
        },
        keyboardOptions = KeyboardOptions(
            keyboardType = KeyboardType.Password,
            imeAction = ImeAction.Done,
        ),
        trailingIcon = {
            TextButton(onClick = { visible = !visible }) {
                Text(if (visible) "隠す" else "表示")
            }
        },
        modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
private fun CodeField(value: String, onValueChange: (String) -> Unit) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text("確認コード") },
        singleLine = true,
        keyboardOptions = KeyboardOptions(
            keyboardType = KeyboardType.Number,
            imeAction = ImeAction.Done,
        ),
        modifier = Modifier.fillMaxWidth(),
    )
}
