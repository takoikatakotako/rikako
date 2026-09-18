package org.rikako.quiz

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Test
import org.rikako.quiz.data.remote.ContentApi
import org.rikako.quiz.data.remote.UserApi

class WorkbookProgressApiTest {
    @Test
    fun `問題集の進捗を認証付きで取得する`() = runBlocking {
        val engine = MockEngine { request ->
            assertEquals("/users/me/workbook-progress", request.url.encodedPath)
            assertEquals("42", request.url.parameters["workbook_id"])
            assertEquals("device-1", request.headers["X-Device-ID"])
            assertEquals("Bearer token-1", request.headers[HttpHeaders.Authorization])
            respond(
                content = """{"results":[{"questionId":101,"isCorrect":true}]}""",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, ContentType.Application.Json.toString()),
            )
        }
        val api = UserApi("https://api.example", ContentApi.defaultClient(engine))

        val result = api.fetchWorkbookProgress("device-1", "token-1", 42)
        assertEquals(101L, result.results.single().questionId)
        assertEquals(true, result.results.single().isCorrect)
    }
}
