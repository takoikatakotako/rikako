package org.rikako.quiz

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.rikako.quiz.data.model.AnswerItem
import org.rikako.quiz.data.model.Question
import org.rikako.quiz.ui.quiz.QuizScoring

class QuizScoringTest {

    private fun question(id: Long, correct: Int?) = Question(
        id = id,
        text = "問$id",
        choices = listOf("ア", "イ", "ウ", "エ"),
        correct = correct,
    )

    private val questions = listOf(question(1, 0), question(2, 3), question(3, 1))

    @Test
    fun `正解した数を数える`() {
        assertEquals(2, QuizScoring.correctCount(questions, listOf(0, 3, 2)))
    }

    @Test
    fun `未回答は不正解として扱う`() {
        assertEquals(1, QuizScoring.correctCount(questions, listOf(0, null, null)))
        assertFalse(QuizScoring.isCorrect(questions[0], null))
    }

    @Test
    fun `correct が無い問題はどの選択肢でも不正解`() {
        assertFalse(QuizScoring.isCorrect(question(9, null), 0))
        assertTrue(QuizScoring.isCorrect(questions[1], 3))
    }

    @Test
    fun `未回答は送信対象に含めない`() {
        assertEquals(
            listOf(AnswerItem(1, 0), AnswerItem(3, 1)),
            QuizScoring.answerItems(questions, listOf(0, null, 1)),
        )
    }
}
