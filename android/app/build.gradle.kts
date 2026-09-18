plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

// Play へ上げるビルドは CI から鍵を渡す。ローカルでは未設定のままでよく、
// その場合 release も署名なし（= Play へは上げられない）ビルドになる。
val keystoreFile: String? = System.getenv("ANDROID_KEYSTORE_FILE")
val keystorePassword: String? = System.getenv("ANDROID_KEYSTORE_PASSWORD")
val keyAlias: String? = System.getenv("ANDROID_KEY_ALIAS")
val keyPassword: String? = System.getenv("ANDROID_KEY_PASSWORD")
val hasReleaseSigning = !keystoreFile.isNullOrBlank() && file(keystoreFile).exists()

android {
    namespace = "org.rikako.quiz"
    compileSdk = 35

    defaultConfig {
        minSdk = 26
        targetSdk = 35
        // Play は同じ versionCode を二度受け付けないため、CI では UTC 時刻由来の
        // 一意な番号を渡す。手元では初回手動アップロード用の 1 のまま。
        versionCode = (System.getenv("ANDROID_VERSION_CODE") ?: "1").toInt()
        versionName = "1.0.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(keystoreFile!!)
                storePassword = keystorePassword
                this.keyAlias = keyAlias
                this.keyPassword = keyPassword
            }
        }
    }

    // iOS の xcconfig（ios/Configs 配下の xcconfig）と同じ軸で変種を持つ。
    // app  … アプリのフレーバー（化学 / IT）
    // env  … 接続先環境（dev / prod）
    flavorDimensions += listOf("app", "env")

    productFlavors {
        create("chemistry") {
            dimension = "app"
            applicationId = "org.rikako.chemistry"
            buildConfigField("String", "APP_SLUG", "\"high-school-chemistry\"")
        }
        create("itPassport") {
            dimension = "app"
            applicationId = "org.rikako.itpassport"
            buildConfigField("String", "APP_SLUG", "\"it-passport\"")
        }
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            buildConfigField("String", "API_BASE_URL", "\"https://api.dev.rikako.org\"")
            buildConfigField("String", "CONTENT_BASE_URL", "\"https://content.dev.rikako.org/v1\"")
            buildConfigField("String", "COGNITO_CLIENT_ID", "\"2buo6t5fbneujoknvrdph8flda\"")
            buildConfigField(
                "String",
                "COGNITO_IDENTITY_POOL_ID",
                "\"ap-northeast-1:51acc74e-ec8d-4de4-bfa1-84648ea45222\""
            )
        }
        create("prod") {
            dimension = "env"
            buildConfigField("String", "API_BASE_URL", "\"https://api.rikako.org\"")
            buildConfigField("String", "CONTENT_BASE_URL", "\"https://content.rikako.org/v1\"")
            buildConfigField("String", "COGNITO_CLIENT_ID", "\"4sqsett62vuckqt68d72nf2083\"")
            buildConfigField(
                "String",
                "COGNITO_IDENTITY_POOL_ID",
                "\"ap-northeast-1:57e37fca-fc40-4c34-9e1b-c5ef9888d3f4\""
            )
        }
    }

    buildTypes {
        debug {
            versionNameSuffix = "-debug"
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    packaging {
        resources.excludes += "/META-INF/{AL2.0,LGPL2.1}"
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.navigation.compose)

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    debugImplementation(libs.androidx.compose.ui.tooling)

    implementation(libs.ktor.client.core)
    implementation(libs.ktor.client.okhttp)
    implementation(libs.ktor.client.content.negotiation)
    implementation(libs.ktor.serialization.kotlinx.json)
    implementation(libs.kotlinx.serialization.json)

    implementation(libs.coil.compose)
    implementation(libs.coil.network.okhttp)

    implementation("com.google.zxing:core:3.5.4")
    implementation("com.google.android.gms:play-services-code-scanner:16.1.0")

    testImplementation(libs.junit)
    // Keystore は実機／エミュレータでしか動かないので、保存まわりは計装テストで確認する。
    androidTestImplementation(libs.junit)
    androidTestImplementation(libs.androidx.test.junit)
    androidTestImplementation(libs.androidx.test.runner)
    testImplementation(libs.ktor.client.mock)
    testImplementation(libs.kotlinx.coroutines.test)
}
