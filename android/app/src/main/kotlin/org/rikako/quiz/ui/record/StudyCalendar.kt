package org.rikako.quiz.ui.record

import java.time.DayOfWeek
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.TemporalAdjusters

internal val STUDY_ZONE: ZoneId = ZoneId.of("Asia/Tokyo")

internal fun studyStreak(studyDates: Set<String>, today: LocalDate = LocalDate.now(STUDY_ZONE)): Int {
    var date = if (today.toString() in studyDates) today else today.minusDays(1)
    if (date.toString() !in studyDates) return 0
    var count = 0
    while (date.toString() in studyDates) {
        count++
        date = date.minusDays(1)
    }
    return count
}

internal fun studyWeek(today: LocalDate = LocalDate.now(STUDY_ZONE)): List<LocalDate> {
    val monday = today.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
    return (0..6).map { monday.plusDays(it.toLong()) }
}

/** iOS と同じ直近53週。今週の未来日は null とし、学習済みと誤認させない。 */
internal fun studyHeatmap(today: LocalDate = LocalDate.now(STUDY_ZONE)): List<List<LocalDate?>> {
    val firstMonday = studyWeek(today).first().minusWeeks(52)
    return (0 until 53).map { week ->
        (0..6).map { day ->
            firstMonday.plusWeeks(week.toLong()).plusDays(day.toLong()).takeIf { !it.isAfter(today) }
        }
    }
}
