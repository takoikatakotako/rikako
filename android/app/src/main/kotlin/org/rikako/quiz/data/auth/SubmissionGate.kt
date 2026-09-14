package org.rikako.quiz.data.auth

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * 回答送信と `/account/link` を直列化する。
 *
 * link は「この端末の匿名ユーザーに溜まった回答」をアカウント側へ移す操作なので、
 * 送信と重なると移動後の旧ユーザーへ INSERT が入り、その回答だけ取り残される。
 * 送信は複数同時に走ってよいが、link の間は新しい送信を始めさせず、
 * 進行中の送信が終わるのを待つ（読み書きロックと同じ考え方）。
 */
class SubmissionGate {

    private val linkMutex = Mutex()
    private val active = MutableStateFlow(0)

    suspend fun <T> submission(block: suspend () -> T): T {
        // link 中はここで待たされる。
        linkMutex.withLock { active.update { it + 1 } }
        try {
            return block()
        } finally {
            active.update { it - 1 }
        }
    }

    suspend fun <T> link(block: suspend () -> T): T = linkMutex.withLock {
        active.first { it == 0 }
        block()
    }
}
