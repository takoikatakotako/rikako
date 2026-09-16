package org.rikako.quiz.data.remote

import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType
import org.rikako.quiz.data.model.ChatRequest
import org.rikako.quiz.data.model.ChatResponse

/** iOS と同じ POST /questions/{id}/chat。匿名IDとログイン状態を送る。 */
class ChatApi(
    private val apiBaseUrl: String,
    private val client: HttpClient = ContentApi.defaultClient(),
) {
    suspend fun chat(questionId: Long, deviceId: String, idToken: String?, request: ChatRequest): ChatResponse =
        client.post("$apiBaseUrl/questions/$questionId/chat") {
            header("X-Device-ID", deviceId)
            idToken?.let { header("Authorization", "Bearer $it") }
            contentType(ContentType.Application.Json)
            setBody(request)
        }.body()
}
