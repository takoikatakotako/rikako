package org.rikako.quiz.data.repository

import org.rikako.quiz.data.model.Workbook
import org.rikako.quiz.data.model.WorkbookDetail
import org.rikako.quiz.data.remote.ContentApi

class LearningRepository(
    private val api: ContentApi,
    private val slug: String,
) {
    /** 全問題集のうち、このフレーバーが扱うカテゴリのものだけを返す。 */
    suspend fun fetchWorkbooks(): List<Workbook> {
        val all = api.fetchWorkbooks().workbooks
        val categoryIds = api.fetchAppDetail(slug).categories.map { it.id }.toSet()
        return all.filter { it.categoryId != null && it.categoryId in categoryIds }
    }

    suspend fun fetchWorkbookDetail(id: Long): WorkbookDetail = api.fetchWorkbookDetail(id)
}
