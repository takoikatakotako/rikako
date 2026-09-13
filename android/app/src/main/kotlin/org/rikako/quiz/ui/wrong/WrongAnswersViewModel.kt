package org.rikako.quiz.ui.wrong

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import org.rikako.quiz.ServiceLocator
import org.rikako.quiz.data.model.WrongAnswerQuestion
import org.rikako.quiz.data.repository.LearningRepository

sealed interface WrongAnswersUiState {
    data object Loading : WrongAnswersUiState

    data class Error(val message: String) : WrongAnswersUiState

    data class Success(
        val questions: List<WrongAnswerQuestion>,
        val total: Int,
        val expandedIds: Set<Long> = emptySet(),
        val isLoadingMore: Boolean = false,
    ) : WrongAnswersUiState {
        val canLoadMore: Boolean get() = questions.size < total
    }
}

class WrongAnswersViewModel(
    private val repository: LearningRepository = ServiceLocator.learningRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow<WrongAnswersUiState>(WrongAnswersUiState.Loading)
    val uiState: StateFlow<WrongAnswersUiState> = _uiState.asStateFlow()

    init {
        load()
    }

    fun load() {
        _uiState.value = WrongAnswersUiState.Loading
        viewModelScope.launch {
            _uiState.value = runCatching { repository.fetchWrongAnswers() }
                .fold(
                    onSuccess = { WrongAnswersUiState.Success(it.questions, it.total) },
                    onFailure = { WrongAnswersUiState.Error(it.message ?: "読み込みに失敗しました") },
                )
        }
    }

    fun loadMore() {
        val current = _uiState.value as? WrongAnswersUiState.Success ?: return
        if (current.isLoadingMore || !current.canLoadMore) return

        _uiState.value = current.copy(isLoadingMore = true)
        viewModelScope.launch {
            val result = runCatching { repository.fetchWrongAnswers(offset = current.questions.size) }
            _uiState.update { state ->
                val success = state as? WrongAnswersUiState.Success ?: return@update state
                result.fold(
                    onSuccess = { page ->
                        val known = success.questions.mapTo(mutableSetOf()) { it.id }
                        success.copy(
                            questions = success.questions + page.questions.filter { it.id !in known },
                            total = page.total,
                            isLoadingMore = false,
                        )
                    },
                    onFailure = { success.copy(isLoadingMore = false) },
                )
            }
        }
    }

    /** 解説の開閉。 */
    fun toggleExpanded(questionId: Long) {
        _uiState.update { state ->
            val success = state as? WrongAnswersUiState.Success ?: return@update state
            val expanded = success.expandedIds
            success.copy(
                expandedIds = if (questionId in expanded) expanded - questionId else expanded + questionId,
            )
        }
    }
}
