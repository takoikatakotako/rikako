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

/** POST /answers のリクエスト。 */
@Serializable
data class SubmitAnswersRequest(
    @SerialName("workbookId") val workbookId: Long,
    val answers: List<AnswerItem>,
)

@Serializable
data class AnswerItem(
    @SerialName("questionId") val questionId: Long,
    @SerialName("selectedChoice") val selectedChoice: Int,
)

@Serializable
data class SubmitAnswersResponse(
    @SerialName("correctCount") val correctCount: Int,
    @SerialName("totalCount") val totalCount: Int,
)

/** GET /users/me/summary */
@Serializable
data class UserSummary(
    @SerialName("totalAnswered") val totalAnswered: Int,
    @SerialName("totalCorrect") val totalCorrect: Int,
    @SerialName("weeklyAnswered") val weeklyAnswered: Int,
    @SerialName("weeklyCorrect") val weeklyCorrect: Int,
    /** yyyy-MM-dd 形式の学習日。 */
    @SerialName("studyDates") val studyDates: List<String> = emptyList(),
    @SerialName("weeklyWorkbookIds") val weeklyWorkbookIds: List<Long> = emptyList(),
)

/** GET /users/me/workbook-progress */
@Serializable
data class WorkbookProgressResponse(
    val results: List<QuestionProgressItem> = emptyList(),
)

@Serializable
data class QuestionProgressItem(
    @SerialName("questionId") val questionId: Long,
    @SerialName("isCorrect") val isCorrect: Boolean,
)

/** GET /users/me/answer-logs */
@Serializable
data class AnswerLogsResponse(
    val logs: List<AnswerLogItem> = emptyList(),
    val total: Int = 0,
)

@Serializable
data class AnswerLogItem(
    val id: Long,
    @SerialName("questionId") val questionId: Long,
    @SerialName("questionText") val questionText: String,
    @SerialName("workbookId") val workbookId: Long,
    @SerialName("workbookTitle") val workbookTitle: String,
    @SerialName("selectedChoice") val selectedChoice: Int,
    @SerialName("isCorrect") val isCorrect: Boolean,
    @SerialName("answeredAt") val answeredAt: String,
)

/** GET /users/me/wrong-answers */
@Serializable
data class WrongAnswersResponse(
    val questions: List<WrongAnswerQuestion> = emptyList(),
    val total: Int = 0,
)

@Serializable
data class WrongAnswerQuestion(
    val id: Long,
    val type: String = "single_choice",
    val text: String,
    val choices: List<String> = emptyList(),
    val correct: Int? = null,
    val explanation: String? = null,
    val images: List<String> = emptyList(),
    @SerialName("workbookId") val workbookId: Long,
)

/** 解き直しで通常の出題と同じ扱いにするための変換。 */
fun WrongAnswerQuestion.toQuestion(): Question = Question(
    id = id,
    type = type,
    text = text,
    choices = choices,
    correct = correct,
    explanation = explanation,
    images = images,
)

@Serializable
data class ChatMessageRequest(val role: String, val content: String)

@Serializable
data class ChatRequest(
    val messages: List<ChatMessageRequest>,
    @SerialName("selectedChoice") val selectedChoice: Int,
)

@Serializable
data class ChatResponse(
    val reply: String,
    @SerialName("turnCount") val turnCount: Int,
    @SerialName("remainingTurns") val remainingTurns: Int,
)

@Serializable
data class UserProfile(
    val userId: Long? = null,
    val identityId: String,
    val displayName: String? = null,
    val selectedWorkbookId: Long? = null,
)

@Serializable
data class UpdateUserProfileRequest(val displayName: String?)

@Serializable
data class Announcement(
    val id: Long,
    val title: String,
    val body: String,
    val category: String,
    val publishedAt: String,
)

@Serializable
data class AnnouncementsResponse(val announcements: List<Announcement> = emptyList())

@Serializable
data class ContactRequest(
    val body: String,
    val subject: String? = null,
    val email: String? = null,
    val userId: String? = null,
    val deviceModel: String? = null,
    val osVersion: String? = null,
    val appVersion: String? = null,
)
