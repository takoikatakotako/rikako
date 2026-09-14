package org.rikako.quiz

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.plugins.ClientRequestException
import io.ktor.client.request.get
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import org.rikako.quiz.data.auth.AccountSession
import org.rikako.quiz.data.auth.AuthTokenStore
import org.rikako.quiz.data.auth.AuthTokens
import org.rikako.quiz.data.auth.AuthorizedCall
import org.rikako.quiz.data.remote.CognitoUserPoolApi
import org.rikako.quiz.data.remote.ContentApi

/**
 * 401 の再試行が「開始時のセッション」に束縛されていることを確認する。
 * 束縛されていないと、通信中にアカウントが切り替わった場合に、
 * 古い操作を新しいアカウントとして再送したり、新しいセッションを終了させたりする。
 */
class AuthorizedCallSessionBindingTest {

    private class Store(var tokens: AuthTokens?) : AuthTokenStore {
        override fun load(): AuthTokens? = tokens
        override fun save(tokens: AuthTokens) { this.tokens = tokens }
        override fun clear() { tokens = null }
        override var linkPending: Boolean = false
    }

    private fun tokens(id: String) = AuthTokens(id, "access", "refresh-$id", System.currentTimeMillis() / 1000 + 3600)

    private var refreshCalls = 0

    private fun session(store: Store): AccountSession {
        val engine = MockEngine {
            refreshCalls++
            respond(
                content = """
                    {"AuthenticationResult":{"IdToken":"refreshed","AccessToken":"a",
                     "RefreshToken":"refresh-b","ExpiresIn":3600}}
                """.trimIndent(),
                status = HttpStatusCode.OK,
            )
        }
        return AccountSession(CognitoUserPoolApi("client-id", ContentApi.defaultClient(engine)), store)
    }

    /** 常に 401 を返すエンドポイント。ClientRequestException を発生させるために使う。 */
    private val unauthorizedClient = ContentApi.defaultClient(
        MockEngine { respond(content = "", status = HttpStatusCode.Unauthorized) },
    )

    private suspend fun callUnauthorized() {
        unauthorizedClient.get("https://api.example/unauthorized")
    }

    @Test
    fun `通信中にアカウントが変わったら再試行しない`() = runTest {
        val store = Store(tokens("account-a"))
        val sut = session(store)
        val authorized = AuthorizedCall(sut)
        var attempts = 0

        val error = assertThrows(ClientRequestException::class.java) {
            kotlinx.coroutines.runBlocking {
                authorized.execute { _ ->
                    attempts++
                    // 1回目の通信中にログアウト → 別アカウントでログインした状況を作る。
                    if (attempts == 1) {
                        sut.signOut()
                        store.tokens = tokens("account-b")
                        sut.signIn("b@example.com", "password")
                    }
                    callUnauthorized()
                }
            }
        }

        assertEquals(HttpStatusCode.Unauthorized, error.response.status)
        // 再送していない（1回だけ）。
        assertEquals(1, attempts)
        // 新しいアカウントのセッションは生きたまま。
        assertTrue(sut.isLoggedIn)
    }

}
