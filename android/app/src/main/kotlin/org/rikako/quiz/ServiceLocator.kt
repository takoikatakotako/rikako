package org.rikako.quiz

import android.content.Context
import org.rikako.quiz.data.identity.CognitoDeviceIdentityProvider
import org.rikako.quiz.data.identity.DeviceIdentityProvider
import org.rikako.quiz.data.identity.SharedPrefsIdentityStore
import org.rikako.quiz.data.remote.AnswerApi
import org.rikako.quiz.data.remote.CognitoIdentityApi
import org.rikako.quiz.data.remote.ContentApi
import org.rikako.quiz.data.repository.LearningRepository

/** DI ライブラリを入れるまでの最小限の依存解決。 */
object ServiceLocator {
    private val flavor = AppFlavor.current

    private lateinit var appContext: Context

    fun init(context: Context) {
        appContext = context.applicationContext
    }

    private val httpClient by lazy { ContentApi.defaultClient() }

    val deviceIdentityProvider: DeviceIdentityProvider by lazy {
        CognitoDeviceIdentityProvider(
            api = CognitoIdentityApi(
                identityPoolId = flavor.cognitoIdentityPoolId,
                client = httpClient,
            ),
            store = SharedPrefsIdentityStore(appContext),
        )
    }

    val learningRepository: LearningRepository by lazy {
        LearningRepository(
            api = ContentApi(
                contentBaseUrl = flavor.contentBaseUrl,
                apiBaseUrl = flavor.apiBaseUrl,
                client = httpClient,
            ),
            answerApi = AnswerApi(apiBaseUrl = flavor.apiBaseUrl, client = httpClient),
            identityProvider = deviceIdentityProvider,
            slug = flavor.slug,
        )
    }
}
