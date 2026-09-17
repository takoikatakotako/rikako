package org.rikako.quiz

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.OutgoingContent
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.rikako.quiz.data.auth.SubmissionGate
import org.rikako.quiz.data.identity.CognitoDeviceIdentityProvider
import org.rikako.quiz.data.identity.IdentityStore
import org.rikako.quiz.data.remote.AnswerApi
import org.rikako.quiz.data.remote.CognitoIdentityApi
import org.rikako.quiz.data.remote.ContentApi
import org.rikako.quiz.data.remote.TransferApi
import org.rikako.quiz.data.remote.UserApi
import org.rikako.quiz.data.repository.LearningRepository
import org.rikako.quiz.ui.mypage.normalizedTransferToken
import org.rikako.quiz.ui.mypage.formatTransferExpiry

class TransferTest {
    @Test fun `引き継ぎトークンの取得と更新は端末IDを送る`() = runTest {
        val paths = mutableListOf<String>()
        val methods = mutableListOf<String>()
        val client = ContentApi.defaultClient(MockEngine { request ->
            paths += request.url.encodedPath
            methods += request.method.value
            assertEquals("old-device", request.headers["X-Device-ID"])
            respond(
                """{"token":"${"a".repeat(64)}","expires_at":"2029-09-17T00:00:00Z"}""",
                HttpStatusCode.OK,
                headersOf(HttpHeaders.ContentType, ContentType.Application.Json.toString()),
            )
        })
        val api = TransferApi("https://api.example", client)

        assertEquals("a".repeat(64), api.fetchToken("old-device").token)
        assertEquals("2029-09-17T00:00:00Z", api.refreshToken("old-device").expiresAt)
        assertEquals(listOf("/transfer/token", "/transfer/token"), paths)
        assertEquals(listOf("GET", "POST"), methods)
    }

    @Test fun `引き継ぎ後の identity は次の通信から切り替わる`() = runTest {
        val store = object : IdentityStore {
            var value: String? = "old-device"
            override fun load(): String? = value
            override fun save(value: String) { this.value = value }
            override fun clear() { value = null }
        }
        val requests = mutableListOf<String>()
        val client = ContentApi.defaultClient(MockEngine { request ->
            requests += "${request.url.encodedPath}:${request.headers["X-Device-ID"]}"
            val body = when (request.url.encodedPath) {
                "/transfer/apply" -> {
                    val json = (request.body as OutgoingContent.ByteArrayContent).bytes().decodeToString()
                    assertTrue(json.contains("\"token\":\"${"a".repeat(64)}\""))
                    """{"identity_id":"source-device"}"""
                }
                else -> """{"totalAnswered":3,"totalCorrect":2,"weeklyAnswered":1,"weeklyCorrect":1}"""
            }
            respond(body, HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, ContentType.Application.Json.toString()))
        })
        val identity = CognitoDeviceIdentityProvider(CognitoIdentityApi("pool", client), store)
        val repository = LearningRepository(
            api = ContentApi("https://content.example", "https://api.example", client),
            answerApi = AnswerApi("https://api.example", client),
            userApi = UserApi("https://api.example", client),
            identityProvider = identity,
            session = signedOutSession(),
            submissionGate = SubmissionGate(),
            slug = "high-school-chemistry",
            transferApi = TransferApi("https://api.example", client),
        )

        repository.applyTransferToken("a".repeat(64))
        repository.fetchSummary()

        assertEquals("source-device", store.value)
        assertEquals(listOf("/transfer/apply:old-device", "/users/me/summary:source-device"), requests)
    }

    @Test fun `引き継ぎコードは64桁の16進数のみ受け付ける`() {
        assertEquals("a".repeat(64), normalizedTransferToken("  ${"A".repeat(64)}  "))
        assertNull(normalizedTransferToken("a".repeat(63)))
        assertNull(normalizedTransferToken("g".repeat(64)))
    }

    @Test fun `引き継ぎ期限は日本時間で表示する`() {
        assertEquals("2029年9月16日 08:35", formatTransferExpiry("2029-09-15T23:35:00Z"))
    }
}
