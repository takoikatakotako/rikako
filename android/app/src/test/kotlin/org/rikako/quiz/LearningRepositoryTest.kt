package org.rikako.quiz

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test
import org.rikako.quiz.data.identity.DeviceIdentityProvider
import org.rikako.quiz.data.remote.AnswerApi
import org.rikako.quiz.data.remote.ContentApi
import org.rikako.quiz.data.remote.UserApi
import org.rikako.quiz.data.repository.LearningRepository

class LearningRepositoryTest {

    private val workbooksJson = """
        {"workbooks":[
          {"id":1,"title":"無機化学","description":"","questionCount":10,"categoryId":100},
          {"id":2,"title":"IT基礎","description":"","questionCount":20,"categoryId":200},
          {"id":3,"title":"カテゴリ無し","description":"","questionCount":5}
        ]}
    """.trimIndent()

    private val appJson = """
        {"id":1,"slug":"high-school-chemistry","title":"4択化学","categories":[{"id":100,"title":"化学"}]}
    """.trimIndent()

    @Test
    fun `フレーバーのカテゴリに属する問題集だけを返す`() = runTest {
        val engine = MockEngine { request ->
            val body = if (request.url.encodedPath.endsWith("workbooks.json")) workbooksJson else appJson
            respond(
                content = body,
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, ContentType.Application.Json.toString()),
            )
        }
        val api = ContentApi(
            contentBaseUrl = "https://content.example/v1",
            apiBaseUrl = "https://api.example",
            client = ContentApi.defaultClient(engine),
        )
        val repository = LearningRepository(
            api = api,
            answerApi = AnswerApi("https://api.example", ContentApi.defaultClient(engine)),
            userApi = UserApi("https://api.example", ContentApi.defaultClient(engine)),
            session = signedOutSession(),
            identityProvider = FakeDeviceIdentityProvider("ap-northeast-1:test"),
            slug = "high-school-chemistry",
        )

        val workbooks = repository.fetchWorkbooks()

        assertEquals(listOf(1L), workbooks.map { it.id })
    }
}
