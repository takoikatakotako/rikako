package org.rikako.quiz.data.identity

import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.rikako.quiz.data.remote.CognitoIdentityApi

/**
 * 匿名ユーザーの識別子（Cognito Identity ID）を払い出して保持する。
 * サーバーへは X-Device-ID ヘッダーで送る。iOS の CognitoDeviceIdentityProvider と同じ扱い。
 */
interface DeviceIdentityProvider {
    suspend fun identityId(): String

    /**
     * 新しい匿名 identity を取り直す。GetId は logins 無しで呼ぶと毎回新しい identity を
     * 払い出すので、保存済みの値を捨てて取り直すだけでローテーションになる。
     */
    suspend fun rotate(): String
}

class CognitoDeviceIdentityProvider(
    private val api: CognitoIdentityApi,
    private val store: IdentityStore,
) : DeviceIdentityProvider {

    private val mutex = Mutex()

    @Volatile
    private var cached: String? = null

    override suspend fun identityId(): String {
        cached?.let { return it }
        return mutex.withLock {
            // ロック待ちの間に別のコルーチンが取得済みかもしれないので、もう一度見る。
            cached ?: (store.load() ?: api.getId().also { store.save(it) }).also { cached = it }
        }
    }

    override suspend fun rotate(): String = mutex.withLock {
        api.getId().also {
            store.save(it)
            cached = it
        }
    }
}

interface IdentityStore {
    fun load(): String?
    fun save(value: String)
    fun clear()
}
