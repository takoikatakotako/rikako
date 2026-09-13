package org.rikako.quiz

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.rikako.quiz.data.auth.AccountSession
import org.rikako.quiz.data.auth.AuthTokenStore
import org.rikako.quiz.data.auth.AuthTokens
import org.rikako.quiz.data.identity.DeviceIdentityProvider
import org.rikako.quiz.data.remote.AccountApi
import org.rikako.quiz.data.remote.CognitoUserPoolApi
import org.rikako.quiz.data.remote.ContentApi
import org.rikako.quiz.data.repository.AccountRepository

class AccountRepositoryTest {

    private class RotatingIdentityProvider : DeviceIdentityProvider {
        var current = "ap-northeast-1:first"
        var rotations = 0
        override suspend fun identityId(): String = current
        override suspend fun rotate(): String {
            rotations++
            current = "ap-northeast-1:rotated"
            return current
        }
    }

    private class Store(var tokens: AuthTokens?, override var linkPending: Boolean) : AuthTokenStore {
        override fun load(): AuthTokens? = tokens
        override fun save(tokens: AuthTokens) { this.tokens = tokens }
        override fun clear() { tokens = null }
    }

    private val sentDeviceIds = mutableListOf<String?>()

    private fun repository(
        store: Store,
        identityProvider: DeviceIdentityProvider,
        statuses: List<HttpStatusCode>,
    ): AccountRepository {
        var index = 0
        val engine = MockEngine { request ->
            sentDeviceIds += request.headers["X-Device-ID"]
            val status = statuses.getOrElse(index) { statuses.last() }
            index++
            if (status == HttpStatusCode.OK) {
                respond(
                    content = """{"accountId":7,"email":"me@example.com"}""",
                    status = status,
                    headers = headersOf(HttpHeaders.ContentType, ContentType.Application.Json.toString()),
                )
            } else {
                respond(content = """{"code":"CONFLICT","message":"already linked"}""", status = status)
            }
        }
        val client = ContentApi.defaultClient(engine)
        return AccountRepository(
            session = AccountSession(CognitoUserPoolApi("client-id", client), store),
            accountApi = AccountApi("https://api.example", "high-school-chemistry", client),
            identityProvider = identityProvider,
        )
    }

    private fun validTokens() = AuthTokens(
        idToken = "id-token",
        accessToken = "access",
        refreshToken = "refresh",
        expiresAt = System.currentTimeMillis() / 1000 + 3600,
    )

    @Test
    fun `リンクに成功したら pending を下ろす`() = runTest {
        val store = Store(validTokens(), linkPending = true)
        val identity = RotatingIdentityProvider()
        val repository = repository(store, identity, listOf(HttpStatusCode.OK))

        val link = repository.ensureLinked()

        assertEquals(7L, link?.accountId)
        assertEquals(false, store.linkPending)
        assertEquals(0, identity.rotations)
        assertEquals(listOf("ap-northeast-1:first"), sentDeviceIds)
    }

    @Test
    fun `409 なら identity を取り直して再試行する`() = runTest {
        val store = Store(validTokens(), linkPending = true)
        val identity = RotatingIdentityProvider()
        val repository = repository(
            store,
            identity,
            listOf(HttpStatusCode.Conflict, HttpStatusCode.OK),
        )

        val link = repository.ensureLinked()

        assertEquals(7L, link?.accountId)
        assertEquals(1, identity.rotations)
        assertEquals(
            listOf("ap-northeast-1:first", "ap-northeast-1:rotated"),
            sentDeviceIds,
        )
        assertEquals(false, store.linkPending)
    }

    @Test
    fun `pending でなければ何もしない`() = runTest {
        val store = Store(validTokens(), linkPending = false)
        val repository = repository(store, RotatingIdentityProvider(), listOf(HttpStatusCode.OK))

        assertNull(repository.ensureLinked())
        assertEquals(emptyList<String?>(), sentDeviceIds)
    }

    @Test
    fun `未ログインなら何もしない`() = runTest {
        val store = Store(tokens = null, linkPending = true)
        val repository = repository(store, RotatingIdentityProvider(), listOf(HttpStatusCode.OK))

        assertNull(repository.ensureLinked())
        assertEquals(emptyList<String?>(), sentDeviceIds)
    }
}
