package org.rikako.quiz.data.remote

import io.ktor.client.HttpClient
import io.ktor.client.plugins.ResponseException
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.HttpResponse
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.contentType
import io.ktor.http.isSuccess
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlinx.serialization.json.putJsonObject
import org.rikako.quiz.data.auth.AuthTokens

/** cognito-idp が返すエラー。`__type` の `#` 以降がエラーコード。 */
class CognitoException(val code: String, val rawMessage: String) : Exception(
    japaneseMessage(code, rawMessage),
) {
    companion object {
        /**
         * エラーコードを日本語メッセージに寄せる。iOS の CognitoError と
         * portal/src/lib/cognito.ts に合わせてある。
         * prevent_user_existence_errors=ENABLED のため「ユーザー不存在」は出さない。
         */
        fun japaneseMessage(code: String, fallback: String): String = when (code) {
            "UsernameExistsException" -> "このメールアドレスは既に登録されています。"
            "InvalidPasswordException" ->
                "パスワードが要件を満たしていません（8文字以上・大小英字・数字・記号）。"
            "CodeMismatchException" -> "確認コードが正しくありません。"
            "ExpiredCodeException" -> "確認コードの有効期限が切れています。再送してください。"
            "NotAuthorizedException" -> "メールアドレスまたはパスワードが正しくありません。"
            "UserNotConfirmedException" -> "メール確認が完了していません。確認コードを入力してください。"
            "LimitExceededException", "TooManyRequestsException" ->
                "試行回数が多すぎます。しばらくしてから再度お試しください。"
            // 設定不備。ユーザーの操作では直らないので汎用の文言に留める。
            "MissingClientId" -> "アプリの設定に問題があります。"
            else -> fallback.ifEmpty { "エラーが発生しました。" }
        }

        /** refresh token が無効で、再ログイン以外に回復手段が無いもの。 */
        val TERMINAL_CODES = setOf(
            "NotAuthorizedException",
            "UserNotFoundException",
            "InvalidParameterException",
        )
    }
}

/**
 * Cognito User Pool の操作。Amplify は使わず cognito-idp を直接叩く
 * （匿名認証の CognitoIdentityApi と同じ流儀）。
 */
class CognitoUserPoolApi(
    private val clientId: String,
    private val client: HttpClient = ContentApi.defaultClient(),
    private val region: String = "ap-northeast-1",
) {
    suspend fun signUp(email: String, password: String) {
        call(
            "SignUp",
            buildJsonObject {
                put("ClientId", clientId)
                put("Username", email)
                put("Password", password)
                putJsonArray("UserAttributes") {
                    add(buildJsonObject { put("Name", "email"); put("Value", email) })
                }
            },
        )
    }

    suspend fun confirmSignUp(email: String, code: String) {
        call(
            "ConfirmSignUp",
            buildJsonObject {
                put("ClientId", clientId)
                put("Username", email)
                put("ConfirmationCode", code)
            },
        )
    }

    suspend fun resendConfirmationCode(email: String) {
        call(
            "ResendConfirmationCode",
            buildJsonObject {
                put("ClientId", clientId)
                put("Username", email)
            },
        )
    }

    /** ログイン（USER_PASSWORD_AUTH）。App Client は generate_secret=false なので SECRET_HASH 不要。 */
    suspend fun signIn(email: String, password: String): AuthTokens {
        val json = call(
            "InitiateAuth",
            buildJsonObject {
                put("AuthFlow", "USER_PASSWORD_AUTH")
                put("ClientId", clientId)
                putJsonObject("AuthParameters") {
                    put("USERNAME", email)
                    put("PASSWORD", password)
                }
            },
        )
        return tokens(json, currentRefreshToken = null)
    }

    suspend fun refresh(refreshToken: String): AuthTokens {
        val json = call(
            "InitiateAuth",
            buildJsonObject {
                put("AuthFlow", "REFRESH_TOKEN_AUTH")
                put("ClientId", clientId)
                putJsonObject("AuthParameters") { put("REFRESH_TOKEN", refreshToken) }
            },
        )
        // REFRESH_TOKEN_AUTH のレスポンスには refresh token が含まれないので、今の値を引き継ぐ。
        return tokens(json, currentRefreshToken = refreshToken)
    }

    suspend fun forgotPassword(email: String) {
        call(
            "ForgotPassword",
            buildJsonObject {
                put("ClientId", clientId)
                put("Username", email)
            },
        )
    }

    suspend fun confirmForgotPassword(email: String, code: String, newPassword: String) {
        call(
            "ConfirmForgotPassword",
            buildJsonObject {
                put("ClientId", clientId)
                put("Username", email)
                put("ConfirmationCode", code)
                put("Password", newPassword)
            },
        )
    }

    suspend fun revokeToken(refreshToken: String) {
        call(
            "RevokeToken",
            buildJsonObject {
                put("ClientId", clientId)
                put("Token", refreshToken)
            },
        )
    }

    private suspend fun call(target: String, body: JsonObject): JsonObject {
        if (clientId.isEmpty()) throw CognitoException("MissingClientId", "")

        // 共有の HttpClient は expectSuccess=true なので、4xx/5xx はここで例外になる。
        // cognito-idp はエラー内容を本文に入れてくるため、拾い直して CognitoException にする。
        val response: HttpResponse = try {
            client.post("https://cognito-idp.$region.amazonaws.com/") {
                header("X-Amz-Target", "AWSCognitoIdentityProviderService.$target")
                contentType(AMZ_JSON)
                setBody(ContentApi.json.encodeToString(JsonObject.serializer(), body))
            }
        } catch (e: ResponseException) {
            throw cognitoException(e.response.bodyAsText())
        }
        val text = response.bodyAsText()

        if (!response.status.isSuccess()) throw cognitoException(text)

        return if (text.isBlank()) {
            JsonObject(emptyMap())
        } else {
            ContentApi.json.parseToJsonElement(text).jsonObject
        }
    }

    private fun cognitoException(text: String): CognitoException {
        val json = runCatching { ContentApi.json.parseToJsonElement(text).jsonObject }.getOrNull()
        val type = json?.get("__type")?.jsonPrimitive?.content.orEmpty()
        val message = json?.get("message")?.jsonPrimitive?.content.orEmpty()
        return CognitoException(type.substringAfterLast('#'), message)
    }

    private fun tokens(json: JsonObject, currentRefreshToken: String?): AuthTokens {
        val result = json["AuthenticationResult"]?.jsonObject
            ?: throw CognitoException("InvalidResponse", "認証結果を取得できませんでした。")
        val refreshToken = result["RefreshToken"]?.jsonPrimitive?.content
            ?: currentRefreshToken
            ?: throw CognitoException("InvalidResponse", "認証結果を取得できませんでした。")
        val expiresIn = result["ExpiresIn"]?.jsonPrimitive?.content?.toLongOrNull() ?: 3600

        return AuthTokens(
            idToken = result["IdToken"]?.jsonPrimitive?.content
                ?: throw CognitoException("InvalidResponse", "認証結果を取得できませんでした。"),
            accessToken = result["AccessToken"]?.jsonPrimitive?.content.orEmpty(),
            refreshToken = refreshToken,
            expiresAt = System.currentTimeMillis() / 1000 + expiresIn,
        )
    }

    private companion object {
        val AMZ_JSON = ContentType("application", "x-amz-json-1.1")
    }
}
