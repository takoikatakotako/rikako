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
        check(prefs.edit().putString(KEY_IDENTITY_ID, value).commit()) {
            "端末の引き継ぎ情報を保存できませんでした"
        }
    }

    override fun clear() {
        check(prefs.edit().remove(KEY_IDENTITY_ID).commit()) {
            "端末の引き継ぎ情報を削除できませんでした"
        }
    }

    private companion object {
        const val KEY_IDENTITY_ID = "identity_id"
    }
}
