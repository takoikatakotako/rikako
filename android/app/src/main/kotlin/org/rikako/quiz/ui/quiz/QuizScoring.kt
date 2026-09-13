package org.rikako.quiz.ui.quiz

import org.rikako.quiz.data.model.AnswerItem
import org.rikako.quiz.data.model.Question

/** 採点。サーバーも同じ判定をするが、結果画面は送信の成否に関わらず出す。 */
object QuizScoring {

    fun isCorrect(question: Question, selectedChoice: Int?): Boolean =
        selectedChoice != null && selectedChoice == question.correctIndex

    fun correctCount(questions: List<Question>, answers: List<Int?>): Int =
        questions.indices.count { isCorrect(questions[it], answers.getOrNull(it)) }

    /** 未回答は送信しない（サーバーは選択肢 index を必須で受け取るため）。 */
    fun answerItems(questions: List<Question>, answers: List<Int?>): List<AnswerItem> =
        questions.indices.mapNotNull { index ->
            answers.getOrNull(index)?.let { AnswerItem(questions[index].id, it) }
        }
}
