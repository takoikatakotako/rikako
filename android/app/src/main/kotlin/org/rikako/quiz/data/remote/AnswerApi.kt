package org.rikako.quiz.data.remote

import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType
import org.rikako.quiz.data.model.SubmitAnswersRequest
import org.rikako.quiz.data.model.SubmitAnswersResponse

/**
 * 回答送信。匿名ユーザーの識別子は X-Device-ID で送り、ログイン中は Authorization も付ける
 * （サーバーはログイン中ならアカウント側のユーザーに書き込む）。
 */
class AnswerApi(
    private val apiBaseUrl: String,
    private val client: HttpClient = ContentApi.defaultClient(),
) {
    suspend fun submitAnswers(
        deviceId: String,
        idToken: String?,
        request: SubmitAnswersRequest,
    ): SubmitAnswersResponse =
        client.post("$apiBaseUrl/answers") {
            header("X-Device-ID", deviceId)
            idToken?.let { header("Authorization", "Bearer $it") }
            contentType(ContentType.Application.Json)
            setBody(request)
        }.body()
}
