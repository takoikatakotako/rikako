package org.rikako.quiz.ui.quiz

import org.rikako.quiz.data.model.AnswerItem
import org.rikako.quiz.data.model.Question

/**
 * クイズの出題元。回答をどの問題集に記録するかを決める（iOS の QuizSource と同じ考え方）。
 *
 * - [Workbook]: 通常プレイ。全問が同じ問題集に属する
 * - [Review]: 間違えた問題の解き直し。問題ごとに出身の問題集が違うので、
 *   問題ID → 問題集ID の対応を持つ
 */
sealed interface QuizSource {

    data class Workbook(val workbookId: Long) : QuizSource

    data class Review(val workbookIds: Map<Long, Long>) : QuizSource

    fun workbookId(questionId: Long): Long? = when (this) {
        is Workbook -> workbookId
        is Review -> workbookIds[questionId]
    }

    /**
     * 回答を問題集ごとにまとめる。送信経路（結果画面・中断時の保存）で共通に使う。
     * 未回答と、出身の問題集が分からない問題は送らない。
     */
    fun groupedAnswers(questions: List<Question>, answers: List<Int?>): Map<Long, List<AnswerItem>> {
        val grouped = mutableMapOf<Long, MutableList<AnswerItem>>()
        questions.forEachIndexed { index, question ->
            val choice = answers.getOrNull(index) ?: return@forEachIndexed
            val workbookId = workbookId(question.id) ?: return@forEachIndexed
            grouped.getOrPut(workbookId) { mutableListOf() } += AnswerItem(question.id, choice)
        }
        return grouped
    }
}
