package org.rikako.quiz

import androidx.lifecycle.viewModelScope
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.withTimeout
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.rikako.quiz.data.auth.SubmissionGate
import org.rikako.quiz.data.identity.OnboardingPreference
import org.rikako.quiz.data.identity.SelectedWorkbookPreference
import org.rikako.quiz.data.model.Question
import org.rikako.quiz.data.remote.AnswerApi
import org.rikako.quiz.data.remote.ChatApi
import org.rikako.quiz.data.remote.ContentApi
import org.rikako.quiz.data.remote.UserApi
import org.rikako.quiz.data.repository.LearningRepository
import org.rikako.quiz.ui.chat.AIChatViewModel
import org.rikako.quiz.ui.onboarding.OnboardingViewModel

@OptIn(ExperimentalCoroutinesApi::class)
class OnboardingAndChatViewModelTest {
    private val models = mutableListOf<androidx.lifecycle.ViewModel>()

    @Before fun setup() { Dispatchers.setMain(Dispatchers.Unconfined) }
    @After fun cleanup() {
        models.forEach { it.viewModelScope.cancel() }
        Dispatchers.resetMain()
    }

    private fun repository(engine: MockEngine): LearningRepository {
        val client = ContentApi.defaultClient(engine)
        return LearningRepository(
            api = ContentApi("https://content.example", "https://api.example", client),
            answerApi = AnswerApi("https://api.example", client),
            chatApi = ChatApi("https://api.example", client),
            userApi = UserApi("https://api.example", client),
            identityProvider = FakeDeviceIdentityProvider("device-1"),
            session = signedOutSession(),
            submissionGate = SubmissionGate(),
            slug = "high-school-chemistry",
        )
    }

    @Test fun `初期設定は教材選択と規約同意を終えてから完了する`() = runBlocking {
        val engine = MockEngine { request ->
            val body = when (request.url.encodedPath) {
                "/workbooks.json" -> """{"workbooks":[{"id":4,"title":"化学","categoryId":1}]}"""
                "/apps/high-school-chemistry" ->
                    """{"id":1,"slug":"high-school-chemistry","title":"化学","categories":[{"id":1,"title":"化学"}]}"""
                else -> error("Unexpected request: ${request.url}")
            }
            respond(body, HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, ContentType.Application.Json.toString()))
        }
        var selected: Long? = null
        val selection = object : SelectedWorkbookPreference {
            override fun get() = selected
            override fun set(workbookId: Long) { selected = workbookId }
            override fun clear() { selected = null }
        }
        val completion = MutableStateFlow(false)
        val onboarding = object : OnboardingPreference {
            override val completed: StateFlow<Boolean> = completion
            override fun complete() { completion.value = true }
            override fun reset() { completion.value = false }
        }
        val model = OnboardingViewModel(
            repository(engine), FakeDeviceIdentityProvider("device-1"), selection, onboarding,
        ).also { models += it }
        withTimeout(5_000) { model.uiState.first { !it.loadingWorkbooks } }
        model.next()
        model.next()
        model.next() // 教材選択ページからは選ばずに進めない
        assertEquals(2, model.uiState.value.page)
        model.chooseWorkbook(4)
        assertEquals(4L, selected)
        model.next()
        model.next() // 規約同意前は進めない
        assertEquals(4, model.uiState.value.page)
        model.setTermsAccepted(true)
        model.next()
        model.start()
        withTimeout(5_000) { completion.first { it } }
        assertTrue(completion.value)
    }

    @Test fun `AI質問は残り回数がゼロになったら送信を止める`() = runBlocking {
        var calls = 0
        val engine = MockEngine {
            calls++
            respond(
                """{"reply":"解説です","turnCount":5,"remainingTurns":0}""",
                HttpStatusCode.OK,
                headersOf(HttpHeaders.ContentType, ContentType.Application.Json.toString()),
            )
        }
        val question = Question(12, text = "問題", choices = listOf("甲", "乙"), correct = 0)
        val model = AIChatViewModel(question, 1, repository(engine)).also { models += it }
        model.updateInput("なぜ？")
        model.sendMessage()
        withTimeout(5_000) { model.uiState.first { it.messages.size == 2 } }
        assertEquals(0, model.uiState.value.remainingTurns)
        assertFalse(model.uiState.value.canSend)
        model.updateInput("もう一度")
        model.sendMessage()
        assertEquals(1, calls)
    }
}
