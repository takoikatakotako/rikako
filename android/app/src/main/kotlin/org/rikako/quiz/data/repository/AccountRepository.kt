package org.rikako.quiz.data.repository

import io.ktor.client.plugins.ClientRequestException
import io.ktor.http.HttpStatusCode
import org.rikako.quiz.data.auth.AccountSession
import org.rikako.quiz.data.identity.DeviceIdentityProvider
import org.rikako.quiz.data.remote.AccountApi
import org.rikako.quiz.data.remote.AccountLink

class AccountRepository(
    private val session: AccountSession,
    private val accountApi: AccountApi,
    private val identityProvider: DeviceIdentityProvider,
) {
    /**
     * 匿名データをアカウントへ紐付ける。
     *
     * リンクが失敗したままだと、ログイン済みなので通常 API は canonical user を読み書きできる一方、
     * ログイン前にこの端末に溜まった学習記録だけが取り残される。そのため成功するまで
     * pending を残し、起動時とログイン直後の両方から呼ぶ（冪等）。
     */
    suspend fun ensureLinked(): AccountLink? {
        if (!session.isLoggedIn || !session.linkPending) return null

        val link = linkWithRotationOnConflict()
        session.linkPending = false
        return link
    }

    private suspend fun linkWithRotationOnConflict(): AccountLink {
        val idToken = session.validIdToken() ?: error("not logged in")
        return try {
            accountApi.link(idToken, identityProvider.identityId())
        } catch (e: ClientRequestException) {
            // 409 は、この端末の identity が既に別アカウントへ紐付いている場合。
            // 新しい匿名 identity を取り直してからやり直す（iOS と同じ）。
            if (e.response.status != HttpStatusCode.Conflict) throw e
            accountApi.link(idToken, identityProvider.rotate())
        }
    }
}
