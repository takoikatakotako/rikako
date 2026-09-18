package org.rikako.quiz.ui.quiz

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import java.util.Collections
import org.rikako.quiz.R

/** iOS と同じ正解・不正解音を先読みして低遅延で再生する。 */
internal class QuizFeedbackPlayer(context: Context) {
    private val loaded = Collections.synchronizedSet(mutableSetOf<Int>())
    private val pool = SoundPool.Builder()
        .setMaxStreams(2)
        .setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build(),
        )
        .build()
    private val correctId: Int
    private val incorrectId: Int

    init {
        pool.setOnLoadCompleteListener { _, sampleId, status ->
            if (status == 0) loaded.add(sampleId)
        }
        correctId = pool.load(context, R.raw.correct, 1)
        incorrectId = pool.load(context, R.raw.incorrect, 1)
    }

    fun play(correct: Boolean) {
        val sampleId = if (correct) correctId else incorrectId
        if (sampleId in loaded) pool.play(sampleId, 0.4f, 0.4f, 1, 0, 1f)
    }

    fun release() { pool.release() }
}
