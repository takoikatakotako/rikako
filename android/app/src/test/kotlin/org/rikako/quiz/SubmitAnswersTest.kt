package org.rikako.quiz

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.ktor.utils.io.ByteReadChannel
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test
import org.rikako.quiz.data.model.AnswerItem
import org.rikako.quiz.data.auth.SubmissionGate
import org.rikako.quiz.data.remote.AnswerApi
import org.rikako.quiz.data.remote.ContentApi
import org.rikako.quiz.data.remote.UserApi
import org.rikako.quiz.data.repository.LearningRepository

class SubmitAnswersTest {

    @Test
    fun `X-Device-ID を付けて回答を送信し結果を返す`() = runTest {
        var deviceId: String? = null
        var body: String? = null
        var method: HttpMethod? = null
        var path: String? = null

        val engine = MockEngine { request ->
            deviceId = request.headers["X-Device-ID"]
            method = request.method
            path = request.url.encodedPath
            body = (request.body as io.ktor.http.content.OutgoingContent.ByteArrayContent)
                .bytes()
                .decodeToString()
            respond(
                content = ByteReadChannel("""{"correctCount":2,"totalCount":3}"""),
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, ContentType.Application.Json.toString()),
            )
        }
        val client = ContentApi.defaultClient(engine)
        val repository = LearningRepository(
            api = ContentApi("https://content.example/v1", "https://api.example", client),
            userApi = UserApi("https://api.example", client),
            answerApi = AnswerApi("https://api.example", client),
            session = signedOutSession(),
            submissionGate = SubmissionGate(),
            identityProvider = FakeDeviceIdentityProvider("ap-northeast-1:device"),
            slug = "high-school-chemistry",
        )

        val result = repository.submitAnswers(
            workbookId = 4,
            answers = listOf(AnswerItem(1021, 2), AnswerItem(1040, 0)),
        )

        assertEquals(2, result.correctCount)
        assertEquals(3, result.totalCount)
        assertEquals("ap-northeast-1:device", deviceId)
        assertEquals(HttpMethod.Post, method)
        assertEquals("/answers", path)
        assertEquals(
            """{"workbookId":4,"answers":[{"questionId":1021,"selectedChoice":2},{"questionId":1040,"selectedChoice":0}]}""",
            body,
        )
    }
}
