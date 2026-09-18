package org.rikako.quiz.ui.workbook

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch
import org.rikako.quiz.ServiceLocator
import org.rikako.quiz.data.identity.SelectedWorkbookPreference
import org.rikako.quiz.data.model.Workbook
import org.rikako.quiz.data.model.WorkbookDetail
import org.rikako.quiz.data.repository.LearningRepository

sealed interface WorkbookListUiState {
    data object Loading : WorkbookListUiState
    data class Success(
        val workbooks: List<Workbook>,
        val selectedId: Long?,
        val detail: WorkbookDetail? = null,
        val progress: Map<Long, Boolean> = emptyMap(),
        val isDetailLoading: Boolean = false,
        val detailError: String? = null,
    ) : WorkbookListUiState {
        val selectedWorkbook: Workbook?
            get() = workbooks.firstOrNull { it.id == selectedId }
    }
    data class Error(val message: String) : WorkbookListUiState
}

/** iOS の StudyHomeViewModel と同じく、選択中の問題集とチャプターをホームに表示する。 */
class WorkbookListViewModel(
    private val repository: LearningRepository = ServiceLocator.learningRepository,
    private val selectedStore: SelectedWorkbookPreference = ServiceLocator.selectedWorkbookStore,
) : ViewModel() {

    private val _uiState = MutableStateFlow<WorkbookListUiState>(WorkbookListUiState.Loading)
    val uiState: StateFlow<WorkbookListUiState> = _uiState.asStateFlow()
    private var detailGeneration = 0
    private var progressGeneration = 0

    init {
        load()
        viewModelScope.launch {
            repository.learningDataChanged.collect { refreshProgress() }
        }
    }

    fun load() {
        detailGeneration++
        progressGeneration++
        _uiState.value = WorkbookListUiState.Loading
        viewModelScope.launch {
            val workbooks = try {
                repository.fetchWorkbooks()
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                _uiState.value = WorkbookListUiState.Error(error.message ?: "読み込みに失敗しました")
                return@launch
            }
            val preferred = selectedStore.get()
            val selectedId = workbooks.firstOrNull { it.id == preferred }?.id ?: workbooks.firstOrNull()?.id
            if (selectedId != null) selectedStore.set(selectedId)
            _uiState.value = WorkbookListUiState.Success(
                workbooks = workbooks,
                selectedId = selectedId,
                isDetailLoading = selectedId != null,
            )
            if (selectedId != null) loadDetail(selectedId)
        }
    }

    fun selectWorkbook(id: Long) {
        val current = _uiState.value as? WorkbookListUiState.Success ?: return
        if (current.workbooks.none { it.id == id } || current.selectedId == id) return
        selectedStore.set(id)
        progressGeneration++
        _uiState.value = current.copy(
            selectedId = id,
            detail = null,
            progress = emptyMap(),
            isDetailLoading = true,
            detailError = null,
        )
        viewModelScope.launch { loadDetail(id) }
        viewModelScope.launch {
            try {
                repository.updateSelectedWorkbook(id)
            } catch (error: CancellationException) {
                throw error
            } catch (_: Exception) {
                // 端末内の選択は保ち、次回の選択時に再同期する。
            }
        }
    }

    private suspend fun loadDetail(id: Long) {
        val generation = ++detailGeneration
        val detail = try {
            repository.fetchWorkbookDetail(id)
        } catch (error: CancellationException) {
            throw error
        } catch (error: Exception) {
            val current = _uiState.value as? WorkbookListUiState.Success ?: return
            if (generation == detailGeneration && current.selectedId == id) {
                _uiState.value = current.copy(
                    isDetailLoading = false,
                    detailError = error.message ?: "チャプターを読み込めませんでした",
                )
            }
            return
        }
        val current = _uiState.value as? WorkbookListUiState.Success ?: return
        if (generation != detailGeneration || current.selectedId != id) return
        _uiState.value = current.copy(detail = detail, isDetailLoading = false, detailError = null)
        refreshProgress()
    }

    private suspend fun refreshProgress() {
        val current = _uiState.value as? WorkbookListUiState.Success ?: return
        val id = current.selectedId ?: return
        if (current.detail == null) return
        val generation = ++progressGeneration
        val progress = try {
            repository.fetchWorkbookProgress(id).results.associate { it.questionId to it.isCorrect }
        } catch (error: CancellationException) {
            throw error
        } catch (_: Exception) {
            return
        }
        val latest = _uiState.value as? WorkbookListUiState.Success ?: return
        if (latest.selectedId == id && generation == progressGeneration) {
            _uiState.value = latest.copy(progress = progress)
        }
    }
}
