package org.rikako.quiz.ui.workbook

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.rikako.quiz.ServiceLocator
import org.rikako.quiz.data.model.Workbook
import org.rikako.quiz.data.repository.LearningRepository

sealed interface WorkbookListUiState {
    data object Loading : WorkbookListUiState
    data class Success(val workbooks: List<Workbook>) : WorkbookListUiState
    data class Error(val message: String) : WorkbookListUiState
}

class WorkbookListViewModel(
    private val repository: LearningRepository = ServiceLocator.learningRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow<WorkbookListUiState>(WorkbookListUiState.Loading)
    val uiState: StateFlow<WorkbookListUiState> = _uiState.asStateFlow()

    init {
        load()
    }

    fun load() {
        _uiState.value = WorkbookListUiState.Loading
        viewModelScope.launch {
            _uiState.value = runCatching { repository.fetchWorkbooks() }
                .fold(
                    onSuccess = { WorkbookListUiState.Success(it) },
                    onFailure = { WorkbookListUiState.Error(it.message ?: "読み込みに失敗しました") },
                )
        }
    }
}
