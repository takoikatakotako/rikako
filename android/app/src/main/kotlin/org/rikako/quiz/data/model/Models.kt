package org.rikako.quiz.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** 問題集の一覧項目。content CDN の v1/workbooks.json と公開 API のレスポンスに対応。 */
@Serializable
data class Workbook(
    val id: Long,
    val title: String,
    val description: String = "",
    @SerialName("questionCount") val questionCount: Int = 0,
    @SerialName("categoryId") val categoryId: Long? = null,
)

@Serializable
data class WorkbookListResponse(val workbooks: List<Workbook> = emptyList())

/** 問題集の詳細。v1/workbooks/{id}.json。 */
@Serializable
data class WorkbookDetail(
    val id: Long,
    val title: String,
    val description: String = "",
    @SerialName("categoryId") val categoryId: Long? = null,
    val questions: List<Question> = emptyList(),
)

@Serializable
data class Question(
    val id: Long,
    val type: String = "single_choice",
    val text: String,
    val choices: List<String> = emptyList(),
    val correct: Int? = null,
    val explanation: String? = null,
    val images: List<String> = emptyList(),
) {
    val correctIndex: Int get() = correct ?: -1
}

@Serializable
data class Category(
    val id: Long,
    val title: String,
    val description: String? = null,
    @SerialName("workbookCount") val workbookCount: Int? = null,
)

/** GET /apps/{slug}。フレーバーが扱うカテゴリを返す。 */
@Serializable
data class AppDetail(
    val id: Long,
    val slug: String,
    val title: String,
    val categories: List<Category> = emptyList(),
)
