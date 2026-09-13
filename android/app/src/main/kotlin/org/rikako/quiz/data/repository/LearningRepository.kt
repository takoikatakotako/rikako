package org.rikako.quiz.data.repository

import org.rikako.quiz.data.auth.AccountSession
import org.rikako.quiz.data.auth.AuthorizedCall
import org.rikako.quiz.data.auth.SubmissionGate
import org.rikako.quiz.data.identity.DeviceIdentityProvider
import org.rikako.quiz.data.model.AnswerItem
import org.rikako.quiz.data.model.AnswerLogsResponse
import org.rikako.quiz.data.model.SubmitAnswersRequest
import org.rikako.quiz.data.model.SubmitAnswersResponse
import org.rikako.quiz.data.model.UserSummary
import org.rikako.quiz.data.model.Workbook
import org.rikako.quiz.data.model.WorkbookDetail
import org.rikako.quiz.data.model.WrongAnswersResponse
import org.rikako.quiz.data.remote.AnswerApi
import org.rikako.quiz.data.remote.ContentApi
import org.rikako.quiz.data.remote.UserApi

class LearningRepository(
    private val api: ContentApi,
    private val answerApi: AnswerApi,
    private val userApi: UserApi,
    private val identityProvider: DeviceIdentityProvider,
    private val session: AccountSession,
    private val submissionGate: SubmissionGate,
    private val slug: String,
) {
    /** 全問題集のうち、このフレーバーが扱うカテゴリのものだけを返す。 */
    suspend fun fetchWorkbooks(): List<Workbook> {
        val all = api.fetchWorkbooks().workbooks
        val categoryIds = api.fetchAppDetail(slug).categories.map { it.id }.toSet()
        return all.filter { it.categoryId != null && it.categoryId in categoryIds }
    }

    suspend fun fetchWorkbookDetail(id: Long): WorkbookDetail = api.fetchWorkbookDetail(id)

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
            }
        }

    companion object {
        const val PAGE_SIZE = 20
    }
}
