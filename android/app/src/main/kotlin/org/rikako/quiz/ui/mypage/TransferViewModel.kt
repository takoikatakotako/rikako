package org.rikako.quiz.ui.mypage

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import io.ktor.client.plugins.ClientRequestException
import io.ktor.client.statement.bodyAsText
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import org.rikako.quiz.ServiceLocator
import org.rikako.quiz.data.model.TransferToken
import org.rikako.quiz.data.repository.LearningRepository

data class TransferUiState(
    val token: TransferToken? = null,
    val loadingToken: Boolean = true,
    val applying: Boolean = false,
    val completed: Boolean = false,
    val error: String? = null,
)

class TransferViewModel(
    private val repository: LearningRepository = ServiceLocator.learningRepository,
) : ViewModel() {
    private val _uiState = MutableStateFlow(TransferUiState())
    val uiState: StateFlow<TransferUiState> = _uiState.asStateFlow()

    init { loadToken() }

    fun loadToken(refresh: Boolean = false) {
        if (_uiState.value.loadingToken && _uiState.value.token != null) return
        _uiState.update { it.copy(loadingToken = true, error = null) }
        viewModelScope.launch {
            try {
                val token = if (refresh) repository.refreshTransferToken() else repository.fetchTransferToken()
                _uiState.update { it.copy(token = token, loadingToken = false) }
            } catch (error: CancellationException) {
                throw error
            } catch (_: Exception) {
                _uiState.update { it.copy(loadingToken = false, error = "引き継ぎコードを取得できませんでした") }
            }
        }
    }

    fun applyToken(value: String) {
        val token = normalizedTransferToken(value)
        if (token == null) {
            _uiState.update { it.copy(error = "64文字の引き継ぎコードを入力してください") }
            return
        }
        if (_uiState.value.applying || _uiState.value.completed) return
        _uiState.update { it.copy(applying = true, error = null) }
        viewModelScope.launch {
            try {
                repository.applyTransferToken(token)
                _uiState.update { it.copy(applying = false, completed = true) }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                val response = if (error is ClientRequestException) runCatching { error.response.bodyAsText() }.getOrNull() else null
                val message = if (response?.contains("SAME_DEVICE") == true) {
                    "この端末で発行したコードは使用できません"
                } else if (error.message?.contains("ログアウト") == true) {
                    "アカウントからログアウトしてから引き継いでください"
                } else {
                    "引き継ぎに失敗しました。コードの有効期限を確認してください"
                }
                _uiState.update { it.copy(applying = false, error = message) }
            }
        }
    }

    fun showError(message: String) { _uiState.update { it.copy(error = message) } }

    /** 完了表示は一度だけ。画面が再構成されてもダイアログを再表示しない。 */
    fun consumeCompleted() { _uiState.update { it.copy(completed = false) } }

    companion object {
        fun factory(): ViewModelProvider.Factory = object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: Class<T>): T = TransferViewModel() as T
        }
    }
}
