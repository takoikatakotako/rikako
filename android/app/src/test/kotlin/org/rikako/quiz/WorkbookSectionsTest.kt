package org.rikako.quiz

import org.junit.Assert.assertEquals
import org.junit.Test
import org.rikako.quiz.data.model.Question
import org.rikako.quiz.ui.workbook.WorkbookSections

class WorkbookSectionsTest {
    @Test
    fun `iOSと同じ10問単位で最後の端数も残す`() {
        val questions = (1L..21L).map { Question(id = it, text = "問$it") }
        val sections = WorkbookSections.split(questions)

        assertEquals(listOf(10, 10, 1), sections.map { it.size })
        assertEquals(listOf(1L, 11L, 21L), sections.map { it.first().id })
        assertEquals(2, WorkbookSections.correctCount(sections.first(), mapOf(1L to true, 2L to true, 3L to false)))
        assertEquals(emptyList<List<Question>>(), WorkbookSections.split(emptyList()))
    }
}
