package org.rikako.quiz.data.remote

import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.parameter
import org.rikako.quiz.data.model.AnswerLogsResponse
import org.rikako.quiz.data.model.UserSummary
import org.rikako.quiz.data.model.WrongAnswersResponse

/** 学習記録まわり。いずれも匿名ユーザーの識別子を X-Device-ID で送る。 */
class UserApi(
    private val apiBaseUrl: String,
    private val client: HttpClient = ContentApi.defaultClient(),
) {
    suspend fun fetchSummary(deviceId: String): UserSummary =
        client.get("$apiBaseUrl/users/me/summary") {
            header("X-Device-ID", deviceId)
        }.body()

    suspend fun fetchAnswerLogs(deviceId: String, limit: Int, offset: Int): AnswerLogsResponse =
        client.get("$apiBaseUrl/users/me/answer-logs") {
            header("X-Device-ID", deviceId)
            parameter("limit", limit)
            parameter("offset", offset)
        }.body()

    suspend fun fetchWrongAnswers(deviceId: String, limit: Int, offset: Int): WrongAnswersResponse =
        client.get("$apiBaseUrl/users/me/wrong-answers") {
            header("X-Device-ID", deviceId)
            parameter("limit", limit)
            parameter("offset", offset)
        }.body()
}
