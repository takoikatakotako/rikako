package org.rikako.quiz

/**
 * ビルド変種ごとの設定。値は app/build.gradle.kts の productFlavors から
 * BuildConfig 経由で渡る（iOS の ios/Configs 配下の xcconfig に対応）。
 */
data class AppFlavor(
    val slug: String,
    val apiBaseUrl: String,
    val contentBaseUrl: String,
    val cognitoClientId: String,
    val cognitoIdentityPoolId: String,
) {
    companion object {
        val current: AppFlavor = AppFlavor(
            slug = BuildConfig.APP_SLUG,
            apiBaseUrl = BuildConfig.API_BASE_URL,
            contentBaseUrl = BuildConfig.CONTENT_BASE_URL,
            cognitoClientId = BuildConfig.COGNITO_CLIENT_ID,
            cognitoIdentityPoolId = BuildConfig.COGNITO_IDENTITY_POOL_ID,
        )
    }
}
