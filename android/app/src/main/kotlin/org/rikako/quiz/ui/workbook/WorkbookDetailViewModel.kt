package org.rikako.quiz.ui.workbook

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.rikako.quiz.ServiceLocator
import org.rikako.quiz.data.model.WorkbookDetail
import org.rikako.quiz.data.repository.LearningRepository

sealed interface WorkbookDetailUiState {
    data object Loading : WorkbookDetailUiState
    data class Success(val detail: WorkbookDetail) : WorkbookDetailUiState
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
    }

    fun load() {
        _uiState.value = WorkbookDetailUiState.Loading
        viewModelScope.launch {
            _uiState.value = runCatching { repository.fetchWorkbookDetail(workbookId) }
                .fold(
                    onSuccess = { WorkbookDetailUiState.Success(it) },
                    onFailure = { WorkbookDetailUiState.Error(it.message ?: "読み込みに失敗しました") },
                )
        }
    }

    companion object {
        fun factory(workbookId: Long): ViewModelProvider.Factory = viewModelFactory {
            initializer { WorkbookDetailViewModel(workbookId) }
        }
    }
}
