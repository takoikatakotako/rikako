package org.rikako.quiz.data.auth

import kotlin.io.encoding.Base64
import kotlin.io.encoding.ExperimentalEncodingApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.rikako.quiz.data.remote.CognitoException
import org.rikako.quiz.data.remote.CognitoUserPoolApi
import org.rikako.quiz.data.remote.ContentApi

/** ログインの有効期限が切れ、再ログインが必要な状態。 */
class SessionExpiredException : Exception("ログインの有効期限が切れました。もう一度ログインしてください。")

data class AccountState(
    val isLoggedIn: Boolean = false,
    /** 表示用。ID token の email クレームから取る。 */
    val email: String? = null,
)

/**
 * メールアドレスでのログイン状態を持つ。トークンは端末に永続化するので、
 * アプリ再起動後もログインが続く。未ログインのときは従来どおり匿名（X-Device-ID）で動く。
 */
class AccountSession(
    private val api: CognitoUserPoolApi,
    private val store: AuthTokenStore,
) {
    private val mutex = Mutex()

    @Volatile
    private var tokens: AuthTokens? = store.load()

    private val _state = MutableStateFlow(
        AccountState(isLoggedIn = tokens != null, email = tokens?.let { emailFrom(it.idToken) }),
    )
    val state: StateFlow<AccountState> = _state.asStateFlow()

    val isLoggedIn: Boolean get() = tokens != null

    var linkPending: Boolean
        get() = store.linkPending
        set(value) {
            store.linkPending = value
        }

    suspend fun signUp(email: String, password: String) = api.signUp(email, password)

    suspend fun confirmSignUp(email: String, code: String) = api.confirmSignUp(email, code)

    suspend fun resendConfirmationCode(email: String) = api.resendConfirmationCode(email)

    suspend fun forgotPassword(email: String) = api.forgotPassword(email)

    suspend fun confirmForgotPassword(email: String, code: String, newPassword: String) =
        api.confirmForgotPassword(email, code, newPassword)

    suspend fun signIn(email: String, password: String) {
        val newTokens = api.signIn(email, password)
        // 2つの保存をトランザクションにはできないので、順序で安全側に倒す。
        // 先に pending を立てておけば、トークン保存前に落ちても未ログインのままで害がない。
        // 逆順だと「ログイン済みだが pending=false」になり、リンク漏れが永久に残る。
        store.linkPending = true
        apply(newTokens)
    }

    suspend fun signOut() {
        val refreshToken = tokens?.refreshToken
        clear()
        // 失効させられなくてもローカルのログアウトは済ませる。
        if (refreshToken != null) runCatching { api.revokeToken(refreshToken) }
    }

    /**
     * API 呼び出し用の有効な ID token。期限が近ければ refresh する。
     *
     * nil 相当（null）を返すのは「呼び出し時点で未ログイン」のときだけ。refresh の失敗は
     * terminal（refresh token が失効・無効）と transient（オフライン等）を区別し、
     * どちらも throw する。terminal でもローカルを消したうえで throw するのが要点で、
     * null を返すと期限切れを検知したその1回の書き込みだけが匿名側へ流れてしまう。
     */
    suspend fun validIdToken(): String? {
        val current = tokens ?: return null
        if (!current.isExpired()) return current.idToken
        return refreshLocked(current.refreshToken)
    }

    /** 期限内でもサーバーが 401 を返すことがあるので、その再試行用に期限を見ずに refresh する。 */
    suspend fun forceRefresh(): String? {
        val current = tokens ?: return null
        return refreshLocked(current.refreshToken)
    }

    private suspend fun refreshLocked(refreshToken: String): String? = mutex.withLock {
        // ロック待ちの間に他のコルーチンが更新済みかもしれない。
        tokens?.let { if (!it.isExpired() && it.refreshToken != refreshToken) return it.idToken }

        try {
            val refreshed = api.refresh(refreshToken)
            apply(refreshed)
            refreshed.idToken
        } catch (e: CognitoException) {
            if (e.code in CognitoException.TERMINAL_CODES) {
                // ローカルのセッションは終了するが、この1回のリクエストは匿名で流さず失敗させる。
                clear()
                throw SessionExpiredException()
            }
            // transient は呼び出し側へ伝える（匿名にフォールバックさせない）。
            throw e
        }
    }

    private fun apply(newTokens: AuthTokens) {
        tokens = newTokens
        store.save(newTokens)
        _state.value = AccountState(isLoggedIn = true, email = emailFrom(newTokens.idToken))
    }

    private fun clear() {
        tokens = null
        store.clear()
        store.linkPending = false
        _state.value = AccountState(isLoggedIn = false, email = null)
    }

    /** ID token は検証せず、表示用に email クレームだけ取り出す（検証はサーバーの責務）。 */
    @OptIn(ExperimentalEncodingApi::class)
    private fun emailFrom(idToken: String): String? = runCatching {
        val payload = idToken.split('.').getOrNull(1) ?: return null
        val decoded = Base64.UrlSafe.withPadding(Base64.PaddingOption.ABSENT_OPTIONAL)
            .decode(payload)
        ContentApi.json.parseToJsonElement(decoded.decodeToString())
            .jsonObject["email"]?.jsonPrimitive?.content
    }.getOrNull()
}
