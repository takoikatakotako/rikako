package org.rikako.quiz

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import org.rikako.quiz.data.auth.AccountSession
import org.rikako.quiz.data.auth.AuthTokens
import org.rikako.quiz.data.auth.AuthTokenStore
import org.rikako.quiz.data.auth.TokenPersistenceException
import org.rikako.quiz.data.remote.CognitoException
import org.rikako.quiz.data.remote.CognitoUserPoolApi
import org.rikako.quiz.data.remote.ContentApi
import java.util.concurrent.atomic.AtomicInteger

class AccountSessionTest {

    private class InMemoryStore(var tokens: AuthTokens? = null) : AuthTokenStore {
        override fun load(): AuthTokens? = tokens
        override fun save(tokens: AuthTokens) { this.tokens = tokens }
        override fun clear() { tokens = null }
        override var linkPending: Boolean = false
    }

    private val calls = AtomicInteger()

    /** ヘッダの email クレームだけ使うので、署名は空のダミーでよい。 */
    private fun idToken(email: String): String {
        val payload = """{"email":"$email"}"""
        val encoded = java.util.Base64.getUrlEncoder().withoutPadding()
            .encodeToString(payload.toByteArray())
        return "header.$encoded.signature"
    }

    private fun session(
        store: AuthTokenStore,
        responder: (Int) -> Pair<HttpStatusCode, String>,
    ): AccountSession {
        val engine = MockEngine {
            val (status, body) = responder(calls.getAndIncrement())
            respond(content = body, status = status)
        }
        return AccountSession(
            api = CognitoUserPoolApi("client-id", ContentApi.defaultClient(engine)),
            store = store,
        )
    }

    @Test
    fun `ログインするとトークンを保存しリンク待ちを立てる`() = runTest {
        val store = InMemoryStore()
        val sut = session(store) { _ ->
            HttpStatusCode.OK to """
                {"AuthenticationResult":{"IdToken":"${idToken("me@example.com")}",
                "AccessToken":"access","RefreshToken":"refresh","ExpiresIn":3600}}
            """.trimIndent()
        }

        sut.signIn("me@example.com", "password")

        assertTrue(sut.isLoggedIn)
        assertTrue(store.linkPending)
        assertEquals("me@example.com", sut.state.value.email)
        assertEquals("refresh", store.tokens?.refreshToken)
    }

    @Test
    fun `期限切れなら refresh して新しい ID token を返す`() = runTest {
        val expired = AuthTokens("old", "access", "refresh", expiresAt = 0)
        val store = InMemoryStore(expired)
        val newIdToken = idToken("me@example.com")
        val sut = session(store) { _ ->
            // REFRESH_TOKEN_AUTH のレスポンスには RefreshToken が含まれない。
            HttpStatusCode.OK to """
                {"AuthenticationResult":{"IdToken":"$newIdToken","AccessToken":"a","ExpiresIn":3600}}
            """.trimIndent()
        }

        assertEquals(newIdToken, sut.validIdToken())
        // 既存の refresh token が引き継がれる。
        assertEquals("refresh", store.tokens?.refreshToken)
    }

    @Test
    fun `refresh token が失効したらセッションを消して SessionExpired を投げる`() = runTest {
        val store = InMemoryStore(AuthTokens("old", "access", "refresh", expiresAt = 0))
        val sut = session(store) { _ ->
            HttpStatusCode.BadRequest to
                """{"__type":"com.amazon#NotAuthorizedException","message":"Refresh Token has expired"}"""
        }

        assertThrows(org.rikako.quiz.data.auth.SessionExpiredException::class.java) {
            kotlinx.coroutines.runBlocking { sut.validIdToken() }
        }
        assertFalse(sut.isLoggedIn)
        assertNull(store.tokens)
    }

