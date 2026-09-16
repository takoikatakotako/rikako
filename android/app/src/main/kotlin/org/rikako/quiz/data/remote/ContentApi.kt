package org.rikako.quiz.data.remote

import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.engine.HttpClientEngine
import io.ktor.client.engine.okhttp.OkHttp
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.request.get
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.json.Json
import org.rikako.quiz.data.model.AppDetail
import org.rikako.quiz.data.model.AnnouncementsResponse
import org.rikako.quiz.data.model.WorkbookDetail
import org.rikako.quiz.data.model.WorkbookListResponse

/**
 * 問題データの取得。一覧・詳細は S3 + CloudFront の静的 JSON（content CDN）から、
 * フレーバーの対象カテゴリだけ公開 API から取る。iOS の RemoteLearningRepository と同じ経路。
 */
class ContentApi(
    private val contentBaseUrl: String,
    private val apiBaseUrl: String,
    private val client: HttpClient = defaultClient(),
) {
    suspend fun fetchWorkbooks(): WorkbookListResponse =
        client.get("$contentBaseUrl/workbooks.json").body()

    suspend fun fetchWorkbookDetail(id: Long): WorkbookDetail =
        client.get("$contentBaseUrl/workbooks/$id.json").body()

    suspend fun fetchAppDetail(slug: String): AppDetail =
        client.get("$apiBaseUrl/apps/$slug").body()

    suspend fun fetchAnnouncements(): AnnouncementsResponse =
        client.get("$contentBaseUrl/announcements.json").body()

    companion object {
        val json: Json = Json { ignoreUnknownKeys = true }

        fun defaultClient(engine: HttpClientEngine = OkHttp.create()): HttpClient =
            HttpClient(engine) {
                // 4xx/5xx を握り潰さず例外にして、UI 側でエラー表示に倒す。
                expectSuccess = true
                install(ContentNegotiation) { json(json) }
            }
    }
}
