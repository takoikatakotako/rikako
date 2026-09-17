package org.rikako.quiz.data.remote

import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.HttpRequestBuilder
import io.ktor.client.request.get
import io.ktor.client.request.put
import io.ktor.client.request.setBody
import io.ktor.client.request.header
import io.ktor.client.request.parameter
import io.ktor.http.ContentType
import io.ktor.http.contentType
import org.rikako.quiz.data.model.AnswerLogsResponse
import org.rikako.quiz.data.model.UserSummary
import org.rikako.quiz.data.model.UserProfile
import org.rikako.quiz.data.model.UpdateUserProfileRequest
import org.rikako.quiz.data.model.UpdateSelectedWorkbookRequest
import org.rikako.quiz.data.model.WorkbookProgressResponse
import org.rikako.quiz.data.model.WrongAnswersResponse

/**
 * 学習記録まわり。いずれも匿名ユーザーの識別子を X-Device-ID で送り、
 * ログイン中は Authorization も付ける（アカウント側の記録が返る）。
 */
class UserApi(
    private val apiBaseUrl: String,
    private val client: HttpClient = ContentApi.defaultClient(),
) {
    suspend fun fetchProfile(deviceId: String, idToken: String?, slug: String): UserProfile =
        client.get("$apiBaseUrl/users/me") {
            authHeaders(deviceId, idToken)
            header("X-App-Slug", slug)
        }.body()

    suspend fun updateProfile(
        deviceId: String,
        idToken: String?,
        slug: String,
        displayName: String?,
    ): UserProfile = client.put("$apiBaseUrl/users/me") {
        authHeaders(deviceId, idToken)
        header("X-App-Slug", slug)
        contentType(ContentType.Application.Json)
        setBody(UpdateUserProfileRequest(displayName))
    }.body()

    suspend fun updateSelectedWorkbook(
        deviceId: String,
        idToken: String?,
        slug: String,
        workbookId: Long,
    ): UserProfile = client.put("$apiBaseUrl/users/me") {
        authHeaders(deviceId, idToken)
        header("X-App-Slug", slug)
        contentType(ContentType.Application.Json)
        setBody(UpdateSelectedWorkbookRequest(workbookId))
    }.body()

    suspend fun fetchSummary(deviceId: String, idToken: String?): UserSummary =
        client.get("$apiBaseUrl/users/me/summary") {
            authHeaders(deviceId, idToken)
        }.body()

    suspend fun fetchWorkbookProgress(
        deviceId: String,
        idToken: String?,
        workbookId: Long,
    ): WorkbookProgressResponse =
        client.get("$apiBaseUrl/users/me/workbook-progress") {
            authHeaders(deviceId, idToken)
            parameter("workbook_id", workbookId)
        }.body()

    suspend fun fetchAnswerLogs(
        deviceId: String,
        idToken: String?,
        limit: Int,
        offset: Int,
    ): AnswerLogsResponse =
        client.get("$apiBaseUrl/users/me/answer-logs") {
            authHeaders(deviceId, idToken)
            parameter("limit", limit)
            parameter("offset", offset)
        }.body()

    suspend fun fetchWrongAnswers(
        deviceId: String,
        idToken: String?,
        limit: Int,
        offset: Int,
    ): WrongAnswersResponse =
        client.get("$apiBaseUrl/users/me/wrong-answers") {
            authHeaders(deviceId, idToken)
            parameter("limit", limit)
            parameter("offset", offset)
        }.body()

    private fun HttpRequestBuilder.authHeaders(deviceId: String, idToken: String?) {
        header("X-Device-ID", deviceId)
        idToken?.let { header("Authorization", "Bearer $it") }
    }
}
