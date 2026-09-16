package org.rikako.quiz.ui.quiz

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import org.rikako.quiz.ServiceLocator
import org.rikako.quiz.data.model.AnswerItem
import org.rikako.quiz.data.model.Question
import org.rikako.quiz.data.model.toQuestion
import org.rikako.quiz.data.repository.LearningRepository
import org.rikako.quiz.ui.workbook.WorkbookSections

/** 何を出題するか。画面遷移から渡される。 */
sealed interface QuizMode {
    /** 問題集をそのまま解く。 */
    data class Workbook(val workbookId: Long, val sectionIndex: Int = 0) : QuizMode

    /** 間違えた問題をまとめて解き直す。 */
    data object Review : QuizMode
}

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
        val nextChapterNumber: Int?,
    ) : QuizUiState {
        val correctCount: Int get() = QuizScoring.correctCount(questions, answers)
        val wrongQuestions: List<Question> get() = QuizScoring.wrongQuestions(questions, answers)
    }
}

sealed interface SubmissionState {
    data object Submitting : SubmissionState
    data object Success : SubmissionState
    data class Failed(val message: String) : SubmissionState
}

class QuizViewModel(
    private val mode: QuizMode,
    private val repository: LearningRepository = ServiceLocator.learningRepository,
    // 送信は画面のライフサイクルから切り離す。結果画面を閉じても送信は最後まで走る。
    private val submissionScope: CoroutineScope = ServiceLocator.applicationScope,
) : ViewModel() {

    /**
     * 出題元。解き直しでは問題ごとに出身の問題集が違うため、読み込み時に確定する。
     * 回答の送信先（workbookId）はここから引く。
     */
    private var source: QuizSource = when (mode) {
        is QuizMode.Workbook -> QuizSource.Workbook(mode.workbookId)
        QuizMode.Review -> QuizSource.Review(emptyMap())
    }
    private var sections: List<List<Question>> = emptyList()
    private var currentSectionIndex = 0

    private val _uiState = MutableStateFlow<QuizUiState>(QuizUiState.Loading)
    val uiState: StateFlow<QuizUiState> = _uiState.asStateFlow()

    init {
        load()
    }

    fun load() {
        _uiState.value = QuizUiState.Loading
        viewModelScope.launch {
            _uiState.value = runCatching {
                when (mode) {
                    is QuizMode.Workbook -> loadWorkbook(mode.workbookId, mode.sectionIndex)
                    QuizMode.Review -> loadReview()
                }
            }.getOrElse { QuizUiState.Error(it.message ?: "読み込みに失敗しました") }
        }
    }

    private suspend fun loadWorkbook(workbookId: Long, sectionIndex: Int): QuizUiState {
        val detail = repository.fetchWorkbookDetail(workbookId)
        source = QuizSource.Workbook(workbookId)
        sections = WorkbookSections.split(detail.questions)
        if (sections.isEmpty()) return QuizUiState.Error("この問題集には問題がありません")
        if (sectionIndex !in sections.indices) return QuizUiState.Error("チャプターが見つかりません")
        currentSectionIndex = sectionIndex
        return playing(detail.title, sections[sectionIndex])
    }

    private suspend fun loadReview(): QuizUiState {
        val wrong = repository.fetchWrongAnswers(limit = REVIEW_LIMIT)
        // 出身の問題集は問題ごとに違うので、ここで対応表を作って送信先に使う。
        source = QuizSource.Review(wrong.questions.associate { it.id to it.workbookId })
        sections = emptyList()
        if (wrong.questions.isEmpty()) return QuizUiState.Error("間違えた問題はありません")
        return playing(REVIEW_TITLE, wrong.questions.map { it.toQuestion() })
    }

    private fun playing(title: String, questions: List<Question>) = QuizUiState.Playing(
        title = title,
        questions = questions,
        currentIndex = 0,
        answers = List(questions.size) { null },
        showExplanation = false,
    )

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
                nextChapterNumber = if (sections.isEmpty()) null else (currentSectionIndex + 1) % sections.size + 1,
            )
            submitAnswers()
        } else {
            _uiState.value = playing.copy(
                currentIndex = playing.currentIndex + 1,
                showExplanation = false,
            )
        }
    }

    /** 結果画面に入ったときに一度だけ送る。再送導線は冪等化（#377）まで出さない。 */
    private fun submitAnswers() {
        val finished = _uiState.value as? QuizUiState.Finished ?: return
        val grouped = source.groupedAnswers(finished.questions, finished.answers)
        if (grouped.isEmpty()) {
            _uiState.value = finished.copy(submission = SubmissionState.Success)
            return
        }

        _uiState.value = finished.copy(submission = SubmissionState.Submitting)
        viewModelScope.launch {
            // async は submissionScope 側なので、この ViewModel が破棄されても送信自体は継続する。
            val submission = submissionScope.async { submitGrouped(grouped) }
            val result = runCatching { submission.await() }
            // 画面を離れたことによるキャンセルは状態更新せずそのまま伝播させる。
            (result.exceptionOrNull() as? CancellationException)?.let { throw it }
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
        val grouped = playing?.let { source.groupedAnswers(it.questions, it.answers) }.orEmpty()
        if (grouped.isNotEmpty()) {
            // 送信を待たずに閉じる。送信は submissionScope で完走するので、
            // 送信中に画面が操作できてしまう状態も、二重送信も起きない。
            submissionScope.launch { runCatching { submitGrouped(grouped) } }
        }
        onFinished()
    }

    /** 解き直しでは問題集が混ざるので、問題集ごとに分けて送る。 */
    private suspend fun submitGrouped(grouped: Map<Long, List<AnswerItem>>) {
        // 復習は複数の問題集にまたがる。1件失敗しても後続を送る（iOS と同じ）。
        var firstFailure: Throwable? = null
        grouped.forEach { (workbookId, items) ->
            try {
                repository.submitAnswers(workbookId, items)
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                if (firstFailure == null) firstFailure = error
            }
        }
        firstFailure?.let { throw it }
    }

    fun restart() {
        val finished = _uiState.value as? QuizUiState.Finished ?: return
        _uiState.value = playing(finished.title, finished.questions)
    }

    /**
     * いま間違えた問題だけをその場で解き直す。出題元（source）はそのままなので、
     * 解き直しの回答も元の問題集へ記録される。
     */
    fun retryWrongAnswers() {
        val finished = _uiState.value as? QuizUiState.Finished ?: return
        val wrong = finished.wrongQuestions
        if (wrong.isEmpty()) return
        _uiState.value = playing(finished.title, wrong)
    }

    /** iOS の結果画面と同じく、最後のチャプターの次は最初へ戻る。 */
    fun startNextChapter() {
        val finished = _uiState.value as? QuizUiState.Finished ?: return
        if (sections.isEmpty()) return
        currentSectionIndex = (currentSectionIndex + 1) % sections.size
        _uiState.value = playing(finished.title, sections[currentSectionIndex])
    }

    companion object {
        /** 解き直しで一度に出す上限。多すぎると1回が終わらないので区切る。 */
        const val REVIEW_LIMIT = 50
        const val REVIEW_TITLE = "間違えた問題"

        fun factory(mode: QuizMode): ViewModelProvider.Factory = viewModelFactory {
            initializer { QuizViewModel(mode) }
        }
    }
}
