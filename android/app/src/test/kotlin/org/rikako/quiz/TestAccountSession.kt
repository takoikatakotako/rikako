package org.rikako.quiz

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respondError
import io.ktor.http.HttpStatusCode
import org.rikako.quiz.data.auth.AccountSession
import org.rikako.quiz.data.auth.AuthTokenStore
import org.rikako.quiz.data.auth.AuthTokens
import org.rikako.quiz.data.remote.CognitoUserPoolApi
import org.rikako.quiz.data.remote.ContentApi

/** 未ログインのセッション。Cognito を呼ぶ経路に入ったら分かるようエラーを返す engine を使う。 */
fun signedOutSession(): AccountSession = AccountSession(
    api = CognitoUserPoolApi(
        clientId = "client-id",
        client = ContentApi.defaultClient(MockEngine { respondError(HttpStatusCode.BadRequest) }),
    ),
    store = object : AuthTokenStore {
        override fun load(): AuthTokens? = null
        override fun save(tokens: AuthTokens) = Unit
        override fun clear() = Unit
        override var linkPending: Boolean = false
    },
)
