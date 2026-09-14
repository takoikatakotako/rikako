package org.rikako.quiz.data.remote

import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class AccountLink(
    @SerialName("accountId") val accountId: Long,
    val email: String? = null,
)

/** POST /account/link。ログイン中の ID token と端末の identity ID の両方が要る。 */
class AccountApi(
    private val apiBaseUrl: String,
    private val slug: String,
    private val client: HttpClient = ContentApi.defaultClient(),
) {
    suspend fun link(idToken: String, deviceId: String): AccountLink =
        client.post("$apiBaseUrl/account/link") {
            header("Authorization", "Bearer $idToken")
            header("X-Device-ID", deviceId)
            header("X-App-Slug", slug)
            contentType(ContentType.Application.Json)
            setBody("{}")
        }.body()
}
