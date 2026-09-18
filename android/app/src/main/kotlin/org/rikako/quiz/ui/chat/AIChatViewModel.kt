package org.rikako.quiz.ui.chat

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import org.rikako.quiz.ServiceLocator
import org.rikako.quiz.data.model.ChatMessageRequest
import org.rikako.quiz.data.model.Question
import org.rikako.quiz.data.repository.LearningRepository

data class AIChatMessage(val role: String, val content: String)

data class AIChatUiState(
    val messages: List<AIChatMessage> = emptyList(),
    val inputText: String = "",
    val remainingTurns: Int = 5,
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
) {
    val canSend: Boolean get() = inputText.isNotBlank() && !isLoading && remainingTurns > 0
}

/** iOS の AIChatViewModel と同じ5往復・会話履歴送信。 */
class AIChatViewModel(
    private val question: Question,
    private val selectedChoice: Int,
    private val repository: LearningRepository = ServiceLocator.learningRepository,
) : ViewModel() {
    private val _uiState = MutableStateFlow(AIChatUiState())
    val uiState: StateFlow<AIChatUiState> = _uiState.asStateFlow()

    fun updateInput(text: String) {
        _uiState.update { it.copy(inputText = text) }
    }

    fun sendMessage() {
        val current = _uiState.value
        val text = current.inputText.trim()
        if (text.isEmpty() || current.isLoading || current.remainingTurns <= 0) return
        val history = current.messages + AIChatMessage("user", text)
        _uiState.value = current.copy(messages = history, inputText = "", isLoading = true, errorMessage = null)

        viewModelScope.launch {
            try {
                val response = repository.chatWithQuestion(
                    questionId = question.id,
                    messages = history.map { ChatMessageRequest(it.role, it.content) },
                    selectedChoice = selectedChoice,
                )
                _uiState.update {
                    it.copy(
                        messages = history + AIChatMessage("assistant", response.reply),
                        remainingTurns = response.remainingTurns.coerceIn(0, 5),
                        isLoading = false,
                    )
                }
            } catch (error: CancellationException) {
                throw error
            } catch (_: Exception) {
                // 失敗した発言は履歴から取り除き、入力欄へ戻して再送できるようにする。
                _uiState.update {
                    it.copy(
                        messages = current.messages,
                        inputText = text,
                        isLoading = false,
                        errorMessage = "エラーが発生しました。もう一度お試しください。",
                    )
                }
            }
        }
    }

    companion object {
        fun factory(question: Question, selectedChoice: Int): ViewModelProvider.Factory = viewModelFactory {
            initializer { AIChatViewModel(question, selectedChoice) }
        }
    }
}
