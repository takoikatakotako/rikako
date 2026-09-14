package org.rikako.quiz

import android.content.Context
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.rikako.quiz.data.auth.AuthTokens
import org.rikako.quiz.data.auth.KeystoreAuthTokenStore

/**
 * Keystore は JVM のユニットテストでは動かないので、ここで確認する。
 * 端末では `./gradlew :app:connectedChemistryDevDebugAndroidTest` で実行する。
 */
@RunWith(AndroidJUnit4::class)
class KeystoreAuthTokenStoreTest {

    private val context: Context = InstrumentationRegistry.getInstrumentation().targetContext
    private val store = KeystoreAuthTokenStore(context)

    private val tokens = AuthTokens(
        idToken = "id-token-value",
        accessToken = "access-token-value",
        refreshToken = "refresh-token-value",
        expiresAt = 1_800_000_000,
    )

    @Before
    fun setUp() {
        store.clear()
    }

    @After
    fun tearDown() {
        store.clear()
    }

    @Test
    fun 保存したトークンを読み戻せる() {
        store.save(tokens)

        assertEquals(tokens, store.load())
    }

    @Test
    fun 保存領域にトークンが平文で残らない() {
        store.save(tokens)

        val raw = context.getSharedPreferences("rikako_auth", Context.MODE_PRIVATE).all
        val dumped = raw.values.joinToString(",")
        assertFalse("refresh token が平文", dumped.contains("refresh-token-value"))
        assertFalse("id token が平文", dumped.contains("id-token-value"))
        assertTrue("暗号文が保存されていない", dumped.isNotEmpty())
    }

    @Test
    fun clearすると読み出せない() {
        store.save(tokens)
        store.clear()

        assertNull(store.load())
    }

    @Test
    fun 壊れた値は未ログインとして扱う() {
        store.save(tokens)
        // 何らかの理由で復号できなくなった状態を作る。
        context.getSharedPreferences("rikako_auth", Context.MODE_PRIVATE).edit()
            .putString("refresh_token", "broken")
            .commit()

        assertNull(store.load())
    }

    @Test
    fun linkPendingは別の保存領域に置く() {
        store.linkPending = false
        store.save(tokens)

        val tokenPrefs = context.getSharedPreferences("rikako_auth", Context.MODE_PRIVATE)
        assertFalse(tokenPrefs.contains("link_pending"))
        assertFalse(store.linkPending)
    }
}
