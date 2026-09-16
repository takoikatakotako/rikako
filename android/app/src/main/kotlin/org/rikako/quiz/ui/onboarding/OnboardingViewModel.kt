package org.rikako.quiz.ui.onboarding

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import org.rikako.quiz.ServiceLocator
import org.rikako.quiz.data.identity.DeviceIdentityProvider
import org.rikako.quiz.data.identity.OnboardingPreference
import org.rikako.quiz.data.identity.SelectedWorkbookPreference
import org.rikako.quiz.data.model.Workbook
import org.rikako.quiz.data.repository.LearningRepository

data class OnboardingUiState(
    val page: Int = 0,
    val workbooks: List<Workbook> = emptyList(),
    val selectedWorkbookId: Long? = null,
    val loadingWorkbooks: Boolean = true,
    val workbookError: String? = null,
    val acceptedTerms: Boolean = false,
    val starting: Boolean = false,
    val startError: String? = null,
) {
    val recommendedWorkbook: Workbook? get() = workbooks.firstOrNull()
}

/** iOS の6ページの初期設定と、最後の匿名ID払い出しを管理する。 */
class OnboardingViewModel(
    private val repository: LearningRepository = ServiceLocator.learningRepository,
    private val identityProvider: DeviceIdentityProvider = ServiceLocator.deviceIdentityProvider,
    private val selectedStore: SelectedWorkbookPreference = ServiceLocator.selectedWorkbookStore,
    private val onboardingStore: OnboardingPreference = ServiceLocator.onboardingStore,
) : ViewModel() {
    private val _uiState = MutableStateFlow(OnboardingUiState())
    val uiState: StateFlow<OnboardingUiState> = _uiState.asStateFlow()

    init { loadWorkbooks() }

    fun loadWorkbooks() {
        _uiState.update { it.copy(loadingWorkbooks = true, workbookError = null) }
        viewModelScope.launch {
            try {
                val workbooks = repository.fetchWorkbooks()
                val saved = selectedStore.get()
                _uiState.update {
                    it.copy(
                        workbooks = workbooks,
                        selectedWorkbookId = workbooks.firstOrNull { workbook -> workbook.id == saved }?.id,
                        loadingWorkbooks = false,
                    )
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                _uiState.update {
                    it.copy(loadingWorkbooks = false, workbookError = error.message ?: "問題集を読み込めませんでした")
                }
            }
        }
    }

    fun next() {
        _uiState.update { state ->
            if (state.page >= 5 || state.page == 2 || (state.page == 4 && !state.acceptedTerms)) state
            else state.copy(page = state.page + 1)
        }
    }

    fun back() {
        _uiState.update { if (it.page > 0 && !it.starting) it.copy(page = it.page - 1) else it }
    }

    fun chooseWorkbook(id: Long) {
        val state = _uiState.value
        if (state.page != 2 || state.workbooks.none { it.id == id }) return
        selectedStore.set(id)
        _uiState.update { it.copy(selectedWorkbookId = id, page = 3) }
    }

    fun setTermsAccepted(accepted: Boolean) {
        _uiState.update { it.copy(acceptedTerms = accepted) }
    }

    fun start() {
        val state = _uiState.value
        if (state.page != 5 || state.starting || !state.acceptedTerms || state.selectedWorkbookId == null) return
        _uiState.update { it.copy(starting = true, startError = null) }
        viewModelScope.launch {
            try {
                identityProvider.identityId()
                onboardingStore.complete()
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                _uiState.update { it.copy(starting = false, startError = error.message ?: "開始できませんでした") }
            }
        }
    }
}
