package org.rikako.quiz.data.identity

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

interface OnboardingPreference {
    val completed: StateFlow<Boolean>
    fun complete()
    fun reset()
}

/** iOS の hasCompletedOnboarding と同じ端末内フラグ。学習記録や匿名IDは消さない。 */
class OnboardingStore(context: Context) : OnboardingPreference {
    private val preferences = context.getSharedPreferences("rikako_onboarding", Context.MODE_PRIVATE)
    private val _completed = MutableStateFlow(preferences.getBoolean(KEY, false))
    override val completed: StateFlow<Boolean> = _completed.asStateFlow()
    private val _revision = MutableStateFlow(0)
    val revision: StateFlow<Int> = _revision.asStateFlow()

    override fun complete() {
        preferences.edit().putBoolean(KEY, true).apply()
        _completed.value = true
    }

    override fun reset() {
        preferences.edit().remove(KEY).apply()
        _revision.value += 1
        _completed.value = false
    }

    private companion object {
        const val KEY = "completed"
    }
}
