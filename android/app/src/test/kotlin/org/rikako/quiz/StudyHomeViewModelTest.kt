package org.rikako.quiz

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.withTimeout
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.rikako.quiz.data.auth.SubmissionGate
import org.rikako.quiz.data.identity.SelectedWorkbookPreference
import org.rikako.quiz.data.remote.AnswerApi
import org.rikako.quiz.data.remote.ContentApi
import org.rikako.quiz.data.remote.UserApi
import org.rikako.quiz.data.repository.LearningRepository
import org.rikako.quiz.ui.workbook.WorkbookListUiState
import org.rikako.quiz.ui.workbook.WorkbookListViewModel

@OptIn(ExperimentalCoroutinesApi::class)
class StudyHomeViewModelTest {
    private class MemorySelection(var selected: Long? = null) : SelectedWorkbookPreference {
        override fun get(): Long? = selected
        override fun set(workbookId: Long) { selected = workbookId }
        override fun clear() { selected = null }
    }

    private fun repository(): LearningRepository {
        val engine = MockEngine { request ->
            val body = when (request.url.encodedPath) {
                "/workbooks.json" -> """{"workbooks":[
                    {"id":4,"title":"問題集4","categoryId":1,"questionCount":11},
                    {"id":7,"title":"問題集7","categoryId":1,"questionCount":1}
                ]}"""
                "/apps/high-school-chemistry" ->
                    """{"id":1,"slug":"high-school-chemistry","title":"化学","categories":[{"id":1,"title":"化学"}]}"""
                "/workbooks/4.json" -> """{"id":4,"title":"問題集4","questions":[
                    {"id":101,"text":"問101","choices":["A","B"],"correct":0},
                    {"id":102,"text":"問102","choices":["A","B"],"correct":0}
                ]}"""
                "/workbooks/7.json" -> """{"id":7,"title":"問題集7","questions":[
                    {"id":201,"text":"問201","choices":["A","B"],"correct":0}
                ]}"""
                "/users/me/workbook-progress" -> {
                    if (request.url.parameters["workbook_id"] == "4") {
                        """{"results":[{"questionId":101,"isCorrect":true},{"questionId":102,"isCorrect":false}]}"""
                    } else """{"results":[{"questionId":201,"isCorrect":true}]}"""
                }
                else -> error("Unexpected request: ${request.url}")
            }
            respond(
                content = body,
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, ContentType.Application.Json.toString()),
            )
        }
        val client = ContentApi.defaultClient(engine)
        return LearningRepository(
            api = ContentApi("https://content.example", "https://api.example", client),
            answerApi = AnswerApi("https://api.example", client),
            userApi = UserApi("https://api.example", client),
            identityProvider = FakeDeviceIdentityProvider("device-1"),
            session = signedOutSession(),
            submissionGate = SubmissionGate(),
            slug = "high-school-chemistry",
        )
    }

    @Before fun setUp() { Dispatchers.setMain(Dispatchers.Unconfined) }
    @After fun tearDown() { Dispatchers.resetMain() }

    @Test
    fun `選択中の問題集と進捗を表示し選択変更を保存する`() = runBlocking {
        val selection = MemorySelection(4)
        val viewModel = WorkbookListViewModel(repository(), selection)
        val first = withTimeout(5_000) {
            viewModel.uiState.first {
                it is WorkbookListUiState.Success && it.detail?.id == 4L && it.progress.isNotEmpty()
            } as WorkbookListUiState.Success
        }
        assertEquals(4L, first.selectedId)
        assertEquals(mapOf(101L to true, 102L to false), first.progress)

        viewModel.selectWorkbook(7)
        val second = withTimeout(5_000) {
            viewModel.uiState.first {
                it is WorkbookListUiState.Success && it.detail?.id == 7L && it.progress.isNotEmpty()
            } as WorkbookListUiState.Success
        }
        assertEquals(7L, selection.selected)
        assertEquals(mapOf(201L to true), second.progress)
    }
}
