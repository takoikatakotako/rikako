package org.rikako.quiz

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.rikako.quiz.data.auth.AccountSession
import org.rikako.quiz.data.auth.AuthTokenStore
import org.rikako.quiz.data.auth.AuthTokens
import org.rikako.quiz.data.auth.SubmissionGate
import org.rikako.quiz.data.remote.AccountApi
import org.rikako.quiz.data.remote.CognitoUserPoolApi
import org.rikako.quiz.data.remote.ContentApi
import org.rikako.quiz.data.repository.AccountRepository
import org.rikako.quiz.data.repository.LinkState

/**
 * link の通信中にアカウントが切り替わった場合、その結果で新しいセッションの
 * pending を下げないこと。LinkState も Linking のまま残さないこと。
 */
class EnsureLinkedSessionSwitchTest {

    private class Store(var tokens: AuthTokens?, override var linkPending: Boolean) : AuthTokenStore {
        override fun load(): AuthTokens? = tokens
        override fun save(tokens: AuthTokens) { this.tokens = tokens }
        override fun clear() { tokens = null }
    }

    private fun validTokens(id: String) =
        AuthTokens(id, "access", "refresh", System.currentTimeMillis() / 1000 + 3600)

    @Test
    fun `link 中にアカウントが変わったら新しいセッションの pending は下げない`() = runBlocking {
        val store = Store(validTokens("account-a"), linkPending = true)
        lateinit var session: AccountSession

        val engine = MockEngine { request ->
            if (request.url.encodedPath == "/account/link") {
                // 応答を返す前に、ログアウト → 別アカウントでログインした状況を作る。
                session.signOut()
                store.linkPending = true
                session.signIn("b@example.com", "password")
                respond(
                    content = """{"accountId":7,"email":"a@example.com"}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, ContentType.Application.Json.toString()),
                )
            } else {
                // signIn / revoke 用。
                respond(
                    content = """
                        {"AuthenticationResult":{"IdToken":"account-b","AccessToken":"a",
                         "RefreshToken":"refresh-b","ExpiresIn":3600}}
                    """.trimIndent(),
                    status = HttpStatusCode.OK,
                )
            }
        }
        val client = ContentApi.defaultClient(engine)
        session = AccountSession(CognitoUserPoolApi("client-id", client), store)
        val repository = AccountRepository(
            session = session,
            accountApi = AccountApi("https://api.example", "high-school-chemistry", client),
            identityProvider = FakeDeviceIdentityProvider("ap-northeast-1:device"),
            submissionGate = SubmissionGate(),
        )

        val link = repository.ensureLinked()

        // 旧セッションの結果なので、新しいセッションには適用しない。
        assertNull(link)
        assertTrue("新しいセッションの pending を下げてはいけない", store.linkPending)
        // Linking のまま残さない。
        assertEquals(LinkState.Idle, repository.linkState.value)
    }
}
