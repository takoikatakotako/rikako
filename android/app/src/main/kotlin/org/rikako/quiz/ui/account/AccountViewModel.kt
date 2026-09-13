package org.rikako.quiz.ui.account

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import org.rikako.quiz.ServiceLocator
import org.rikako.quiz.data.auth.AccountSession
import org.rikako.quiz.data.repository.AccountRepository

/** 未ログイン時にどのフォームを出しているか。 */
enum class AccountForm {
    SignIn,
    SignUp,
    ConfirmSignUp,
    ForgotPassword,
    ConfirmForgotPassword,
}

data class AccountUiState(
    val isLoggedIn: Boolean = false,
    val email: String? = null,
    val form: AccountForm = AccountForm.SignIn,
    val isBusy: Boolean = false,
    val errorMessage: String? = null,
    val infoMessage: String? = null,
    /** リンク（匿名データの引き継ぎ）に失敗していて、再試行できる状態か。 */
    val linkFailed: Boolean = false,
)

class AccountViewModel(
    private val session: AccountSession = ServiceLocator.accountSession,
    private val accountRepository: AccountRepository = ServiceLocator.accountRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(
        AccountUiState(
            isLoggedIn = session.state.value.isLoggedIn,
            email = session.state.value.email,
        ),
    )
    val uiState: StateFlow<AccountUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            session.state.collect { account ->
                _uiState.update { it.copy(isLoggedIn = account.isLoggedIn, email = account.email) }
            }
        }
    }

    fun showForm(form: AccountForm) {
        _uiState.update { it.copy(form = form, errorMessage = null, infoMessage = null) }
    }

    fun signUp(email: String, password: String) = run("確認コードをメールに送りました。") {
        session.signUp(email, password)
        _uiState.update { it.copy(form = AccountForm.ConfirmSignUp) }
    }

    fun confirmSignUp(email: String, code: String) = run("登録が完了しました。ログインしてください。") {
        session.confirmSignUp(email, code)
        _uiState.update { it.copy(form = AccountForm.SignIn) }
    }

    fun resendConfirmationCode(email: String) = run("確認コードを再送しました。") {
        session.resendConfirmationCode(email)
    }

    fun signIn(email: String, password: String) = run(null) {
        session.signIn(email, password)
        linkAccount()
    }

    fun forgotPassword(email: String) = run("確認コードをメールに送りました。") {
        session.forgotPassword(email)
        _uiState.update { it.copy(form = AccountForm.ConfirmForgotPassword) }
    }

    fun confirmForgotPassword(email: String, code: String, newPassword: String) =
        run("パスワードを変更しました。ログインしてください。") {
            session.confirmForgotPassword(email, code, newPassword)
            _uiState.update { it.copy(form = AccountForm.SignIn) }
        }

    fun signOut() = run(null) {
        session.signOut()
        _uiState.update { it.copy(form = AccountForm.SignIn, linkFailed = false) }
    }

    /** 引き継ぎ（/account/link）の再試行。 */
    fun retryLink() = run(null) { linkAccount() }

    private suspend fun linkAccount() {
        val failed = runCatching { accountRepository.ensureLinked() }.isFailure
        _uiState.update { it.copy(linkFailed = failed) }
    }

    private fun run(successMessage: String?, block: suspend () -> Unit) {
        if (_uiState.value.isBusy) return
        _uiState.update { it.copy(isBusy = true, errorMessage = null, infoMessage = null) }
        viewModelScope.launch {
            val result = runCatching { block() }
            _uiState.update { state ->
                result.fold(
                    onSuccess = { state.copy(isBusy = false, infoMessage = successMessage) },
                    onFailure = { e ->
                        state.copy(isBusy = false, errorMessage = e.message ?: "エラーが発生しました。")
                    },
                )
            }
        }
    }
}
