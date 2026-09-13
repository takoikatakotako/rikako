package org.rikako.quiz.ui.wrong

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Job
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
        /** 次に要求する offset。表示件数ではなくサーバーから受け取った件数で進める。 */
        val nextOffset: Int,
        val expandedIds: Set<Long> = emptySet(),
        val isLoadingMore: Boolean = false,
    ) : WrongAnswersUiState {
        val canLoadMore: Boolean get() = nextOffset < total
    }
}

class WrongAnswersViewModel(
    private val repository: LearningRepository = ServiceLocator.learningRepository,
) : ViewModel() {

    /**
     * 読み込みの世代。load を始めるたびに進め、開始時と一致する応答だけ適用する。
     * これが無いと、進行中の loadMore の応答が再読込後の状態に連結され、
     * その分の offset が飛ばされて表示が欠ける。
     */
    private var generation = 0
    private var loadJob: Job? = null
    private var loadMoreJob: Job? = null

    private val _uiState = MutableStateFlow<WrongAnswersUiState>(WrongAnswersUiState.Loading)
    val uiState: StateFlow<WrongAnswersUiState> = _uiState.asStateFlow()

    init {
        load()
        // 回答が送信されたら読み直す。init だけだと、タブを開いたあとに問題を解いても
        // 古い集計・古い間違い状態が残り続ける。
        viewModelScope.launch {
            repository.learningDataChanged.collect { load() }
        }
    }

    fun load() {
        generation++
        loadMoreJob?.cancel()
        loadJob?.cancel()
        val startedAt = generation

        _uiState.value = WrongAnswersUiState.Loading
        loadJob = viewModelScope.launch {
            val result = runCatching { repository.fetchWrongAnswers() }
            if (startedAt != generation) return@launch
            _uiState.value = result
                .fold(
                    onSuccess = {
                        WrongAnswersUiState.Success(
                            questions = it.questions,
                            total = it.total,
                            nextOffset = it.questions.size,
                        )
                    },
                    onFailure = { WrongAnswersUiState.Error(it.message ?: "読み込みに失敗しました") },
                )
        }
    }

    fun loadMore() {
        val current = _uiState.value as? WrongAnswersUiState.Success ?: return
        if (current.isLoadingMore || !current.canLoadMore) return

        val startedAt = generation
        _uiState.value = current.copy(isLoadingMore = true)
        loadMoreJob = viewModelScope.launch {
            val result = runCatching { repository.fetchWrongAnswers(offset = current.nextOffset) }
            // 再読込が始まっていたら、このページは今の状態に連結できない。
            if (startedAt != generation) return@launch
            _uiState.update { state ->
                val success = state as? WrongAnswersUiState.Success ?: return@update state
                result.fold(
                    onSuccess = { page ->
                        val known = success.questions.mapTo(mutableSetOf()) { it.id }
                        success.copy(
                            questions = success.questions + page.questions.filter { it.id !in known },
                            total = page.total,
                            nextOffset = success.nextOffset + page.questions.size,
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
