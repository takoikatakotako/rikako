package org.rikako.quiz.ui.root

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.rikako.quiz.BuildConfig
import org.rikako.quiz.ServiceLocator
import org.rikako.quiz.data.repository.AccountRepository
import org.rikako.quiz.data.repository.LearningRepository
import org.rikako.quiz.data.identity.OnboardingPreference
import org.rikako.quiz.data.identity.SelectedWorkbookPreference

sealed interface RootUiState {
    data object Loading : RootUiState
    data object Ready : RootUiState
    data class Error(val message: String) : RootUiState
    data class Maintenance(val message: String) : RootUiState
    data object UpdateRequired : RootUiState
}

class RootViewModel(
    private val learningRepository: LearningRepository = ServiceLocator.learningRepository,
    private val accountRepository: AccountRepository = ServiceLocator.accountRepository,
    private val onboarding: OnboardingPreference = ServiceLocator.onboardingStore,
    private val selectedWorkbook: SelectedWorkbookPreference = ServiceLocator.selectedWorkbookStore,
    private val currentVersion: String = BuildConfig.VERSION_NAME,
) : ViewModel() {
    private val _uiState = MutableStateFlow<RootUiState>(RootUiState.Loading)
    val uiState: StateFlow<RootUiState> = _uiState.asStateFlow()

    init { refresh() }

    fun refresh() {
        _uiState.value = RootUiState.Loading
        viewModelScope.launch {
            try {
                val status = learningRepository.fetchAppStatus()
                when {
                    status.isMaintenance -> {
                        _uiState.value = RootUiState.Maintenance(status.maintenanceMessage)
                        return@launch
                    }
                    isUpdateRequired(currentVersion, status.minimumVersion) -> {
                        _uiState.value = RootUiState.UpdateRequired
                        return@launch
                    }
                }
                if (onboarding.completed.value) {
                    // リンク・プロフィールの同期失敗は学習そのものを止めない。
                    try {
                        accountRepository.ensureLinked()
                        learningRepository.fetchProfile().selectedWorkbookId?.let(selectedWorkbook::set)
                    } catch (error: CancellationException) {
                        throw error
                    } catch (_: Exception) {
                        // 設定やアカウント画面から再試行できる。
                    }
                }
                _uiState.value = RootUiState.Ready
            } catch (error: CancellationException) {
                throw error
            } catch (_: Exception) {
                _uiState.value = RootUiState.Error("接続を確認して再試行してください")
            }
        }
    }
}

/** minimumVersion が不正なときはアプリを誤って締め出さない。 */
internal fun isUpdateRequired(current: String, minimum: String): Boolean {
    fun parts(value: String): List<Int>? = value.substringBefore('-').split('.').map { it.toIntOrNull() }
        .takeIf { it.all { number -> number != null } }?.filterNotNull()
    val installed = parts(current) ?: return false
    val required = parts(minimum) ?: return false
    for (index in 0 until maxOf(installed.size, required.size)) {
        val left = installed.getOrElse(index) { 0 }
        val right = required.getOrElse(index) { 0 }
        if (left != right) return left < right
    }
    return false
}
