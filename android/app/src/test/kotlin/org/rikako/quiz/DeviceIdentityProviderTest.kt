package org.rikako.quiz

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test
import org.rikako.quiz.data.identity.CognitoDeviceIdentityProvider
import org.rikako.quiz.data.identity.IdentityStore
import org.rikako.quiz.data.remote.CognitoIdentityApi
import org.rikako.quiz.data.remote.ContentApi

class DeviceIdentityProviderTest {

    private class InMemoryStore(var value: String? = null) : IdentityStore {
        override fun load(): String? = value
        override fun save(value: String) { this.value = value }
        override fun clear() { value = null }
    }

    private fun provider(store: IdentityStore, ids: List<String>): Pair<CognitoDeviceIdentityProvider, () -> Int> {
        var calls = 0
        val engine = MockEngine {
            val id = ids[calls.coerceAtMost(ids.lastIndex)]
            calls++
            respond(content = """{"IdentityId":"$id"}""", status = HttpStatusCode.OK)
        }
        val api = CognitoIdentityApi(
            identityPoolId = "ap-northeast-1:pool",
            client = ContentApi.defaultClient(engine),
        )
        return CognitoDeviceIdentityProvider(api, store) to { calls }
    }

    @Test
    fun `払い出した identity は保存され二度目は GetId を呼ばない`() = runTest {
        val store = InMemoryStore()
        val (sut, calls) = provider(store, listOf("ap-northeast-1:first"))

        assertEquals("ap-northeast-1:first", sut.identityId())
        assertEquals("ap-northeast-1:first", sut.identityId())

        assertEquals("ap-northeast-1:first", store.value)
        assertEquals(1, calls())
    }

    @Test
    fun `保存済みの identity があれば GetId を呼ばない`() = runTest {
        val store = InMemoryStore("ap-northeast-1:saved")
        val (sut, calls) = provider(store, listOf("ap-northeast-1:new"))

        assertEquals("ap-northeast-1:saved", sut.identityId())
        assertEquals(0, calls())
    }

    @Test
    fun `rotate すると新しい identity を取り直して保存する`() = runTest {
        val store = InMemoryStore("ap-northeast-1:old")
        val (sut, _) = provider(store, listOf("ap-northeast-1:rotated"))

        assertEquals("ap-northeast-1:rotated", sut.rotate())
        assertEquals("ap-northeast-1:rotated", store.value)
        assertEquals("ap-northeast-1:rotated", sut.identityId())
    }
}
