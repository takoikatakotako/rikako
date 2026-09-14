package org.rikako.quiz.data.repository

import io.ktor.client.plugins.ClientRequestException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import io.ktor.http.HttpStatusCode
import org.rikako.quiz.data.auth.AccountSession
import org.rikako.quiz.data.auth.AuthorizedCall
import org.rikako.quiz.data.auth.SubmissionGate
import org.rikako.quiz.data.identity.DeviceIdentityProvider
import org.rikako.quiz.data.remote.AccountApi
import org.rikako.quiz.data.remote.AccountLink

/** `/account/link` の進行状況。起動時の再試行結果も画面から見えるようにする。 */
enum class LinkState {
    Idle,
    Linking,
    Failed,
}

class AccountRepository(
    private val session: AccountSession,
    private val accountApi: AccountApi,
    private val identityProvider: DeviceIdentityProvider,
    private val submissionGate: SubmissionGate,
) {
    private val authorized = AuthorizedCall(session)

    /**
     * ensureLinked を1本ずつ実行する。起動時とログイン直後の2呼び出しが並行すると、
     * 先に成功した方が pending を下げた後で、待っていた方の失敗で Failed が残り、
     * 再試行も pending=false で素通りして解除できなくなる。
     */
    private val linkMutex = Mutex()

    private val _linkState = MutableStateFlow(LinkState.Idle)

    /** 起動時・ログイン直後・明示的な再試行のいずれから呼ばれても、ここに結果が出る。 */
    val linkState: StateFlow<LinkState> = _linkState.asStateFlow()

    /**
     * 匿名データをアカウントへ紐付ける。
     *
     * リンクが失敗したままだと、ログイン済みなので通常 API は canonical user を読み書きできる一方、
     * ログイン前にこの端末に溜まった学習記録だけが取り残される。そのため成功するまで
     * pending を残し、起動時とログイン直後の両方から呼ぶ（冪等）。
     *
     * 進行中の回答送信があると、移動後の旧ユーザーへ INSERT が入って取り残されるため、
     * submissionGate で送信の完了を待ってから実行する。
     */
    suspend fun ensureLinked(): AccountLink? = linkMutex.withLock {
        // ロック待ちの間に、他の呼び出しが済ませているかもしれない。
        if (!session.isLoggedIn || !session.linkPending) return@withLock null

        // 通信中にログアウト → 別アカウントでログインした場合、古いリクエストの結果で
        // 新しいセッションの pending を下げてはいけない。
        val startedAt = session.sessionGeneration

        _linkState.value = LinkState.Linking
        val link = try {
            submissionGate.link { linkWithRotationOnConflict() }
        } catch (e: Throwable) {
            // pending は落とさない。次回起動または明示的な再試行でやり直す。
            if (session.sessionGeneration == startedAt) _linkState.value = LinkState.Failed
            throw e
        }

        if (session.sessionGeneration != startedAt) return@withLock null
        session.linkPending = false
        _linkState.value = LinkState.Idle
        link
    }

    private suspend fun linkWithRotationOnConflict(): AccountLink = authorized.execute { idToken ->
        val token = idToken ?: error("not logged in")
        try {
            accountApi.link(token, identityProvider.identityId())
        } catch (e: ClientRequestException) {
            // 409 は、この端末の identity が既に別アカウントへ紐付いている場合。
            // 新しい匿名 identity を取り直してからやり直す（iOS と同じ）。
            if (e.response.status != HttpStatusCode.Conflict) throw e
            accountApi.link(token, identityProvider.rotate())
        }
    }
}
