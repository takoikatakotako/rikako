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

/** ある時点のセッションの、世代と有効な ID token の組。 */
data class SessionToken(
    val generation: Long,
    val idToken: String?,
)

/** トークンを端末に保存できなかった。再ログインしても直らないことがある。 */
class TokenPersistenceException(cause: Throwable? = null) :
    Exception("ログイン情報を保存できませんでした。", cause)

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
    /** signIn / signOut / refresh の状態遷移を直列化する。 */
    private val mutex = Mutex()

    /**
     * セッションの世代。ログイン・ログアウトのたびに進める。ネットワーク呼び出しの
     * 前後で変わっていたら、その結果は古いセッションのものなので捨てる。
     */
    @Volatile
    private var generation = 0L

    @Volatile
    private var tokens: AuthTokens? = store.load()

    private val _state = MutableStateFlow(
        AccountState(isLoggedIn = tokens != null, email = tokens?.let { emailFrom(it.idToken) }),
    )
    val state: StateFlow<AccountState> = _state.asStateFlow()

    val isLoggedIn: Boolean get() = tokens != null

    /**
     * 現在のセッションの世代。ログイン・ログアウトのたびに変わる。
     * 通信を挟む操作は、開始時の世代を持っておいて同じセッションのときだけ続行する。
     */
    val sessionGeneration: Long get() = generation

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
        val startedAt = mutex.withLock { generation }
        val newTokens = api.signIn(email, password)
        mutex.withLock {
            // 通信中にログアウト・別のログインが起きていたら、この結果は捨てる。
            if (generation != startedAt) return
            // 2つの保存をトランザクションにはできないので、順序で安全側に倒す。
            // 先に pending を立てておけば、トークン保存前に落ちても未ログインのままで害がない。
            // 逆順だと「ログイン済みだが pending=false」になり、リンク漏れが永久に残る。
            store.linkPending = true
            generation++
            apply(newTokens)
        }
    }

    suspend fun signOut() {
        val refreshToken = mutex.withLock {
            val token = tokens?.refreshToken
            generation++
            clear()
            token
        }
        // 失効させられなくてもローカルのログアウトは済ませる。
        if (refreshToken != null) runCatching { api.revokeToken(refreshToken) }
    }

    /**
     * サーバーに 401 を返され続けたときなど、ローカルのセッションだけ終了する。
     * [expectedGeneration] を渡すと、そのセッションがまだ続いているときだけ終了する
     * （古いリクエストの後始末で、別アカウントのログインを巻き込まないため）。
     */
    suspend fun endSession(expectedGeneration: Long? = null) {
        mutex.withLock {
            if (expectedGeneration != null && expectedGeneration != generation) return
            generation++
            clear()
        }
    }

    /**
     * 世代と ID token を**同じロックの中で**取り出す。別々に読むと、その間にセッションが
     * 変わって「世代は A、token は B」のような組を作ってしまう。
     */
    suspend fun currentToken(): SessionToken = mutex.withLock {
        val current = tokens ?: return@withLock SessionToken(generation, null)
        if (!current.isExpired()) return@withLock SessionToken(generation, current.idToken)
        SessionToken(generation, refreshUnderLock(current.refreshToken))
    }

    /**
     * API 呼び出し用の有効な ID token。期限が近ければ refresh する。
     *
     * nil 相当（null）を返すのは「呼び出し時点で未ログイン」のときだけ。refresh の失敗は
     * terminal（refresh token が失効・無効）と transient（オフライン等）を区別し、
     * どちらも throw する。terminal でもローカルを消したうえで throw するのが要点で、
     * null を返すと期限切れを検知したその1回の書き込みだけが匿名側へ流れてしまう。
     */
    suspend fun validIdToken(): String? = currentToken().idToken

    /**
     * 期限内でもサーバーが 401 を返すことがあるので、その再試行用に期限を見ずに refresh する。
     *
     * [expectedGeneration] を渡すと、開始時と同じセッションのときだけ refresh する。
     * これが無いと、通信中にログアウト → 別アカウントでログインした場合に、
     * 古いリクエストの 401 で新しいアカウントのトークンを更新してしまう。
     */
    suspend fun forceRefresh(expectedGeneration: Long? = null): String? {
        if (expectedGeneration != null && expectedGeneration != generation) return null
        val current = tokens ?: return null
        return refreshLocked(current.refreshToken, expectedGeneration)
    }

    private suspend fun refreshLocked(
        refreshToken: String,
        expectedGeneration: Long? = null,
    ): String? = mutex.withLock {
        // ロック待ちの間にログアウトされたか、他のコルーチンが更新済みかもしれない。
        if (expectedGeneration != null && expectedGeneration != generation) return@withLock null
        refreshUnderLock(refreshToken)
    }

    /** mutex を保持した状態で呼ぶこと。 */
    private suspend fun refreshUnderLock(refreshToken: String): String? {
        val current = tokens ?: return null
        if (current.refreshToken != refreshToken) return current.idToken

        try {
            val refreshed = api.refresh(refreshToken)
            apply(refreshed)
            return refreshed.idToken
        } catch (e: CognitoException) {
            if (e.code in CognitoException.TERMINAL_CODES) {
                // ローカルのセッションは終了するが、この1回のリクエストは匿名で流さず失敗させる。
                generation++
                clear()
                throw SessionExpiredException()
            }
            // transient は呼び出し側へ伝える（匿名にフォールバックさせない）。
            throw e
        }
    }

    /**
     * 保存に失敗したらインメモリも更新しない。保存できていないのにログイン済みにすると、
     * その場は動くのに再起動で突然ログアウトする状態になる。
     */
    private fun apply(newTokens: AuthTokens) {
        try {
            store.save(newTokens)
        } catch (e: Throwable) {
            throw TokenPersistenceException(e)
        }
        tokens = newTokens
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
