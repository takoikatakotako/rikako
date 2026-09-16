package org.rikako.quiz

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.withTimeout
import androidx.lifecycle.viewModelScope
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.rikako.quiz.data.auth.SubmissionGate
import org.rikako.quiz.data.remote.AnswerApi
import org.rikako.quiz.data.remote.ContentApi
import org.rikako.quiz.data.remote.UserApi
import org.rikako.quiz.data.repository.LearningRepository
import org.rikako.quiz.ui.quiz.QuizMode
import org.rikako.quiz.ui.quiz.QuizUiState
import org.rikako.quiz.ui.quiz.QuizViewModel

/**
 * 間違えた問題の解き直し。出身の問題集が混ざるので、回答は問題集ごとに分けて送る。
 */
@OptIn(ExperimentalCoroutinesApi::class)
class ReviewQuizTest {

    private val submitted = mutableListOf<String>()
    private val viewModels = mutableListOf<QuizViewModel>()

    /**
     * 送信用スコープ。テストをまたいでコルーチンや例外が漏れると次のテストが
     * UncaughtExceptionsBeforeTest で落ちるため、tearDown で必ず片付ける。
     */
    private val submissionErrors = mutableListOf<Throwable>()
    private val submissionScope = CoroutineScope(
        SupervisorJob() + Dispatchers.Unconfined +
            CoroutineExceptionHandler { _, e -> submissionErrors += e },
    )

    /** 送信は非同期なので、期待する件数が届くまで待つ。 */
    private suspend fun awaitSubmissions(count: Int) = withTimeout(5_000) {
        while (submitted.size < count) kotlinx.coroutines.delay(20)
        submitted.toList()
    }

    /** 問題4（ID 101）と問題7（ID 202）の2問が間違えた問題として返る。 */
    private val wrongAnswersJson = """
        {"questions":[
          {"id":101,"type":"single_choice","text":"問101","choices":["ア","イ"],"correct":0,
           "explanation":"解説101","images":[],"workbookId":4},
          {"id":202,"type":"single_choice","text":"問202","choices":["ア","イ"],"correct":1,
           "explanation":"解説202","images":[],"workbookId":7}
        ],"total":2}
    """.trimIndent()

    private fun repository(failWorkbookId: Long? = null): LearningRepository {
        val engine = MockEngine { request ->
            if (request.url.encodedPath == "/answers") {
                val body = (request.body as io.ktor.http.content.OutgoingContent.ByteArrayContent)
                    .bytes().decodeToString()
                submitted += body
                respond(
                    content = """{"correctCount":1,"totalCount":1}""",
                    status = if (failWorkbookId != null && body.contains("\"workbookId\":$failWorkbookId")) {
                        HttpStatusCode.InternalServerError
                    } else HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, ContentType.Application.Json.toString()),
                )
            } else {
                respond(
                    content = wrongAnswersJson,
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, ContentType.Application.Json.toString()),
                )
            }
        }
        val client = ContentApi.defaultClient(engine)
        return LearningRepository(
            api = ContentApi("https://content.example/v1", "https://api.example", client),
            answerApi = AnswerApi("https://api.example", client),
            userApi = UserApi("https://api.example", client),
            identityProvider = FakeDeviceIdentityProvider("ap-northeast-1:device"),
            session = signedOutSession(),
            submissionGate = SubmissionGate(),
            slug = "high-school-chemistry",
        )
    }

    @Before
    fun setUp() {
        Dispatchers.setMain(Dispatchers.Unconfined)
    }

    @After
    fun tearDown() {
        viewModels.forEach { it.viewModelScope.cancel() }
        submissionScope.cancel()
        Dispatchers.resetMain()
        assertEquals(emptyList<Throwable>(), submissionErrors)
    }

    @Test
    fun `解き直しの回答は出身の問題集ごとに送られる`() = runBlocking {
        val viewModel = QuizViewModel(
            QuizMode.Review,
            repository(),
            submissionScope,
        ).also(viewModels::add)
        val playing = withTimeout(5_000) {
            viewModel.uiState.first { it is QuizUiState.Playing } as QuizUiState.Playing
        }
        assertEquals("間違えた問題", playing.title)
        assertEquals(listOf(101L, 202L), playing.questions.map { it.id })

        viewModel.selectChoice(0)
        viewModel.goToNext()
        viewModel.selectChoice(1)
        viewModel.goToNext()

        val finished = withTimeout(5_000) {
            viewModel.uiState.first { it is QuizUiState.Finished } as QuizUiState.Finished
        }
        assertEquals(2, finished.correctCount)

        // 問題集4と問題集7に、それぞれの問題だけが送られる。
        assertEquals(
            setOf(
                """{"workbookId":4,"answers":[{"questionId":101,"selectedChoice":0}]}""",
                """{"workbookId":7,"answers":[{"questionId":202,"selectedChoice":1}]}""",
            ),
            awaitSubmissions(2).toSet(),
        )
    }

    @Test
    fun `間違えた問題だけを解き直せる`() = runBlocking {
        val viewModel = QuizViewModel(
            QuizMode.Review,
            repository(),
            submissionScope,
        ).also(viewModels::add)
        withTimeout(5_000) { viewModel.uiState.first { it is QuizUiState.Playing } }

        // 1問目を正解、2問目を不正解にする。
        viewModel.selectChoice(0)
        viewModel.goToNext()
        viewModel.selectChoice(0)
        viewModel.goToNext()

        val finished = withTimeout(5_000) {
            viewModel.uiState.first { it is QuizUiState.Finished } as QuizUiState.Finished
        }
        assertEquals(listOf(202L), finished.wrongQuestions.map { it.id })

        viewModel.retryWrongAnswers()

        val retry = viewModel.uiState.value as QuizUiState.Playing
        assertEquals(listOf(202L), retry.questions.map { it.id })
        assertEquals(listOf(null), retry.answers)
    }

    @Test
    fun `一つの問題集への送信が失敗しても別の問題集へは送る`() = runBlocking {
        val viewModel = QuizViewModel(QuizMode.Review, repository(failWorkbookId = 4), submissionScope)
            .also(viewModels::add)
        withTimeout(5_000) { viewModel.uiState.first { it is QuizUiState.Playing } }

        viewModel.selectChoice(0)
        viewModel.goToNext()
        viewModel.selectChoice(1)
        viewModel.goToNext()

        val result = withTimeout(5_000) {
            viewModel.uiState.first {
                it is QuizUiState.Finished && it.submission is org.rikako.quiz.ui.quiz.SubmissionState.Failed
            } as QuizUiState.Finished
        }
        assertEquals(2, result.correctCount)
        assertEquals(2, awaitSubmissions(2).size)
    }
}
