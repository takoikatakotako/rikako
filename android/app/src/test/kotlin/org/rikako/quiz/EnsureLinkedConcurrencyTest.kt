package org.rikako.quiz

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
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
import java.util.concurrent.atomic.AtomicInteger

/**
 * 起動時とログイン直後の ensureLinked が並行しても、pending と linkState が
 * 矛盾した組み合わせ（pending=false かつ Failed で再試行もできない）にならないことを見る。
 */
class EnsureLinkedConcurrencyTest {

    private class Store(var tokens: AuthTokens?, override var linkPending: Boolean) : AuthTokenStore {
        override fun load(): AuthTokens? = tokens
        override fun save(tokens: AuthTokens) { this.tokens = tokens }
        override fun clear() { tokens = null }
    }

    private val linkCalls = AtomicInteger()

    private fun validTokens() = AuthTokens(
        idToken = "id-token",
        accessToken = "access",
        refreshToken = "refresh",
        expiresAt = System.currentTimeMillis() / 1000 + 3600,
    )

    /** link は1回目 200、2回目以降 500 を返す。2本走ったら分かるようにするため。 */
    private fun repository(store: Store): AccountRepository {
        val engine = MockEngine {
            val first = linkCalls.getAndIncrement() == 0
            if (first) {
                respond(
                    content = """{"accountId":7,"email":"me@example.com"}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, ContentType.Application.Json.toString()),
                )
            } else {
                respond(content = """{"message":"boom"}""", status = HttpStatusCode.InternalServerError)
            }
        }
        val client = ContentApi.defaultClient(engine)
        return AccountRepository(
            session = AccountSession(CognitoUserPoolApi("client-id", client), store),
            accountApi = AccountApi("https://api.example", "high-school-chemistry", client),
            identityProvider = FakeDeviceIdentityProvider("ap-northeast-1:device"),
            submissionGate = SubmissionGate(),
        )
    }

    @Test
    fun `並行して呼んでも link は1回だけで状態が壊れない`() = runBlocking {
        val store = Store(validTokens(), linkPending = true)
        val repository = repository(store)

        val first = async { runCatching { repository.ensureLinked() } }
        val second = async { runCatching { repository.ensureLinked() } }
        val results = listOf(first.await(), second.await())

        // 1本目が済ませたので、2本目は何もしない。
        assertEquals(1, linkCalls.get())
        assertTrue("どちらも例外なく終わる", results.all { it.isSuccess })
        assertEquals(7L, results.mapNotNull { it.getOrNull() }.single().accountId)
        assertFalse(store.linkPending)
        assertEquals(LinkState.Idle, repository.linkState.value)
    }

    @Test
    fun `失敗したときは pending を残して再試行できる`() = runBlocking {
        val store = Store(validTokens(), linkPending = true)
        // 1回目から失敗させたいので、あらかじめ1回消費しておく。
        linkCalls.incrementAndGet()
        val repository = repository(store)

        val result = runCatching { repository.ensureLinked() }

        assertTrue(result.isFailure)
        assertEquals(LinkState.Failed, repository.linkState.value)
        assertTrue("再試行できるよう pending は残す", store.linkPending)
    }
}
