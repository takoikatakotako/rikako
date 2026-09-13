package org.rikako.quiz.data.repository

import org.rikako.quiz.data.identity.DeviceIdentityProvider
import org.rikako.quiz.data.model.AnswerItem
import org.rikako.quiz.data.model.SubmitAnswersRequest
import org.rikako.quiz.data.model.SubmitAnswersResponse
import org.rikako.quiz.data.model.Workbook
import org.rikako.quiz.data.model.WorkbookDetail
import org.rikako.quiz.data.remote.AnswerApi
import org.rikako.quiz.data.remote.ContentApi

class LearningRepository(
    private val api: ContentApi,
    private val answerApi: AnswerApi,
    private val identityProvider: DeviceIdentityProvider,
    private val slug: String,
) {
    /** 全問題集のうち、このフレーバーが扱うカテゴリのものだけを返す。 */
    suspend fun fetchWorkbooks(): List<Workbook> {
        val all = api.fetchWorkbooks().workbooks
        val categoryIds = api.fetchAppDetail(slug).categories.map { it.id }.toSet()
        return all.filter { it.categoryId != null && it.categoryId in categoryIds }
    }

    suspend fun fetchWorkbookDetail(id: Long): WorkbookDetail = api.fetchWorkbookDetail(id)

    /** 回答を送信する。匿名 identity は未払い出しならここで取得される。 */
    suspend fun submitAnswers(workbookId: Long, answers: List<AnswerItem>): SubmitAnswersResponse {
        val deviceId = identityProvider.identityId()
        return answerApi.submitAnswers(deviceId, SubmitAnswersRequest(workbookId, answers))
    }
}
