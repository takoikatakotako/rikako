package org.rikako.quiz

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpStatusCode
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
import org.rikako.quiz.data.auth.AccountSession
import org.rikako.quiz.data.auth.AuthTokenStore
import org.rikako.quiz.data.auth.AuthTokens
import org.rikako.quiz.data.auth.SubmissionGate
import org.rikako.quiz.data.remote.AccountApi
import org.rikako.quiz.data.remote.CognitoUserPoolApi
import org.rikako.quiz.data.remote.ContentApi
import org.rikako.quiz.data.repository.AccountRepository
import org.rikako.quiz.ui.account.AccountForm
import org.rikako.quiz.ui.account.AccountViewModel

@OptIn(ExperimentalCoroutinesApi::class)
class AccountViewModelTest {

    private class Store : AuthTokenStore {
        var tokens: AuthTokens? = null
        override fun load(): AuthTokens? = tokens
        override fun save(tokens: AuthTokens) { this.tokens = tokens }
        override fun clear() { tokens = null }
        override var linkPending: Boolean = false
    }

    private fun viewModel(cognitoError: String): AccountViewModel {
        val client = ContentApi.defaultClient(
            MockEngine {
                respond(
                    content = """{"__type":"com.amazon#$cognitoError","message":"error"}""",
                    status = HttpStatusCode.BadRequest,
                )
            },
        )
        val session = AccountSession(CognitoUserPoolApi("client-id", client), Store())
        return AccountViewModel(
            session = session,
            accountRepository = AccountRepository(
                session = session,
                accountApi = AccountApi("https://api.example", "high-school-chemistry", client),
                identityProvider = FakeDeviceIdentityProvider("ap-northeast-1:device"),
                submissionGate = SubmissionGate(),
            ),
        )
    }

    @Before
    fun setUp() {
        Dispatchers.setMain(Dispatchers.Unconfined)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `メール未確認でログインしたら確認コード画面へ誘導する`() = runBlocking {
        val viewModel = viewModel("UserNotConfirmedException")

        viewModel.signIn("me@example.com", "password")

        val state = withTimeout(5_000) {
            viewModel.uiState.first { it.form == AccountForm.ConfirmSignUp && !it.isBusy }
        }
        assertEquals("メール確認が完了していません。確認コードを入力してください。", state.errorMessage)
    }

    @Test
    fun `パスワード誤りではフォームを変えない`() = runBlocking {
        val viewModel = viewModel("NotAuthorizedException")

        viewModel.signIn("me@example.com", "password")

        val state = withTimeout(5_000) { viewModel.uiState.first { !it.isBusy && it.errorMessage != null } }
        assertEquals(AccountForm.SignIn, state.form)
        assertEquals("メールアドレスまたはパスワードが正しくありません。", state.errorMessage)
    }
}
