package org.rikako.quiz.data.auth

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * トークンを Android Keystore の鍵で暗号化して保存する。
 *
 * refresh token は再利用可能な認証情報なので、平文で置かない。鍵は Keystore の中にあり、
 * 取り出せないため、端末外へ持ち出しても復号できない（iOS の Keychain
 * kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly と同じ位置づけ）。
 * 保存先の prefs は AndroidManifest のバックアップ除外にも入れてある。
 *
 * linkPending は秘密情報ではないので別の prefs に置く（バックアップ対象のままでよい）。
 */
class KeystoreAuthTokenStore(context: Context) : AuthTokenStore {

    private val appContext = context.applicationContext
    private val prefs = appContext.getSharedPreferences(PREFS_TOKENS, Context.MODE_PRIVATE)
    private val statePrefs = appContext.getSharedPreferences(PREFS_STATE, Context.MODE_PRIVATE)

    override fun load(): AuthTokens? {
        val idToken = decrypt(prefs.getString(KEY_ID_TOKEN, null)) ?: return null
        val accessToken = decrypt(prefs.getString(KEY_ACCESS_TOKEN, null)) ?: return null
        val refreshToken = decrypt(prefs.getString(KEY_REFRESH_TOKEN, null)) ?: return null
        return AuthTokens(
            idToken = idToken,
            accessToken = accessToken,
            refreshToken = refreshToken,
            expiresAt = prefs.getLong(KEY_EXPIRES_AT, 0),
        )
    }

    override fun save(tokens: AuthTokens) {
        val idToken = encrypt(tokens.idToken)
        val accessToken = encrypt(tokens.accessToken)
        val refreshToken = encrypt(tokens.refreshToken)
        if (idToken == null || accessToken == null || refreshToken == null) {
            // 暗号化できないなら平文で残すより持たない方がよい（再ログインで回復できる）。
            clear()
            return
        }
        prefs.edit()
            .putString(KEY_ID_TOKEN, idToken)
            .putString(KEY_ACCESS_TOKEN, accessToken)
            .putString(KEY_REFRESH_TOKEN, refreshToken)
            .putLong(KEY_EXPIRES_AT, tokens.expiresAt)
            .apply()
    }

    override fun clear() {
        prefs.edit().clear().apply()
    }

    override var linkPending: Boolean
        // キーが無い状態でトークンがあるなら、pending を持たない頃のビルドから
        // 持ち越した端末（リンク未実行）とみなす。
        get() = statePrefs.getBoolean(KEY_LINK_PENDING, true)
        set(value) {
            statePrefs.edit().putBoolean(KEY_LINK_PENDING, value).apply()
        }

    /** 鍵が失われた・復号できない場合は null。呼び出し側は未ログイン扱いにする。 */
    private fun decrypt(stored: String?): String? = runCatching {
        if (stored == null) return null
        val bytes = Base64.decode(stored, Base64.NO_WRAP)
        val iv = bytes.copyOfRange(0, GCM_IV_LENGTH)
        val body = bytes.copyOfRange(GCM_IV_LENGTH, bytes.size)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, secretKey(), GCMParameterSpec(GCM_TAG_BITS, iv))
        cipher.doFinal(body).decodeToString()
    }.getOrNull()

    private fun encrypt(value: String): String? = runCatching {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, secretKey())
        val body = cipher.doFinal(value.toByteArray())
        Base64.encodeToString(cipher.iv + body, Base64.NO_WRAP)
    }.getOrNull()

    private fun secretKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        (keyStore.getEntry(KEY_ALIAS, null) as? KeyStore.SecretKeyEntry)?.let { return it.secretKey }

        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        generator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .build(),
        )
        return generator.generateKey()
    }

    private companion object {
        const val ANDROID_KEYSTORE = "AndroidKeyStore"
        const val KEY_ALIAS = "rikako_auth_tokens"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val GCM_IV_LENGTH = 12
        const val GCM_TAG_BITS = 128

        const val PREFS_TOKENS = "rikako_auth"
        const val PREFS_STATE = "rikako_auth_state"

        const val KEY_ID_TOKEN = "id_token"
        const val KEY_ACCESS_TOKEN = "access_token"
        const val KEY_REFRESH_TOKEN = "refresh_token"
        const val KEY_EXPIRES_AT = "expires_at"
        const val KEY_LINK_PENDING = "link_pending"
    }
}
