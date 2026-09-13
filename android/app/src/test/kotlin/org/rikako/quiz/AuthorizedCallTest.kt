package org.rikako.quiz

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Test
import org.rikako.quiz.data.auth.AccountSession
import org.rikako.quiz.data.auth.AuthTokenStore
import org.rikako.quiz.data.auth.AuthTokens
import org.rikako.quiz.data.auth.SessionExpiredException
import org.rikako.quiz.data.auth.SubmissionGate
import org.rikako.quiz.data.remote.AnswerApi
import org.rikako.quiz.data.remote.CognitoUserPoolApi
import org.rikako.quiz.data.remote.ContentApi
import org.rikako.quiz.data.remote.UserApi
import org.rikako.quiz.data.repository.LearningRepository

class AuthorizedCallTest {

    private class Store(var tokens: AuthTokens?) : AuthTokenStore {
        override fun load(): AuthTokens? = tokens
        override fun save(tokens: AuthTokens) { this.tokens = tokens }
        override fun clear() { tokens = null }
        override var linkPending: Boolean = false
    }

    private val authHeaders = mutableListOf<String?>()

    private fun validTokens(idToken: String = "id-token") = AuthTokens(
        idToken = idToken,
        accessToken = "access",
        refreshToken = "refresh",
        expiresAt = System.currentTimeMillis() / 1000 + 3600,
    )

    /** summary は [summaryStatuses] の順に応答する。cognito-idp への refresh は常に成功。 */
    private fun repository(store: Store, summaryStatuses: List<HttpStatusCode>): LearningRepository {
        var index = 0
        val engine = MockEngine { request ->
            when {
                request.url.host.startsWith("cognito-idp") -> respond(
                    content = """
                        {"AuthenticationResult":{"IdToken":"refreshed-token","AccessToken":"a","ExpiresIn":3600}}
                    """.trimIndent(),
                    status = HttpStatusCode.OK,
                )

                else -> {
                    authHeaders += request.headers[HttpHeaders.Authorization]
                    val status = summaryStatuses.getOrElse(index) { summaryStatuses.last() }
                    index++
                    if (status == HttpStatusCode.OK) {
                        respond(
                            content = """{"totalAnswered":1,"totalCorrect":1,"weeklyAnswered":1,
                                "weeklyCorrect":1,"studyDates":[],"weeklyWorkbookIds":[]}""",
                            status = status,
                            headers = headersOf(
                                HttpHeaders.ContentType,
                                ContentType.Application.Json.toString(),
                            ),
                        )
                    } else {
                        respond(content = """{"message":"unauthorized"}""", status = status)
                    }
                }
            }
        }
        val client = ContentApi.defaultClient(engine)
        return LearningRepository(
            api = ContentApi("https://content.example/v1", "https://api.example", client),
            answerApi = AnswerApi("https://api.example", client),
            userApi = UserApi("https://api.example", client),
            identityProvider = FakeDeviceIdentityProvider("ap-northeast-1:device"),
            session = AccountSession(CognitoUserPoolApi("client-id", client), store),
            submissionGate = SubmissionGate(),
            slug = "high-school-chemistry",
        )
    }

    @Test
    fun `401 なら refresh して新しい ID token で1回だけ再送する`() = runTest {
        val store = Store(validTokens())
        val repository = repository(store, listOf(HttpStatusCode.Unauthorized, HttpStatusCode.OK))

        val summary = repository.fetchSummary()

        assertEquals(1, summary.totalAnswered)
        assertEquals(
            listOf("Bearer id-token", "Bearer refreshed-token"),
            authHeaders,
        )
    }

    @Test
    fun `再送しても 401 ならセッションを終了する`() = runTest {
        val store = Store(validTokens())
        val repository = repository(
            store,
            listOf(HttpStatusCode.Unauthorized, HttpStatusCode.Unauthorized),
        )

        assertThrows(SessionExpiredException::class.java) {
            kotlinx.coroutines.runBlocking { repository.fetchSummary() }
        }
        // ローカルのセッションは終了し、次回以降は匿名として動く。
        assertFalse(store.tokens != null)
        assertEquals(2, authHeaders.size)
    }

    @Test
    fun `未ログインなら 401 でも refresh しない`() = runTest {
        val store = Store(tokens = null)
        val repository = repository(store, listOf(HttpStatusCode.Unauthorized))

        assertThrows(io.ktor.client.plugins.ClientRequestException::class.java) {
            kotlinx.coroutines.runBlocking { repository.fetchSummary() }
        }
        assertEquals(listOf<String?>(null), authHeaders)
    }
}
