package org.rikako.quiz

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test
import org.rikako.quiz.data.auth.SubmissionGate

class SubmissionGateTest {

    @Test
    fun `進行中の送信が終わるまで link を待たせる`() = runTest {
        val gate = SubmissionGate()
        val order = mutableListOf<String>()
        val submissionStarted = CompletableDeferred<Unit>()
        val releaseSubmission = CompletableDeferred<Unit>()

        val submission = async {
            gate.submission {
                order += "submission-start"
                submissionStarted.complete(Unit)
                releaseSubmission.await()
                order += "submission-end"
            }
        }
        submissionStarted.await()

        val link = async { gate.link { order += "link" } }
        advanceUntilIdle()

        // 送信が終わるまで link は動かない。
        assertEquals(listOf("submission-start"), order)

        releaseSubmission.complete(Unit)
        submission.await()
        link.await()

        assertEquals(listOf("submission-start", "submission-end", "link"), order)
    }

    @Test
    fun `link 中に始まった送信は link の後に走る`() = runTest {
        val gate = SubmissionGate()
        val order = mutableListOf<String>()
        val linkStarted = CompletableDeferred<Unit>()
        val releaseLink = CompletableDeferred<Unit>()

        val link = async {
            gate.link {
                order += "link-start"
                linkStarted.complete(Unit)
                releaseLink.await()
                order += "link-end"
            }
        }
        linkStarted.await()

        val submission = async { gate.submission { order += "submission" } }
        advanceUntilIdle()

        assertEquals(listOf("link-start"), order)

        releaseLink.complete(Unit)
        link.await()
        submission.await()

        assertEquals(listOf("link-start", "link-end", "submission"), order)
    }

    @Test
    fun `送信どうしは同時に走れる`() = runTest {
        val gate = SubmissionGate()
        val first = CompletableDeferred<Unit>()
        val bothRunning = CompletableDeferred<Unit>()

        val a = async { gate.submission { first.complete(Unit); bothRunning.await() } }
        val b = async { gate.submission { first.await(); bothRunning.complete(Unit) } }

        a.await()
        b.await()
    }
}
