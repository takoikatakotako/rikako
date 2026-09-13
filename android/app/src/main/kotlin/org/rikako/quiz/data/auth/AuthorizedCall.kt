package org.rikako.quiz.data.auth

import io.ktor.client.plugins.ClientRequestException
import io.ktor.http.HttpStatusCode

/**
 * ログイン中の API 呼び出しの共通経路。
 *
 * 端末の時計では有効でも、サーバーが 401 を返すことはある（トークン失効など）。
 * その場合だけ期限を見ずに refresh して1回だけ再送し、それでも 401 ならセッションを終了する。
 * 再試行しないと、以後の学習記録取得・回答送信が失敗し続けてしまう。
 */
class AuthorizedCall(private val session: AccountSession) {

    suspend fun <T> execute(block: suspend (idToken: String?) -> T): T {
        val idToken = session.validIdToken()
        return try {
            block(idToken)
        } catch (e: ClientRequestException) {
            if (e.response.status != HttpStatusCode.Unauthorized || idToken == null) throw e

            val refreshed = session.forceRefresh() ?: throw e
            try {
                block(refreshed)
            } catch (retryError: ClientRequestException) {
                if (retryError.response.status != HttpStatusCode.Unauthorized) throw retryError
                // refresh 後のトークンでも 401 なら、このセッションでは回復できない。
                session.endSession()
                throw SessionExpiredException()
            }
        }
    }
}
