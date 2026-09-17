package org.rikako.quiz.data.identity

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** iOS の効果音・触覚フィードバック設定に対応。 */
class FeedbackPreferences(context: Context) {
    private val preferences = context.getSharedPreferences("rikako_feedback", Context.MODE_PRIVATE)
    private val _soundEnabled = MutableStateFlow(preferences.getBoolean(SOUND, true))
    private val _hapticEnabled = MutableStateFlow(preferences.getBoolean(HAPTIC, true))

    val soundEnabled: StateFlow<Boolean> = _soundEnabled.asStateFlow()
    val hapticEnabled: StateFlow<Boolean> = _hapticEnabled.asStateFlow()

    fun setSoundEnabled(enabled: Boolean) {
        preferences.edit().putBoolean(SOUND, enabled).apply()
        _soundEnabled.value = enabled
    }

    fun setHapticEnabled(enabled: Boolean) {
        preferences.edit().putBoolean(HAPTIC, enabled).apply()
        _hapticEnabled.value = enabled
    }

    private companion object {
        const val SOUND = "sound_enabled"
        const val HAPTIC = "haptic_enabled"
    }
}
