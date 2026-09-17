package org.rikako.quiz.data.repository

import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.rikako.quiz.data.auth.AccountSession
import org.rikako.quiz.data.auth.AuthorizedCall
import org.rikako.quiz.data.auth.SubmissionGate
import org.rikako.quiz.data.identity.DeviceIdentityProvider
import org.rikako.quiz.data.model.AnswerItem
import org.rikako.quiz.data.model.ChatMessageRequest
import org.rikako.quiz.data.model.ChatRequest
import org.rikako.quiz.data.model.ChatResponse
import org.rikako.quiz.data.model.AnswerLogsResponse
import org.rikako.quiz.data.model.SubmitAnswersRequest
import org.rikako.quiz.data.model.SubmitAnswersResponse
import org.rikako.quiz.data.model.UserSummary
import org.rikako.quiz.data.model.UserProfile
import org.rikako.quiz.data.model.Announcement
import org.rikako.quiz.data.model.AppStatusResponse
import org.rikako.quiz.data.model.TransferToken
import org.rikako.quiz.data.model.ContactRequest
import org.rikako.quiz.data.model.Workbook
import org.rikako.quiz.data.model.WorkbookDetail
import org.rikako.quiz.data.model.WorkbookProgressResponse
import org.rikako.quiz.data.model.WrongAnswersResponse
import org.rikako.quiz.data.remote.AnswerApi
import org.rikako.quiz.data.remote.ChatApi
import org.rikako.quiz.data.remote.ContentApi
import org.rikako.quiz.data.remote.ContactApi
import org.rikako.quiz.data.remote.UserApi
import org.rikako.quiz.data.remote.TransferApi

class LearningRepository(
    private val api: ContentApi,
    private val answerApi: AnswerApi,
    private val chatApi: ChatApi? = null,
    private val contactApi: ContactApi? = null,
    private val userApi: UserApi,
    private val identityProvider: DeviceIdentityProvider,
    private val session: AccountSession,
    private val submissionGate: SubmissionGate,
    private val slug: String,
    private val transferApi: TransferApi? = null,
) {
    private val _learningDataChanged = MutableSharedFlow<Unit>(extraBufferCapacity = 1)
    private val selectedWorkbookUpdateMutex = Mutex()

    /**
     * 回答が記録されたことの通知。学習記録・間違えた問題の画面はこれを受けて読み直す
     * （タブを開いたまま問題を解くと、古い集計が出たままになるため）。
     */
    val learningDataChanged: SharedFlow<Unit> = _learningDataChanged.asSharedFlow()

    /** 全問題集のうち、このフレーバーが扱うカテゴリのものだけを返す。 */
    suspend fun fetchWorkbooks(): List<Workbook> {
        val all = api.fetchWorkbooks().workbooks
        val categoryIds = api.fetchAppDetail(slug).categories.map { it.id }.toSet()
        return all.filter { it.categoryId != null && it.categoryId in categoryIds }
    }

    suspend fun fetchWorkbookDetail(id: Long): WorkbookDetail = api.fetchWorkbookDetail(id)

    suspend fun fetchAppStatus(): AppStatusResponse = api.fetchAppStatus(slug)

    suspend fun fetchTransferToken(): TransferToken {
        check(!session.isLoggedIn) { "ログアウトしてから引き継いでください" }
        return checkNotNull(transferApi) { "引き継ぎAPIが設定されていません" }
            .fetchToken(identityProvider.identityId())
    }

    suspend fun refreshTransferToken(): TransferToken {
        check(!session.isLoggedIn) { "ログアウトしてから引き継いでください" }
        return checkNotNull(transferApi) { "引き継ぎAPIが設定されていません" }
            .refreshToken(identityProvider.identityId())
    }

    suspend fun applyTransferToken(token: String) {
        val api = checkNotNull(transferApi) { "引き継ぎAPIが設定されていません" }
        submissionGate.link {
            check(!session.isLoggedIn) { "ログアウトしてから引き継いでください" }
            val currentId = identityProvider.identityId()
            val sourceId = api.applyToken(currentId, token).identityId
            identityProvider.adopt(sourceId)
        }
        _learningDataChanged.tryEmit(Unit)
    }

    suspend fun fetchAnnouncements(): List<Announcement> = api.fetchAnnouncements().announcements

    suspend fun fetchProfile(): UserProfile = authorized.execute { idToken ->
        userApi.fetchProfile(identityProvider.identityId(), idToken, slug)
    }

    suspend fun updateDisplayName(displayName: String?): UserProfile = authorized.execute { idToken ->
        userApi.updateProfile(identityProvider.identityId(), idToken, slug, displayName)
    }

    suspend fun updateSelectedWorkbook(workbookId: Long): UserProfile = selectedWorkbookUpdateMutex.withLock {
        authorized.execute { idToken ->
            userApi.updateSelectedWorkbook(identityProvider.identityId(), idToken, slug, workbookId)
        }
    }

    suspend fun submitContact(request: ContactRequest) {
        checkNotNull(contactApi) { "お問い合わせAPIが設定されていません" }
            .submit(identityProvider.identityId(), request)
    }

    suspend fun fetchWorkbookProgress(workbookId: Long): WorkbookProgressResponse =
        authorized.execute { idToken ->
            userApi.fetchWorkbookProgress(identityProvider.identityId(), idToken, workbookId)
        }

    suspend fun chatWithQuestion(
        questionId: Long,
        messages: List<ChatMessageRequest>,
        selectedChoice: Int,
    ): ChatResponse = authorized.execute { idToken ->
        val api = checkNotNull(chatApi) { "AI質問APIが設定されていません" }
        api.chat(
            questionId = questionId,
            deviceId = identityProvider.identityId(),
            idToken = idToken,
            request = ChatRequest(messages, selectedChoice),
        )
    }

    private val authorized = AuthorizedCall(session)

    suspend fun fetchSummary(): UserSummary = authorized.execute { idToken ->
        userApi.fetchSummary(identityProvider.identityId(), idToken)
    }

    suspend fun fetchAnswerLogs(limit: Int = PAGE_SIZE, offset: Int = 0): AnswerLogsResponse =
        authorized.execute { idToken ->
            userApi.fetchAnswerLogs(identityProvider.identityId(), idToken, limit, offset)
        }

    suspend fun fetchWrongAnswers(limit: Int = PAGE_SIZE, offset: Int = 0): WrongAnswersResponse =
        authorized.execute { idToken ->
            userApi.fetchWrongAnswers(identityProvider.identityId(), idToken, limit, offset)
        }

    /**
     * 回答を送信する。匿名 identity は未払い出しならここで取得される。
     *
     * 送信は submissionGate を通す。/account/link と直列化しないと、
     * 「未リンクの device user を解決 → link が既存回答を移動 → 旧 user へ INSERT」の順になり、
     * 直前の回答だけアカウントに回収されないため。
     */
    suspend fun submitAnswers(workbookId: Long, answers: List<AnswerItem>): SubmitAnswersResponse =
        submissionGate.submission {
            val deviceId = identityProvider.identityId()
            authorized.execute { idToken ->
                answerApi.submitAnswers(
                    deviceId = deviceId,
                    idToken = idToken,
                    request = SubmitAnswersRequest(workbookId, answers),
                )
            }.also { _learningDataChanged.tryEmit(Unit) }
        }

    companion object {
        const val PAGE_SIZE = 20
    }
}
