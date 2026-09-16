package org.rikako.quiz

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.OutgoingContent
import io.ktor.http.headersOf
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.rikako.quiz.data.model.ChatMessageRequest
import org.rikako.quiz.data.model.ChatRequest
import org.rikako.quiz.data.remote.ChatApi
import org.rikako.quiz.data.remote.ContentApi
import org.rikako.quiz.data.remote.UserApi

class MyPageAndChatApiTest {
    @Test fun `AI質問は選択肢と会話履歴を認証付きで送る`() = runBlocking {
        val engine = MockEngine { request ->
            assertEquals(HttpMethod.Post, request.method)
            assertEquals("/questions/12/chat", request.url.encodedPath)
            assertEquals("device-1", request.headers["X-Device-ID"])
            assertEquals("Bearer token", request.headers[HttpHeaders.Authorization])
            val body = (request.body as OutgoingContent.ByteArrayContent).bytes().decodeToString()
            assertTrue(body.contains("\"selectedChoice\":2"))
            assertTrue(body.contains("\"role\":\"user\""))
            respond(
                """{"reply":"解説","turnCount":1,"remainingTurns":4}""",
                HttpStatusCode.OK,
                headersOf(HttpHeaders.ContentType, ContentType.Application.Json.toString()),
            )
        }
        val response = ChatApi("https://api.example", ContentApi.defaultClient(engine)).chat(
            12, "device-1", "token", ChatRequest(listOf(ChatMessageRequest("user", "なぜ？")), 2),
        )
        assertEquals("解説", response.reply)
        assertEquals(4, response.remainingTurns)
    }

    @Test fun `プロフィール更新はアプリ識別子と表示名を送る`() = runBlocking {
        val engine = MockEngine { request ->
            assertEquals(HttpMethod.Put, request.method)
            assertEquals("/users/me", request.url.encodedPath)
            assertEquals("high-school-chemistry", request.headers["X-App-Slug"])
            assertEquals("device-1", request.headers["X-Device-ID"])
            val body = (request.body as OutgoingContent.ByteArrayContent).bytes().decodeToString()
            assertTrue(body.contains("\"displayName\":\"理科子\""))
            respond(
                """{"userId":3,"identityId":"device-1","displayName":"理科子"}""",
                HttpStatusCode.OK,
                headersOf(HttpHeaders.ContentType, ContentType.Application.Json.toString()),
            )
        }
        val profile = UserApi("https://api.example", ContentApi.defaultClient(engine)).updateProfile(
            "device-1", null, "high-school-chemistry", "理科子",
        )
        assertEquals("理科子", profile.displayName)
    }
}
