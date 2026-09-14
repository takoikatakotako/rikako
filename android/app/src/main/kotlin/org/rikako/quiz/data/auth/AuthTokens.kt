package org.rikako.quiz.data.auth

/** Cognito User Pool のトークン。expiresAt は epoch 秒。 */
data class AuthTokens(
    val idToken: String,
    val accessToken: String,
    val refreshToken: String,
    val expiresAt: Long,
) {
    /**
     * 期限切れ判定。通信と時計ずれを見込んで少し手前で切る（iOS と同じ考え方）。
     */
    fun isExpired(nowSeconds: Long = System.currentTimeMillis() / 1000): Boolean =
        nowSeconds >= expiresAt - LEEWAY_SECONDS

    private companion object {
        const val LEEWAY_SECONDS = 60
    }
}

interface AuthTokenStore {
    fun load(): AuthTokens?
    fun save(tokens: AuthTokens)
    fun clear()

    /** `/account/link` が未完了かどうか。ログイン時に立て、リンク成功で下ろす。 */
    var linkPending: Boolean
}
