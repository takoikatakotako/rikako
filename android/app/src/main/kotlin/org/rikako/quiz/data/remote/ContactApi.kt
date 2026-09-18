package org.rikako.quiz.data.remote

import io.ktor.client.HttpClient
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType
import org.rikako.quiz.data.model.ContactRequest

class ContactApi(
    private val apiBaseUrl: String,
    private val client: HttpClient = ContentApi.defaultClient(),
) {
    suspend fun submit(deviceId: String, request: ContactRequest) {
        client.post("$apiBaseUrl/contact") {
            header("X-Device-ID", deviceId)
            contentType(ContentType.Application.Json)
            setBody(request)
        }
    }
}
