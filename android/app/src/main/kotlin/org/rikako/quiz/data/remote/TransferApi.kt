package org.rikako.quiz.data.remote

import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType
import org.rikako.quiz.data.model.ApplyTransferRequest
import org.rikako.quiz.data.model.ApplyTransferResponse
import org.rikako.quiz.data.model.TransferToken

/** アカウントを使わない端末間の匿名 identity 引き継ぎ。 */
class TransferApi(
    private val apiBaseUrl: String,
    private val client: HttpClient = ContentApi.defaultClient(),
) {
    suspend fun fetchToken(deviceId: String): TransferToken =
        client.get("$apiBaseUrl/transfer/token") { header("X-Device-ID", deviceId) }.body()

    suspend fun refreshToken(deviceId: String): TransferToken =
        client.post("$apiBaseUrl/transfer/token") { header("X-Device-ID", deviceId) }.body()

    suspend fun applyToken(deviceId: String, token: String): ApplyTransferResponse =
        client.post("$apiBaseUrl/transfer/apply") {
            header("X-Device-ID", deviceId)
            contentType(ContentType.Application.Json)
            setBody(ApplyTransferRequest(token))
        }.body()
}
