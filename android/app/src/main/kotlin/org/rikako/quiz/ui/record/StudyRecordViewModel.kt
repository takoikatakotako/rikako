package org.rikako.quiz.ui.record

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Job
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
        /**
         * 次に要求する offset。表示件数ではなくサーバーから受け取った件数で進める。
         * 重複を弾いた後の logs.size を使うと、ページ境界で行が増えたときに毎回
         * 1件ずつ重なって終端に到達できなくなる。
         */
        val nextOffset: Int,
        val isLoadingMore: Boolean = false,
    ) : StudyRecordUiState {
        val canLoadMore: Boolean get() = nextOffset < total
    }
}

class StudyRecordViewModel(
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

    private val _uiState = MutableStateFlow<StudyRecordUiState>(StudyRecordUiState.Loading)
    val uiState: StateFlow<StudyRecordUiState> = _uiState.asStateFlow()

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

        _uiState.value = StudyRecordUiState.Loading
        loadJob = viewModelScope.launch {
            val result = runCatching {
                val summary = repository.fetchSummary()
                val logs = repository.fetchAnswerLogs()
                StudyRecordUiState.Success(
                    summary = summary,
                    logs = logs.logs,
                    total = logs.total,
                    nextOffset = logs.logs.size,
                )
            }
            if (startedAt != generation) return@launch
            _uiState.value = result
                .getOrElse { StudyRecordUiState.Error(it.message ?: "読み込みに失敗しました") }
        }
    }

    fun loadMore() {
        val current = _uiState.value as? StudyRecordUiState.Success ?: return
        if (current.isLoadingMore || !current.canLoadMore) return

        val startedAt = generation
        _uiState.value = current.copy(isLoadingMore = true)
        loadMoreJob = viewModelScope.launch {
            val result = runCatching { repository.fetchAnswerLogs(offset = current.nextOffset) }
            // 再読込が始まっていたら、このページは今の状態に連結できない。
            if (startedAt != generation) return@launch
            _uiState.update { state ->
                val success = state as? StudyRecordUiState.Success ?: return@update state
                result.fold(
                    // 同じ log が二重に並ばないよう id で弾く（ページ境界で追加回答が入った場合）。
                    onSuccess = { page ->
                        val known = success.logs.mapTo(mutableSetOf()) { it.id }
                        success.copy(
                            logs = success.logs + page.logs.filter { it.id !in known },
                            total = page.total,
                            nextOffset = success.nextOffset + page.logs.size,
                            isLoadingMore = false,
                        )
                    },
                    // 取得できなかったページは進めない（次のスクロールで同じ offset を取り直す）。
                    onFailure = { success.copy(isLoadingMore = false) },
                )
            }
        }
    }
}
