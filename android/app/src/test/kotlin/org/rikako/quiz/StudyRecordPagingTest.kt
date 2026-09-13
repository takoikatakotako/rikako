package org.rikako.quiz

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.withTimeout
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Before
import org.junit.Test
import org.rikako.quiz.data.remote.AnswerApi
import org.rikako.quiz.data.remote.ContentApi
import org.rikako.quiz.data.remote.UserApi
import org.rikako.quiz.data.repository.LearningRepository
import org.rikako.quiz.ui.record.StudyRecordUiState
import org.rikako.quiz.ui.record.StudyRecordViewModel

/**
 * ページ境界で先頭に行が増えたとき、表示件数を offset に使うと終端に到達できなくなる。
 * サーバーが返した件数で offset を進めていることを確認する。
 */
@OptIn(ExperimentalCoroutinesApi::class)
class StudyRecordPagingTest {

    private val requestedOffsets = mutableListOf<String?>()

    private fun log(id: Int) = """
        {"id":$id,"questionId":$id,"questionText":"問$id","workbookId":4,
         "workbookTitle":"化学基礎 その1","selectedChoice":0,"isCorrect":true,
         "answeredAt":"2026-09-13T01:00:00Z"}
    """.trimIndent()

    /** 1ページ目は id 20..1、2ページ目は「先頭に1件増えた」状態の続き（id 既知1件を含む）。 */
    private fun repository(): LearningRepository {
        val engine = MockEngine { request ->
            val path = request.url.encodedPath
            val body = when {
                path.endsWith("/summary") -> """{"totalAnswered":41,"totalCorrect":41,
                    "weeklyAnswered":41,"weeklyCorrect":41,"studyDates":[],"weeklyWorkbookIds":[]}"""

                else -> {
                    val offset = request.url.parameters["offset"]
                    requestedOffsets += offset
                    val ids = when (offset) {
                        "0", null -> (20 downTo 1).toList()
                        // 先頭に1件入ったので、同じ offset には既知の20件目が再登場する。
                        "20" -> listOf(20) + (40 downTo 22).toList()
                        else -> (21 downTo 21).toList()
                    }
                    """{"logs":[${ids.joinToString(",") { log(it) }}],"total":41}"""
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
            slug = "high-school-chemistry",
        )
    }

    @Before
    fun setUp() {
        Dispatchers.setMain(Dispatchers.Unconfined)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `offset はサーバーが返した件数で進み終端に到達する`() = runBlocking {
        val viewModel = StudyRecordViewModel(repository())
        val loaded = withTimeout(5_000) {
            viewModel.uiState.first { it is StudyRecordUiState.Success } as StudyRecordUiState.Success
        }
        assertEquals(20, loaded.logs.size)
        assertEquals(20, loaded.nextOffset)

        viewModel.loadMore()
        val second = withTimeout(5_000) {
            viewModel.uiState.first {
                it is StudyRecordUiState.Success && it.nextOffset > 20
            } as StudyRecordUiState.Success
        }

        // 重複した1件は表示から除くが、offset は受け取った20件ぶん進める。
        assertEquals(39, second.logs.size)
        assertEquals(40, second.nextOffset)

        viewModel.loadMore()
        val third = withTimeout(5_000) {
            viewModel.uiState.first {
                it is StudyRecordUiState.Success && it.nextOffset > 40
            } as StudyRecordUiState.Success
        }

        assertEquals(41, third.nextOffset)
        assertEquals(40, third.logs.size)
        assertFalse("終端に到達していない", third.canLoadMore)
        assertEquals(listOf("0", "20", "40"), requestedOffsets)
    }
}
