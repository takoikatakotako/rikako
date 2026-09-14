package org.rikako.quiz.e2e

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.rikako.quiz.AppFlavor
import org.rikako.quiz.data.auth.AccountSession
import org.rikako.quiz.data.auth.AuthTokenStore
import org.rikako.quiz.data.auth.AuthTokens
import org.rikako.quiz.data.auth.SubmissionGate
import org.rikako.quiz.data.identity.CognitoDeviceIdentityProvider
import org.rikako.quiz.data.identity.IdentityStore
import org.rikako.quiz.data.model.AnswerItem
import org.rikako.quiz.data.remote.AccountApi
import org.rikako.quiz.data.remote.AnswerApi
import org.rikako.quiz.data.remote.CognitoIdentityApi
import org.rikako.quiz.data.remote.CognitoUserPoolApi
import org.rikako.quiz.data.remote.ContentApi
import org.rikako.quiz.data.remote.UserApi
import org.rikako.quiz.data.repository.AccountRepository
import org.rikako.quiz.data.repository.LearningRepository

/**
 * メールログイン（#283）の E2E。dev バックエンドに実際につないで、
 * 匿名で解いた回答がログイン時にアカウントへマージされることを件数で検証する。
 *
 * 共有のテストユーザー（RIKAKO_E2E_EMAIL / RIKAKO_E2E_PASSWORD）を使う。
 * 未設定なら skip するので、通常の CI では動かない（android-e2e.yml から実行する）。
 *
 * 実バックエンドに依存するため、ネットワークや dev 環境の状態で落ちることがある。
 * その場合はアプリ側の回帰と切り分けたうえで再実行すること。
 */
class AccountLinkE2ETest {

    private class MemoryIdentityStore : IdentityStore {
        private var value: String? = null
        override fun load(): String? = value
        override fun save(value: String) { this.value = value }
        override fun clear() { value = null }
    }

    private class MemoryTokenStore : AuthTokenStore {
        private var tokens: AuthTokens? = null
        override fun load(): AuthTokens? = tokens
        override fun save(tokens: AuthTokens) { this.tokens = tokens }
        override fun clear() { tokens = null }
        override var linkPending: Boolean = false
    }

    private val email: String? = System.getenv("RIKAKO_E2E_EMAIL")
    private val password: String? = System.getenv("RIKAKO_E2E_PASSWORD")

    @Test
    fun `匿名で解いた回答がログイン時にアカウントへマージされる`() = runBlocking {
        assumeTrue(
            "RIKAKO_E2E_EMAIL / RIKAKO_E2E_PASSWORD が未設定のためスキップ",
            !email.isNullOrEmpty() && !password.isNullOrEmpty(),
        )

        val flavor = AppFlavor.current
        val client = ContentApi.defaultClient()
        val contentApi = ContentApi(flavor.contentBaseUrl, flavor.apiBaseUrl, client)
        val answerApi = AnswerApi(flavor.apiBaseUrl, client)
        val userApi = UserApi(flavor.apiBaseUrl, client)

        // 「新しい端末」を模して、この実行だけの匿名 identity を払い出す。
        val identityProvider = CognitoDeviceIdentityProvider(
            api = CognitoIdentityApi(flavor.cognitoIdentityPoolId, client),
            store = MemoryIdentityStore(),
        )
        val tokenStore = MemoryTokenStore()
        val session = AccountSession(CognitoUserPoolApi(flavor.cognitoClientId, client), tokenStore)
        val gate = SubmissionGate()
        val learning = LearningRepository(
            api = contentApi,
            answerApi = answerApi,
            userApi = userApi,
            identityProvider = identityProvider,
            session = session,
            submissionGate = gate,
            slug = flavor.slug,
        )
        // 1. アカウントの現在の回答数を基準値として読む。
        session.signIn(email!!, password!!)
        assertTrue("ログインできていない", session.isLoggedIn)
        val idToken = requireNotNull(session.validIdToken())
        val accountDeviceId = identityProvider.identityId()
        val baseline = userApi.fetchAnswerLogs(accountDeviceId, idToken, limit = 1, offset = 0).total

        // 2. 未ログインの端末として1問だけ回答する。
        val anonymousSession = AccountSession(
            CognitoUserPoolApi(flavor.cognitoClientId, client),
            MemoryTokenStore(),
        )
        val anonymousIdentity = CognitoDeviceIdentityProvider(
            api = CognitoIdentityApi(flavor.cognitoIdentityPoolId, client),
            store = MemoryIdentityStore(),
        )
        val anonymousGate = SubmissionGate()
        val anonymous = LearningRepository(
            api = contentApi,
            answerApi = answerApi,
            userApi = userApi,
            identityProvider = anonymousIdentity,
            session = anonymousSession,
            submissionGate = anonymousGate,
            slug = flavor.slug,
        )
        val workbook = learning.fetchWorkbooks().first()
        val question = anonymous.fetchWorkbookDetail(workbook.id).questions.first()
        anonymous.submitAnswers(workbook.id, listOf(AnswerItem(question.id, 0)))

        // 3. その端末でログインし、リンクする。
        val deviceSession = AccountSession(
            CognitoUserPoolApi(flavor.cognitoClientId, client),
            MemoryTokenStore(),
        )
        deviceSession.signIn(email, password)
        val deviceAccount = AccountRepository(
            session = deviceSession,
            accountApi = AccountApi(flavor.apiBaseUrl, flavor.slug, client),
            identityProvider = anonymousIdentity,
            submissionGate = anonymousGate,
        )
        val link = deviceAccount.ensureLinked()
        assertTrue("リンクされていない", link != null)

        // 4. 匿名で解いた1問がアカウント側に増えている。
        val after = userApi.fetchAnswerLogs(
            accountDeviceId,
            requireNotNull(session.validIdToken()),
            limit = 1,
            offset = 0,
        ).total
        assertEquals(baseline + 1, after)

        // 後片付け: 共有ユーザーのセッションは失効させておく。
        session.signOut()
        deviceSession.signOut()
    }
}
