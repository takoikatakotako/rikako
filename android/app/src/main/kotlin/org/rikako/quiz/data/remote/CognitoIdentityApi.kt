package org.rikako.quiz.data.remote

import io.ktor.client.HttpClient
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.contentType
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Cognito Identity Pool の GetId を直接叩いて匿名 identity を払い出す。
 * 未認証 identity の GetId は署名不要なので、AWS SDK を入れずに素の HTTP で呼べる。
 */
class CognitoIdentityApi(
    private val identityPoolId: String,
    private val client: HttpClient = ContentApi.defaultClient(),
    // プール ID は "ap-northeast-1:xxxx-..." の形式なので、リージョンはそこから取れる。
    private val region: String = identityPoolId.substringBefore(':'),
) {
    suspend fun getId(): String {
        val response = client.post("https://cognito-identity.$region.amazonaws.com/") {
            header("X-Amz-Target", "AWSCognitoIdentityService.GetId")
            contentType(AMZ_JSON)
            setBody(ContentApi.json.encodeToString(GetIdRequest.serializer(), GetIdRequest(identityPoolId)))
        }
        // レスポンスの Content-Type は application/x-amz-json-1.1 で
        // ContentNegotiation の対象外なため、本文を自前でパースする。
        return ContentApi.json.decodeFromString(GetIdResponse.serializer(), response.bodyAsText()).identityId
    }

    @Serializable
    private data class GetIdRequest(@SerialName("IdentityPoolId") val identityPoolId: String)

    @Serializable
    private data class GetIdResponse(@SerialName("IdentityId") val identityId: String)

    private companion object {
        val AMZ_JSON = ContentType("application", "x-amz-json-1.1")
    }
}
