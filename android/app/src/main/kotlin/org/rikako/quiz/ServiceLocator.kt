package org.rikako.quiz

import org.rikako.quiz.data.remote.ContentApi
import org.rikako.quiz.data.repository.LearningRepository

/** DI ライブラリを入れるまでの最小限の依存解決。 */
object ServiceLocator {
    private val flavor = AppFlavor.current

    val learningRepository: LearningRepository by lazy {
        LearningRepository(
            api = ContentApi(
                contentBaseUrl = flavor.contentBaseUrl,
                apiBaseUrl = flavor.apiBaseUrl,
            ),
            slug = flavor.slug,
        )
    }
}
