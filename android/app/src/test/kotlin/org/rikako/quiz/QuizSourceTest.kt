package org.rikako.quiz

import org.junit.Assert.assertEquals
import org.junit.Test
import org.rikako.quiz.data.model.AnswerItem
import org.rikako.quiz.data.model.Question
import org.rikako.quiz.ui.quiz.QuizSource

class QuizSourceTest {

    private fun question(id: Long) = Question(id = id, text = "問$id", choices = listOf("ア", "イ"), correct = 0)

    private val questions = listOf(question(1), question(2), question(3))

    @Test
    fun `問題集モードでは全問が同じ問題集に送られる`() {
        val grouped = QuizSource.Workbook(4).groupedAnswers(questions, listOf(0, 1, 0))

        assertEquals(
            mapOf(4L to listOf(AnswerItem(1, 0), AnswerItem(2, 1), AnswerItem(3, 0))),
            grouped,
        )
    }

    @Test
    fun `解き直しでは出身の問題集ごとに分けて送る`() {
        val source = QuizSource.Review(mapOf(1L to 4L, 2L to 7L, 3L to 4L))

        val grouped = source.groupedAnswers(questions, listOf(0, 1, 1))

        assertEquals(
            mapOf(
                4L to listOf(AnswerItem(1, 0), AnswerItem(3, 1)),
                7L to listOf(AnswerItem(2, 1)),
            ),
            grouped,
        )
    }

    @Test
    fun `未回答は送らない`() {
        val grouped = QuizSource.Workbook(4).groupedAnswers(questions, listOf(0, null, null))

        assertEquals(mapOf(4L to listOf(AnswerItem(1, 0))), grouped)
    }

    @Test
    fun `出身の問題集が分からない問題は送らない`() {
        // 対応表に無い問題は workbookId を決められないので送信対象から外す。
        val source = QuizSource.Review(mapOf(1L to 4L))

        val grouped = source.groupedAnswers(questions, listOf(0, 0, 0))

        assertEquals(mapOf(4L to listOf(AnswerItem(1, 0))), grouped)
    }
}
