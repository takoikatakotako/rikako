package org.rikako.quiz.data.auth

import android.content.Context

/**
 * トークンはアプリ専用領域（他アプリから読めない）の SharedPreferences に置く。
 * iOS の Keychain と同じ位置づけで、アプリ再起動後もログインが続く。
 */
class SharedPrefsAuthTokenStore(context: Context) : AuthTokenStore {

    private val prefs = context.applicationContext
        .getSharedPreferences("rikako_auth", Context.MODE_PRIVATE)

    override fun load(): AuthTokens? {
        val idToken = prefs.getString(KEY_ID_TOKEN, null) ?: return null
        val accessToken = prefs.getString(KEY_ACCESS_TOKEN, null) ?: return null
        val refreshToken = prefs.getString(KEY_REFRESH_TOKEN, null) ?: return null
        return AuthTokens(
            idToken = idToken,
            accessToken = accessToken,
            refreshToken = refreshToken,
            expiresAt = prefs.getLong(KEY_EXPIRES_AT, 0),
        )
    }

    override fun save(tokens: AuthTokens) {
        prefs.edit()
            .putString(KEY_ID_TOKEN, tokens.idToken)
            .putString(KEY_ACCESS_TOKEN, tokens.accessToken)
            .putString(KEY_REFRESH_TOKEN, tokens.refreshToken)
            .putLong(KEY_EXPIRES_AT, tokens.expiresAt)
            .apply()
    }

    override fun clear() {
        prefs.edit()
            .remove(KEY_ID_TOKEN)
            .remove(KEY_ACCESS_TOKEN)
            .remove(KEY_REFRESH_TOKEN)
            .remove(KEY_EXPIRES_AT)
            .apply()
    }

    override var linkPending: Boolean
        // キーが無い状態でトークンがあるなら、pending を持たない頃のビルドから
        // 持ち越した端末（リンク未実行）とみなす。
        get() = prefs.getBoolean(KEY_LINK_PENDING, true)
        set(value) {
            prefs.edit().putBoolean(KEY_LINK_PENDING, value).apply()
        }

    private companion object {
        const val KEY_ID_TOKEN = "id_token"
        const val KEY_ACCESS_TOKEN = "access_token"
        const val KEY_REFRESH_TOKEN = "refresh_token"
        const val KEY_EXPIRES_AT = "expires_at"
        const val KEY_LINK_PENDING = "link_pending"
    }
}
