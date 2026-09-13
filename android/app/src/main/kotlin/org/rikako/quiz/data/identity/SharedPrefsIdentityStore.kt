package org.rikako.quiz.data.identity

import android.content.Context

/**
 * identity ID はアプリ専用領域（他アプリから読めない）の SharedPreferences に置く。
 * iOS の Keychain と同じく、アンインストールするまで同じ匿名ユーザーとして扱われる。
 */
class SharedPrefsIdentityStore(context: Context) : IdentityStore {

    private val prefs = context.applicationContext
        .getSharedPreferences("rikako_identity", Context.MODE_PRIVATE)

    override fun load(): String? = prefs.getString(KEY_IDENTITY_ID, null)

    override fun save(value: String) {
        prefs.edit().putString(KEY_IDENTITY_ID, value).apply()
    }

    override fun clear() {
        prefs.edit().remove(KEY_IDENTITY_ID).apply()
    }

    private companion object {
        const val KEY_IDENTITY_ID = "identity_id"
    }
}
