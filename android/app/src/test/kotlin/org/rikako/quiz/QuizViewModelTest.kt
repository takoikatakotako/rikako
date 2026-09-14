package org.rikako.quiz

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CompletableDeferred
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
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.rikako.quiz.data.auth.SubmissionGate
import org.rikako.quiz.data.remote.AnswerApi
import org.rikako.quiz.data.remote.ContentApi
import org.rikako.quiz.data.remote.UserApi
import org.rikako.quiz.data.repository.LearningRepository
import org.rikako.quiz.ui.quiz.QuizUiState
import org.rikako.quiz.ui.quiz.QuizViewModel

@OptIn(ExperimentalCoroutinesApi::class)
class QuizViewModelTest {

    private val detailJson = """
        {"id":4,"title":"化学基礎 その1","description":"","categoryId":1,"questions":[
          {"id":101,"text":"問1","choices":["ア","イ"],"correct":1},
          {"id":102,"text":"問2","choices":["ア","イ"],"correct":0}
        ]}
    """.trimIndent()

    /** POST /answers が届いた時点で完了する（リクエストの本文を持つ）。 */
    private val requestStarted = CompletableDeferred<String>()

    /** テストがレスポンスを返すタイミングを握るためのゲート。 */
    private val releaseResponse = CompletableDeferred<Unit>()

    private val submitted = mutableListOf<String>()

    private fun repository(): LearningRepository {
        val engine = MockEngine { request ->
            if (request.url.encodedPath == "/answers") {
                val body = (request.body as io.ktor.http.content.OutgoingContent.ByteArrayContent)
                    .bytes()
                    .decodeToString()
                requestStarted.complete(body)
                releaseResponse.await()
                submitted += body
                respond(
                    content = """{"correctCount":1,"totalCount":1}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, ContentType.Application.Json.toString()),
                )
            } else {
                respond(
                    content = detailJson,
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, ContentType.Application.Json.toString()),
                )
            }
        }
        val client = ContentApi.defaultClient(engine)
        return LearningRepository(
            api = ContentApi("https://content.example/v1", "https://api.example", client),
            userApi = UserApi("https://api.example", client),
            answerApi = AnswerApi("https://api.example", client),
            session = signedOutSession(),
            submissionGate = SubmissionGate(),
            identityProvider = FakeDeviceIdentityProvider("ap-northeast-1:device"),
            slug = "high-school-chemistry",
        )
    }

    /**
     * 送信用スコープ。テストをまたいで例外やコルーチンが漏れると、次のテストが
     * UncaughtExceptionsBeforeTest で落ちるため、SupervisorJob + ハンドラを付けて
     * tearDown で必ず片付ける。
     */
    private val submissionErrors = mutableListOf<Throwable>()
    private val submissionScope = CoroutineScope(
        SupervisorJob() + Dispatchers.Unconfined +
            CoroutineExceptionHandler { _, e -> submissionErrors += e },
    )

    private fun viewModel() = QuizViewModel(4, repository(), submissionScope)

    @Before
    fun setUp() {
        Dispatchers.setMain(Dispatchers.Unconfined)
    }

    @After
    fun tearDown() {
        // 保留中のリクエストを解放してからスコープを閉じる。
        releaseResponse.complete(Unit)
        submissionScope.cancel()
        Dispatchers.resetMain()
        assertTrue(submissionErrors.isEmpty())
    }

    @Test
    fun `履歴を保存して戻るは送信完了を待たずに一度だけ戻る`() = runBlocking {
        val viewModel = viewModel()
        viewModel.uiState.first { it is QuizUiState.Playing }
        viewModel.selectChoice(1)

        var finishedCount = 0
        viewModel.submitAnswersAndExit { finishedCount++ }

        // 送信中でも画面は閉じる（＝送信完了を待たない）。
        assertEquals(1, finishedCount)
        assertTrue(submitted.isEmpty())

        // 画面を離れた後も送信は継続し、回答済みの1問だけが送られる。
        val body = withTimeout(5_000) { requestStarted.await() }
        assertEquals("""{"workbookId":4,"answers":[{"questionId":101,"selectedChoice":1}]}""", body)

        releaseResponse.complete(Unit)
        assertEquals(1, finishedCount)
    }

    @Test
    fun `未回答のまま戻るときは送信しない`() = runBlocking {
        val viewModel = viewModel()
        viewModel.uiState.first { it is QuizUiState.Playing }

        var finishedCount = 0
        viewModel.submitAnswersAndExit { finishedCount++ }

        assertEquals(1, finishedCount)
        assertTrue(requestStarted.isCompleted.not())
    }

    @Test
    fun `最終問題を終えると結果画面になり回答を送信する`() = runBlocking {
        releaseResponse.complete(Unit)
        val viewModel = viewModel()
        viewModel.uiState.first { it is QuizUiState.Playing }

        viewModel.selectChoice(1)
        viewModel.goToNext()
        viewModel.selectChoice(0)
        viewModel.goToNext()

        val state = withTimeout(5_000) {
            viewModel.uiState.first { it is QuizUiState.Finished } as QuizUiState.Finished
        }
        assertEquals(2, state.correctCount)

        withTimeout(5_000) { requestStarted.await() }
        assertEquals(
            listOf("""{"workbookId":4,"answers":[{"questionId":101,"selectedChoice":1},{"questionId":102,"selectedChoice":0}]}"""),
            submitted,
        )
    }
}
