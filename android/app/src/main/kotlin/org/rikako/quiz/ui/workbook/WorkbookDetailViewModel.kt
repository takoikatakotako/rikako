package org.rikako.quiz.ui.workbook

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch
import org.rikako.quiz.ServiceLocator
import org.rikako.quiz.data.model.WorkbookDetail
import org.rikako.quiz.data.repository.LearningRepository

sealed interface WorkbookDetailUiState {
    data object Loading : WorkbookDetailUiState
    data class Success(
        val detail: WorkbookDetail,
        val progress: Map<Long, Boolean> = emptyMap(),
    ) : WorkbookDetailUiState
    data class Error(val message: String) : WorkbookDetailUiState
}

class WorkbookDetailViewModel(
    private val workbookId: Long,
    private val repository: LearningRepository = ServiceLocator.learningRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow<WorkbookDetailUiState>(WorkbookDetailUiState.Loading)
    val uiState: StateFlow<WorkbookDetailUiState> = _uiState.asStateFlow()

    init {
        load()
        viewModelScope.launch {
            repository.learningDataChanged.collect { refreshProgress() }
        }
    }

    fun load() {
        _uiState.value = WorkbookDetailUiState.Loading
        viewModelScope.launch {
            _uiState.value = runCatching { repository.fetchWorkbookDetail(workbookId) }
                .fold(
                    onSuccess = { detail ->
                        val progress = runCatching { repository.fetchWorkbookProgress(workbookId) }
                            .getOrNull()?.results?.associate { it.questionId to it.isCorrect }.orEmpty()
                        WorkbookDetailUiState.Success(detail, progress)
                    },
                    onFailure = { WorkbookDetailUiState.Error(it.message ?: "読み込みに失敗しました") },
                )
        }
    }

    private suspend fun refreshProgress() {
        val current = _uiState.value as? WorkbookDetailUiState.Success ?: return
        val progress = runCatching { repository.fetchWorkbookProgress(workbookId) }
            .getOrNull()?.results?.associate { it.questionId to it.isCorrect } ?: return
        _uiState.value = current.copy(progress = progress)
    }

    companion object {
        fun factory(workbookId: Long): ViewModelProvider.Factory = viewModelFactory {
            initializer { WorkbookDetailViewModel(workbookId) }
        }
    }
}
