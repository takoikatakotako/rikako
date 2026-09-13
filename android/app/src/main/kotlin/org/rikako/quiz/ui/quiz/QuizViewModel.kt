package org.rikako.quiz.ui.quiz

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import org.rikako.quiz.ServiceLocator
import org.rikako.quiz.data.model.Question
import org.rikako.quiz.data.repository.LearningRepository

sealed interface QuizUiState {
    data object Loading : QuizUiState

    data class Error(val message: String) : QuizUiState

    /** 出題中。iOS と同じく選択した時点で正誤と解説を出し、次へ進むまで変更できない。 */
    data class Playing(
        val title: String,
        val questions: List<Question>,
        val currentIndex: Int,
        val answers: List<Int?>,
        val showExplanation: Boolean,
    ) : QuizUiState {
        val currentQuestion: Question get() = questions[currentIndex]
        val selectedChoice: Int? get() = answers.getOrNull(currentIndex)
        val isLastQuestion: Boolean get() = currentIndex == questions.lastIndex
        val hasAnswers: Boolean get() = answers.any { it != null }
    }

    data class Finished(
        val title: String,
        val questions: List<Question>,
        val answers: List<Int?>,
        val submission: SubmissionState,
    ) : QuizUiState {
        val correctCount: Int get() = QuizScoring.correctCount(questions, answers)
    }
}

sealed interface SubmissionState {
    data object Submitting : SubmissionState
    data object Success : SubmissionState
    data class Failed(val message: String) : SubmissionState
}

class QuizViewModel(
    private val workbookId: Long,
    private val repository: LearningRepository = ServiceLocator.learningRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow<QuizUiState>(QuizUiState.Loading)
    val uiState: StateFlow<QuizUiState> = _uiState.asStateFlow()

    init {
        load()
    }

    fun load() {
        _uiState.value = QuizUiState.Loading
        viewModelScope.launch {
            _uiState.value = runCatching { repository.fetchWorkbookDetail(workbookId) }
                .fold(
                    onSuccess = { detail ->
                        if (detail.questions.isEmpty()) {
                            QuizUiState.Error("この問題集には問題がありません")
                        } else {
                            QuizUiState.Playing(
                                title = detail.title,
                                questions = detail.questions,
                                currentIndex = 0,
                                answers = List(detail.questions.size) { null },
                                showExplanation = false,
                            )
                        }
                    },
                    onFailure = { QuizUiState.Error(it.message ?: "読み込みに失敗しました") },
                )
        }
    }

    fun selectChoice(index: Int) {
        _uiState.update { state ->
            val playing = state as? QuizUiState.Playing ?: return@update state
            if (playing.showExplanation) return@update state
            playing.copy(
                answers = playing.answers.toMutableList().also { it[playing.currentIndex] = index },
                showExplanation = true,
            )
        }
    }

    fun goToNext() {
        val playing = _uiState.value as? QuizUiState.Playing ?: return
        if (playing.isLastQuestion) {
            _uiState.value = QuizUiState.Finished(
                title = playing.title,
                questions = playing.questions,
                answers = playing.answers,
                submission = SubmissionState.Submitting,
            )
            submitAnswers()
        } else {
            _uiState.value = playing.copy(
                currentIndex = playing.currentIndex + 1,
                showExplanation = false,
            )
        }
    }

    /** 送信に失敗しても結果画面は出したままにして、ここから再送できるようにする。 */
    fun submitAnswers() {
        val finished = _uiState.value as? QuizUiState.Finished ?: return
        val items = QuizScoring.answerItems(finished.questions, finished.answers)
        if (items.isEmpty()) {
            _uiState.value = finished.copy(submission = SubmissionState.Success)
            return
        }

        _uiState.value = finished.copy(submission = SubmissionState.Submitting)
        viewModelScope.launch {
            val result = runCatching { repository.submitAnswers(workbookId, items) }
            _uiState.update { state ->
                val current = state as? QuizUiState.Finished ?: return@update state
                current.copy(
                    submission = result.fold(
                        onSuccess = { SubmissionState.Success },
                        onFailure = { SubmissionState.Failed(it.message ?: "送信に失敗しました") },
                    ),
                )
            }
        }
    }

    /**
     * 途中で抜けるときに、そこまでの回答だけ送る（iOS の「履歴を保存して戻る」に相当）。
     * 送信の成否に関わらず [onFinished] を呼んで画面を閉じる。
     */
    fun submitAnswersAndExit(onFinished: () -> Unit) {
        val playing = _uiState.value as? QuizUiState.Playing
        val items = playing?.let { QuizScoring.answerItems(it.questions, it.answers) }.orEmpty()
        if (items.isEmpty()) {
            onFinished()
            return
        }
        viewModelScope.launch {
            runCatching { repository.submitAnswers(workbookId, items) }
            onFinished()
        }
    }

    fun restart() {
        val state = _uiState.value
        val questions = when (state) {
            is QuizUiState.Finished -> state.questions
            is QuizUiState.Playing -> state.questions
            else -> return
        }
        val title = when (state) {
            is QuizUiState.Finished -> state.title
            is QuizUiState.Playing -> state.title
            else -> return
        }
        _uiState.value = QuizUiState.Playing(
            title = title,
            questions = questions,
            currentIndex = 0,
            answers = List(questions.size) { null },
            showExplanation = false,
        )
    }

    companion object {
        fun factory(workbookId: Long): ViewModelProvider.Factory = viewModelFactory {
            initializer { QuizViewModel(workbookId) }
        }
    }
}