    @Test
    fun `一時的なエラーではセッションを消さずそのまま投げる`() = runTest {
        val store = InMemoryStore(AuthTokens("old", "access", "refresh", expiresAt = 0))
        val sut = session(store) { _ ->
            HttpStatusCode.ServiceUnavailable to
                """{"__type":"com.amazon#TooManyRequestsException","message":"slow down"}"""
        }

        val error = assertThrows(CognitoException::class.java) {
            kotlinx.coroutines.runBlocking { sut.validIdToken() }
        }
        assertEquals("TooManyRequestsException", error.code)
        // 匿名にフォールバックさせないため、ログイン状態は維持する。
        assertTrue(sut.isLoggedIn)
        assertEquals("refresh", store.tokens?.refreshToken)
    }

    @Test
    fun `未ログインなら ID token は null`() = runTest {
        val sut = session(InMemoryStore()) { _ -> HttpStatusCode.OK to "{}" }
        assertNull(sut.validIdToken())
    }

    @Test
    fun `refresh の最中にログアウトしてもセッションは復活しない`() = runTest {
        val store = InMemoryStore(AuthTokens("old", "access", "refresh", expiresAt = 0))
        val release = CompletableDeferred<Unit>()
        val refreshStarted = CompletableDeferred<Unit>()
        val engine = MockEngine {
            refreshStarted.complete(Unit)
            release.await()
            respond(
                content = """
                    {"AuthenticationResult":{"IdToken":"${idToken("me@example.com")}",
                    "AccessToken":"a","ExpiresIn":3600}}
                """.trimIndent(),
                status = HttpStatusCode.OK,
            )
        }
        val sut = AccountSession(
            api = CognitoUserPoolApi("client-id", ContentApi.defaultClient(engine)),
            store = store,
        )

        val refresh = async { runCatching { sut.validIdToken() } }
        refreshStarted.await()

        // refresh が通信中にログアウトする。
        val signOut = async { sut.signOut() }
        release.complete(Unit)
        refresh.await()
        signOut.await()

        assertFalse(sut.isLoggedIn)
        assertNull(store.tokens)
    }

    @Test
    fun `トークンを保存できなければログイン済みにしない`() = runTest {
        // 保存に失敗する（Keystore の鍵が使えない）状況。
        val failing = object : AuthTokenStore {
            override fun load(): AuthTokens? = null
            override fun save(tokens: AuthTokens) = throw IllegalStateException("暗号化できない")
            override fun clear() = Unit
            override var linkPending: Boolean = false
        }
        val sut = session(failing) { _ ->
            HttpStatusCode.OK to """
                {"AuthenticationResult":{"IdToken":"${idToken("me@example.com")}",
                "AccessToken":"access","RefreshToken":"refresh","ExpiresIn":3600}}
            """.trimIndent()
        }

        assertThrows(TokenPersistenceException::class.java) {
            kotlinx.coroutines.runBlocking { sut.signIn("me@example.com", "password") }
        }
        // 保存できていないのにログイン済みにすると、再起動で突然ログアウトする。
        assertFalse(sut.isLoggedIn)
        assertFalse(sut.state.value.isLoggedIn)
    }

    @Test
    fun `世代と ID token は同じスナップショットで返る`() = runTest {
        val store = InMemoryStore(AuthTokens("current", "access", "refresh", expiresAt = Long.MAX_VALUE))
        val sut = session(store) { _ -> HttpStatusCode.OK to "{}" }

        val snapshot = sut.currentToken()

        assertEquals(sut.sessionGeneration, snapshot.generation)
        assertEquals("current", snapshot.idToken)
    }

    @Test
    fun `UserNotConfirmed は terminal として扱う`() {
        // iOS の AccountSession.isTerminal と同じ集合。
        assertEquals(
            setOf("NotAuthorizedException", "UserNotFoundException", "UserNotConfirmedException"),
            CognitoException.TERMINAL_CODES,
        )
    }

    @Test
    fun `エラーコードは日本語メッセージに寄せる`() {
        assertEquals(
            "メールアドレスまたはパスワードが正しくありません。",
            CognitoException("NotAuthorizedException", "Incorrect username or password.").message,
        )
        assertEquals(
            "このメールアドレスは既に登録されています。",
            CognitoException("UsernameExistsException", "").message,
        )
        // 未知のコードはサーバーのメッセージをそのまま出す。
        assertEquals("なにか", CognitoException("SomethingElse", "なにか").message)
    }
}
