package org.rikako.quiz.ui.workbook

import org.rikako.quiz.data.model.Question

/** iOS と同じく問題集を10問ずつのチャプターに区切る。 */
object WorkbookSections {
    const val SIZE = 10

    fun split(questions: List<Question>): List<List<Question>> = questions.chunked(SIZE)

    fun correctCount(questions: List<Question>, progress: Map<Long, Boolean>): Int =
        questions.count { progress[it.id] == true }
}
