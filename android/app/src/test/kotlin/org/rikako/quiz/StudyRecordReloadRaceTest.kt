package org.rikako.quiz

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.withTimeout
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.rikako.quiz.data.auth.SubmissionGate
import org.rikako.quiz.data.remote.AnswerApi
import org.rikako.quiz.data.remote.ContentApi
import org.rikako.quiz.data.remote.UserApi
import org.rikako.quiz.data.repository.LearningRepository
import org.rikako.quiz.ui.record.StudyRecordUiState
import org.rikako.quiz.ui.record.StudyRecordViewModel

/**
 * 進行中の loadMore の応答が、再読込後の状態に連結されないことを確認する。
 * 連結してしまうと、その分の offset が飛ばされて表示が欠ける。
 */
@OptIn(ExperimentalCoroutinesApi::class)
class StudyRecordReloadRaceTest {

    /** 3ページ目（offset=40）の応答をテストが握るためのゲート。 */
    private val releaseThirdPage = CompletableDeferred<Unit>()
    private val thirdPageRequested = CompletableDeferred<Unit>()

    private fun log(id: Int) = """
        {"id":$id,"questionId":$id,"questionText":"問$id","workbookId":4,
         "workbookTitle":"化学基礎 その1","selectedChoice":0,"isCorrect":true,
         "answeredAt":"2026-09-13T01:00:00Z"}
    """.trimIndent()

    private fun repository(): LearningRepository {
        val engine = MockEngine { request ->
            val body = if (request.url.encodedPath.endsWith("/summary")) {
                """{"totalAnswered":60,"totalCorrect":60,"weeklyAnswered":60,
                   "weeklyCorrect":60,"studyDates":[],"weeklyWorkbookIds":[]}"""
            } else {
                when (request.url.parameters["offset"]) {
                    "40" -> {
                        thirdPageRequested.complete(Unit)
                        releaseThirdPage.await()
                        """{"logs":[${(60 downTo 41).joinToString(",") { log(it) }}],"total":60}"""
                    }

                    "20" -> """{"logs":[${(40 downTo 21).joinToString(",") { log(it) }}],"total":60}"""
                    else -> """{"logs":[${(20 downTo 1).joinToString(",") { log(it) }}],"total":60}"""
                }
            }
            respond(
                content = body,
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, ContentType.Application.Json.toString()),
            )
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
        releaseThirdPage.complete(Unit)
        Dispatchers.resetMain()
    }

    @Test
    fun `loadMore 中に再読込が入ったら古いページは適用しない`() = runBlocking {
        val viewModel = StudyRecordViewModel(repository())
        withTimeout(5_000) { viewModel.uiState.first { it is StudyRecordUiState.Success } }

        // 40件まで読み込む。
        viewModel.loadMore()
        val second = withTimeout(5_000) {
            viewModel.uiState.first {
                it is StudyRecordUiState.Success && it.nextOffset == 40
            } as StudyRecordUiState.Success
        }
        assertEquals(40, second.logs.size)

        // 3ページ目の取得中に、回答完了などで再読込が走る。
        viewModel.loadMore()
        withTimeout(5_000) { thirdPageRequested.await() }
        viewModel.load()
        val reloaded = withTimeout(5_000) {
            viewModel.uiState.first {
                it is StudyRecordUiState.Success && it.nextOffset == 20
            } as StudyRecordUiState.Success
        }

        assertEquals(20, reloaded.logs.size)
        assertEquals(20, reloaded.nextOffset)

        // 保留していた3ページ目を返す。適用されてしまうと logs が増え、nextOffset が飛ぶ。
        releaseThirdPage.complete(Unit)
        kotlinx.coroutines.delay(300)

        val stillFresh = viewModel.uiState.value as StudyRecordUiState.Success
        assertEquals("古いページが連結されている", 20, stillFresh.logs.size)
        assertEquals(20, stillFresh.nextOffset)
    }
}
