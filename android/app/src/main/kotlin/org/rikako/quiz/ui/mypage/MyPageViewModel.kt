package org.rikako.quiz.ui.mypage

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import java.time.OffsetDateTime
import java.time.Instant
import java.time.temporal.ChronoUnit
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.async
import kotlinx.coroutines.supervisorScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import org.rikako.quiz.ServiceLocator
import org.rikako.quiz.data.model.Announcement
import org.rikako.quiz.data.model.UserProfile
import org.rikako.quiz.data.model.UserSummary
import org.rikako.quiz.data.repository.LearningRepository

data class MyPageUiState(
    val profile: UserProfile? = null,
    val summary: UserSummary? = null,
    val announcements: List<Announcement> = emptyList(),
    val isLoading: Boolean = true,
    val isSaving: Boolean = false,
    val error: String? = null,
    val unreadCount: Int = 0,
)

class MyPageViewModel(
    private val repository: LearningRepository = ServiceLocator.learningRepository,
    private val readStore: AnnouncementReadStore = AnnouncementReadStore(ServiceLocator.context()),
) : ViewModel() {
    private val _uiState = MutableStateFlow(MyPageUiState())
    val uiState: StateFlow<MyPageUiState> = _uiState.asStateFlow()
    private var refreshGeneration = 0L

    fun refresh() {
        val generation = ++refreshGeneration
        viewModelScope.launch {
            if (generation != refreshGeneration) return@launch
            _uiState.update { it.copy(profile = null, summary = null, isLoading = true, error = null) }
            val (profile, summary, announcements) = supervisorScope {
                val profile = async { fetchOrNull { repository.fetchProfile() } }
                val summary = async { fetchOrNull { repository.fetchSummary() } }
                val announcements = async { fetchOrNull { repository.fetchAnnouncements() } }
                Triple(profile.await(), summary.await(), announcements.await())
            }
            if (generation == refreshGeneration) {
                val items = announcements.orEmpty().sortedByDescending { it.publishedAt }
                _uiState.update {
                    it.copy(
                        profile = profile,
                        summary = summary,
                        announcements = items,
                        unreadCount = readStore.unreadCount(items),
                        isLoading = false,
                        error = if (profile == null || summary == null || announcements == null) {
                            "一部の情報を取得できませんでした"
                        } else null,
                    )
                }
            }
        }
    }

    fun saveDisplayName(value: String) {
        if (_uiState.value.isSaving) return
        viewModelScope.launch {
            _uiState.update { it.copy(isSaving = true, error = null) }
            try {
                // 空文字も明示して保存する。null は API 側で「更新しない」扱いになる。
                val profile = repository.updateDisplayName(value.trim())
                _uiState.update { it.copy(profile = profile, isSaving = false) }
            } catch (error: CancellationException) {
                throw error
            } catch (_: Exception) {
                _uiState.update { it.copy(isSaving = false, error = "表示名を保存できませんでした") }
            }
        }
    }

    fun markRead(id: Long) {
        readStore.markRead(id)
        _uiState.update { it.copy(unreadCount = readStore.unreadCount(it.announcements)) }
    }

    fun isUnread(announcement: Announcement): Boolean = readStore.isUnread(announcement)

    companion object {
        fun factory(): ViewModelProvider.Factory = viewModelFactory {
            initializer { MyPageViewModel() }
        }
    }
}

private suspend fun <T> fetchOrNull(block: suspend () -> T): T? = try {
    block()
} catch (error: CancellationException) {
    throw error
} catch (_: Exception) {
    null
}

class AnnouncementReadStore(context: Context) {
    private val preferences = context.getSharedPreferences("announcement_reads", Context.MODE_PRIVATE)

    fun markRead(id: Long) { preferences.edit().putBoolean(id.toString(), true).apply() }

    fun isUnread(item: Announcement): Boolean {
        val cutoff = Instant.now().minus(7, ChronoUnit.DAYS)
        return !preferences.getBoolean(item.id.toString(), false) &&
            runCatching { OffsetDateTime.parse(item.publishedAt).toInstant().isAfter(cutoff) }.getOrDefault(false)
    }

    fun unreadCount(items: List<Announcement>): Int = items.count(::isUnread)
}
