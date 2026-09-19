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

// Firebase（Analytics / Crashlytics、#235）。google-services.json は API キーを含むため
// git 管理外（iOS の GoogleService-Info.plist と同じ扱い）。SSM に置いてあるので
// `scripts/firebase-config.sh pull <dev|prod>` で配置する。google-services プラグインは
// env 単独のディレクトリ（src/dev/）を探さないので、iOS の plist と同じく変種ごとに置く:
//   app/src/chemistryDev/google-services.json   … rikako-dev（dev の json。IT 版も同じ内容）
//   app/src/itPassportDev/google-services.json  … rikako-dev
//   app/src/chemistryProd/google-services.json  … rikako-prd
//   app/src/itPassportProd/google-services.json … rikako-prd
// 1 つも無い環境（CI のテスト・lint や初めて clone した手元）ではプラグインごと外し、
// アプリは Firebase 未初期化で動く（Crashlytics / Analytics は送信しない）。
// 一部だけある場合はプラグインを適用し、json の無い変種のビルドはプラグインが止める
// （dev だけ pull した手元で prod をビルドすると失敗する。意図しない未計測ビルドを防ぐため）。
val googleServicesVariants = listOf("chemistryDev", "itPassportDev", "chemistryProd", "itPassportProd")
val hasGoogleServicesJson = googleServicesVariants.any { file("src/$it/google-services.json").exists() }
// prod の release だけは json 無しで通さない（Crashlytics 無しの AAB が Play に上がるのを防ぐ）。
// CI の R8 動作確認（android.yml）は json を取れないので -PallowMissingFirebaseConfig=true で明示的に外す。
val allowMissingFirebaseConfig = providers.gradleProperty("allowMissingFirebaseConfig").orNull == "true"
if (hasGoogleServicesJson) {
    apply(plugin = libs.plugins.google.services.get().pluginId)
    apply(plugin = libs.plugins.firebase.crashlytics.get().pluginId)
} else {
    logger.warn("google-services.json が無いため Firebase プラグインを適用しません（Crashlytics / Analytics は無効。scripts/firebase-config.sh pull で配置）")
}

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
            // R8 で難読化するので、Crashlytics プラグインが release の mapping.txt を
            // 自動アップロードする（mappingFileUploadEnabled はデフォルト true）。
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

androidComponents {
    onVariants { variant ->
        val isProdRelease = variant.buildType == "release" && variant.productFlavors.contains("env" to "prod")
        if (isProdRelease && !hasGoogleServicesJson && !allowMissingFirebaseConfig) {
            // onVariants の時点では変種のタスクがまだ無いので、生成されたときに割り込む。
            val preBuildTask = "pre${variant.name.replaceFirstChar { it.uppercase() }}Build"
            tasks.configureEach {
                if (name != preBuildTask) return@configureEach
                doFirst {
                    throw GradleException(
                        "google-services.json が無いため ${variant.name} をビルドできません。" +
                            "`scripts/firebase-config.sh pull prod android` で配置してください" +
                            "（Firebase 無しで試すだけなら -PallowMissingFirebaseConfig=true）"
                    )
                }
            }
        }
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

    // Firebase は BoM でバージョンを揃える。google-services.json が無くてもライブラリ自体は
    // 入れておき（コンパイルを通すため）、初期化の有無は実行時に FirebaseApp で判定する。
    implementation(platform(libs.firebase.bom))
    implementation(libs.firebase.analytics)
    implementation(libs.firebase.crashlytics)

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
