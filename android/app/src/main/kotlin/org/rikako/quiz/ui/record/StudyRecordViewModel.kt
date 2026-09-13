package org.rikako.quiz.ui.record

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import org.rikako.quiz.ServiceLocator
import org.rikako.quiz.data.model.AnswerLogItem
import org.rikako.quiz.data.model.UserSummary
import org.rikako.quiz.data.repository.LearningRepository

sealed interface StudyRecordUiState {
    data object Loading : StudyRecordUiState

    data class Error(val message: String) : StudyRecordUiState

    data class Success(
        val summary: UserSummary,
        val logs: List<AnswerLogItem>,
        val total: Int,
        val isLoadingMore: Boolean = false,
    ) : StudyRecordUiState {
        val canLoadMore: Boolean get() = logs.size < total
    }
}

class StudyRecordViewModel(
    private val repository: LearningRepository = ServiceLocator.learningRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow<StudyRecordUiState>(StudyRecordUiState.Loading)
    val uiState: StateFlow<StudyRecordUiState> = _uiState.asStateFlow()

    init {
        load()
    }

    fun load() {
        _uiState.value = StudyRecordUiState.Loading
        viewModelScope.launch {
            _uiState.value = runCatching {
                val summary = repository.fetchSummary()
                val logs = repository.fetchAnswerLogs()
                StudyRecordUiState.Success(summary, logs.logs, logs.total)
            }.getOrElse { StudyRecordUiState.Error(it.message ?: "読み込みに失敗しました") }
        }
    }

    fun loadMore() {
        val current = _uiState.value as? StudyRecordUiState.Success ?: return
        if (current.isLoadingMore || !current.canLoadMore) return

        _uiState.value = current.copy(isLoadingMore = true)
        viewModelScope.launch {
            val result = runCatching { repository.fetchAnswerLogs(offset = current.logs.size) }
            _uiState.update { state ->
                val success = state as? StudyRecordUiState.Success ?: return@update state
                result.fold(
                    // 同じ log が二重に並ばないよう id で弾く（ページ境界で追加回答が入った場合）。
                    onSuccess = { page ->
                        val known = success.logs.mapTo(mutableSetOf()) { it.id }
                        success.copy(
                            logs = success.logs + page.logs.filter { it.id !in known },
                            total = page.total,
                            isLoadingMore = false,
                        )
                    },
                    onFailure = { success.copy(isLoadingMore = false) },
                )
            }
        }
    }
}
