package org.rikako.quiz.data.identity

import android.content.Context

/** iOS の selectedWorkbookID と同様、最後に選んだ問題集を端末に保持する。 */
interface SelectedWorkbookPreference {
    fun get(): Long?
    fun set(workbookId: Long)
    fun clear()
}

class SelectedWorkbookStore(context: Context) : SelectedWorkbookPreference {
    private val preferences = context.getSharedPreferences("rikako_learning", Context.MODE_PRIVATE)

    override fun get(): Long? = preferences.getLong(KEY, -1L).takeIf { it >= 0L }

    override fun set(workbookId: Long) {
        preferences.edit().putLong(KEY, workbookId).apply()
    }

    override fun clear() {
        preferences.edit().remove(KEY).apply()
    }

    private companion object {
        const val KEY = "selected_workbook_id"
    }
}
