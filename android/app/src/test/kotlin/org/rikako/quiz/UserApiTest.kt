package org.rikako.quiz

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.ktor.http.content.OutgoingContent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.rikako.quiz.data.auth.SubmissionGate
import org.rikako.quiz.data.remote.AnswerApi
import org.rikako.quiz.data.remote.ContentApi
import org.rikako.quiz.data.remote.UserApi
import org.rikako.quiz.data.repository.LearningRepository
import org.junit.Test

class UserApiTest {

    private val requests = mutableListOf<Pair<String, String?>>()

    private fun repository(body: String): LearningRepository {
        val engine = MockEngine { request ->
            requests += "${request.url.encodedPath}?${request.url.encodedQuery}" to request.headers["X-Device-ID"]
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
            session = signedOutSession(),
            submissionGate = SubmissionGate(),
            identityProvider = FakeDeviceIdentityProvider("ap-northeast-1:device"),
            slug = "high-school-chemistry",
        )
    }

    @Test
    fun `サマリーを X-Device-ID 付きで取得する`() = runTest {
        val repository = repository(
            """{"totalAnswered":120,"totalCorrect":90,"weeklyAnswered":20,"weeklyCorrect":15,
               "studyDates":["2026-09-12","2026-09-13"],"weeklyWorkbookIds":[4]}""",
        )

        val summary = repository.fetchSummary()

        assertEquals(120, summary.totalAnswered)
        assertEquals(90, summary.totalCorrect)
        assertEquals(listOf("2026-09-12", "2026-09-13"), summary.studyDates)
        assertEquals("/users/me/summary?" to "ap-northeast-1:device", requests.single())
    }

    @Test
    fun `回答履歴はページングのパラメータを付ける`() = runTest {
        val repository = repository("""{"logs":[],"total":0}""")

        repository.fetchAnswerLogs(offset = 40)

        assertEquals(
            "/users/me/answer-logs?limit=20&offset=40" to "ap-northeast-1:device",
            requests.single(),
        )
    }

    @Test
    fun `間違えた問題を取得する`() = runTest {
        val repository = repository(
            """{"questions":[{"id":101,"type":"single_choice","text":"問1","choices":["ア","イ"],
               "correct":1,"explanation":"解説","images":[],"workbookId":4}],"total":1}""",
        )

        val result = repository.fetchWrongAnswers()

        assertEquals(1, result.total)
        assertEquals(4L, result.questions.single().workbookId)
        assertEquals(1, result.questions.single().correct)
        assertEquals(
            "/users/me/wrong-answers?limit=20&offset=0" to "ap-northeast-1:device",
            requests.single(),
        )
    }

    @Test
    fun `選択した問題集だけをプロフィールへ送る`() = runTest {
        val engine = MockEngine { request ->
            assertEquals("PUT", request.method.value)
            assertEquals("/users/me", request.url.encodedPath)
            assertEquals("high-school-chemistry", request.headers["X-App-Slug"])
            assertEquals("ap-northeast-1:device", request.headers["X-Device-ID"])
            val body = (request.body as OutgoingContent.ByteArrayContent).bytes().decodeToString()
            assertEquals("""{"selectedWorkbookId":7}""", body)
            respond(
                """{"identityId":"ap-northeast-1:device","selectedWorkbookId":7}""",
                HttpStatusCode.OK,
                headersOf(HttpHeaders.ContentType, ContentType.Application.Json.toString()),
            )
        }
        val client = ContentApi.defaultClient(engine)
        val repository = LearningRepository(
            api = ContentApi("https://content.example/v1", "https://api.example", client),
            answerApi = AnswerApi("https://api.example", client),
            userApi = UserApi("https://api.example", client),
            session = signedOutSession(),
            submissionGate = SubmissionGate(),
            identityProvider = FakeDeviceIdentityProvider("ap-northeast-1:device"),
            slug = "high-school-chemistry",
        )

        assertEquals(7L, repository.updateSelectedWorkbook(7).selectedWorkbookId)
    }
}
