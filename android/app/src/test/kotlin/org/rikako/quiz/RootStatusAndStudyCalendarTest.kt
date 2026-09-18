package org.rikako.quiz

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.time.DayOfWeek
import java.time.LocalDate
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.rikako.quiz.data.remote.ContentApi
import org.rikako.quiz.ui.record.studyHeatmap
import org.rikako.quiz.ui.record.studyStreak
import org.rikako.quiz.ui.record.studyWeek
import org.rikako.quiz.ui.root.isUpdateRequired

class RootStatusAndStudyCalendarTest {
    @Test fun `起動状態にはアプリ別ヘッダーを付ける`() = runBlocking {
        val api = ContentApi(
            "https://content.example", "https://api.example",
            ContentApi.defaultClient(MockEngine { request ->
                assertEquals("/status", request.url.encodedPath)
                assertEquals("high-school-chemistry", request.headers["X-App-Slug"])
                assertEquals("android", request.headers["X-App-Platform"])
                respond(
                    """{"minimumVersion":"1.2.0","latestVersion":"1.3.0","isMaintenance":true,"maintenanceMessage":"点検中"}""",
                    HttpStatusCode.OK,
                    headersOf(HttpHeaders.ContentType, ContentType.Application.Json.toString()),
                )
            }),
        )
        val status = api.fetchAppStatus("high-school-chemistry")
        assertTrue(status.isMaintenance)
        assertEquals("点検中", status.maintenanceMessage)
    }

    @Test fun `バージョンは数値で比較し不正な設定では締め出さない`() {
        assertTrue(isUpdateRequired("1.9.0", "1.10.0"))
        assertFalse(isUpdateRequired("1.10.0", "1.9.9"))
        assertFalse(isUpdateRequired("1.2", "1.2.0"))
        assertFalse(isUpdateRequired("1.0.0", "invalid"))
    }

    @Test fun `連続学習は今日か昨日から数え週は月曜始まり`() {
        val today = LocalDate.of(2026, 9, 17)
        assertEquals(3, studyStreak(setOf("2026-09-16", "2026-09-15", "2026-09-14"), today))
        assertEquals(0, studyStreak(setOf("2026-09-15"), today))
        assertEquals(2, studyStreak(setOf("2026-09-17", "2026-09-16"), today))
        assertEquals(DayOfWeek.MONDAY, studyWeek(today).first().dayOfWeek)
        val weeks = studyHeatmap(today)
        assertEquals(53, weeks.size)
        assertEquals(today, weeks.last()[3])
        assertNull(weeks.last()[4])
    }
}
