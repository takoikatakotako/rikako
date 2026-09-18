package org.rikako.quiz

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.util.concurrent.atomic.AtomicLong
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.withTimeout
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.rikako.quiz.data.auth.SubmissionGate
import org.rikako.quiz.data.identity.OnboardingPreference
import org.rikako.quiz.data.identity.SelectedWorkbookPreference
import org.rikako.quiz.data.remote.AccountApi
import org.rikako.quiz.data.remote.AnswerApi
import org.rikako.quiz.data.remote.ContentApi
import org.rikako.quiz.data.remote.UserApi
import org.rikako.quiz.data.repository.AccountRepository
import org.rikako.quiz.data.repository.LearningRepository
import org.rikako.quiz.ui.root.RootUiState
import org.rikako.quiz.ui.root.RootViewModel
import org.rikako.quiz.ui.workbook.WorkbookListUiState
import org.rikako.quiz.ui.workbook.WorkbookListViewModel

@OptIn(ExperimentalCoroutinesApi::class)
class TransferRefreshTest {
    @Before fun setUp() { Dispatchers.setMain(Dispatchers.Unconfined) }
    @After fun tearDown() { Dispatchers.resetMain() }

    @Test fun `引き継ぎ後の再読込で新しい問題集をホームに表示する`() = runBlocking {
        val serverSelected = AtomicLong(4)
        val client = ContentApi.defaultClient(MockEngine { request ->
            val body = when (request.url.encodedPath) {
                "/status" ->
                    """{"minimumVersion":"1.0.0","latestVersion":"1.0.0","isMaintenance":false,"maintenanceMessage":""}"""
                "/users/me" ->
                    """{"identityId":"device-1","selectedWorkbookId":${serverSelected.get()}}"""
                "/workbooks.json" -> """{"workbooks":[
                    {"id":4,"title":"問題集A","categoryId":1,"questionCount":0},
                    {"id":7,"title":"問題集B","categoryId":1,"questionCount":0}
                ]}"""
                "/apps/high-school-chemistry" ->
                    """{"id":1,"slug":"high-school-chemistry","title":"化学","categories":[{"id":1,"title":"化学"}]}"""
                "/workbooks/7.json" -> """{"id":7,"title":"問題集B","questions":[]}"""
                "/users/me/workbook-progress" -> """{"results":[]}"""
                else -> error("unexpected request: ${request.url}")
            }
            respond(body, HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, ContentType.Application.Json.toString()))
        })
        val session = signedOutSession()
        val gate = SubmissionGate()
        val identity = FakeDeviceIdentityProvider("device-1")
        val repository = LearningRepository(
            api = ContentApi("https://content.example", "https://api.example", client),
            answerApi = AnswerApi("https://api.example", client),
            userApi = UserApi("https://api.example", client),
            identityProvider = identity,
            session = session,
            submissionGate = gate,
            slug = "high-school-chemistry",
        )
        val accountRepository = AccountRepository(
            session, AccountApi("https://api.example", "high-school-chemistry", client), identity, gate,
        )
        val onboarding = object : OnboardingPreference {
            override val completed: StateFlow<Boolean> = MutableStateFlow(true)
            override fun complete() = Unit
            override fun reset() = Unit
        }
        val selection = object : SelectedWorkbookPreference {
            var selected: Long? = 4
            override fun get(): Long? = selected
            override fun set(workbookId: Long) { selected = workbookId }
            override fun clear() { selected = null }
        }
        val root = RootViewModel(repository, accountRepository, onboarding, selection, "1.0.0")
        withTimeout(5_000) { root.uiState.first { it == RootUiState.Ready } }
        assertEquals(4L, selection.selected)

        serverSelected.set(7)
        selection.clear()
        root.refresh()
        withTimeout(5_000) { root.uiState.first { it == RootUiState.Ready } }
        assertEquals(7L, selection.selected)

        // 画面のナビゲーション entry を作り直すと、新しい ViewModel は同期後の値を読む。
        val home = WorkbookListViewModel(repository, selection)
        val state = withTimeout(5_000) {
            home.uiState.first { it is WorkbookListUiState.Success || it is WorkbookListUiState.Error }
        }
        assertTrue("state=$state", state is WorkbookListUiState.Success)
        assertEquals(7L, (state as WorkbookListUiState.Success).selectedId)
    }
}
