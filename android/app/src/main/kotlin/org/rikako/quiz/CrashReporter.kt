package org.rikako.quiz

import android.content.Context
import com.google.firebase.FirebaseApp
import com.google.firebase.crashlytics.FirebaseCrashlytics

/**
 * Firebase Crashlytics の設定（#235）。iOS の `Infrastructure/Crash/CrashReporter.swift` に対応。
 *
 * Firebase の初期化は google-services.json から生成される設定で自動的に行われる。
 * json が無いビルド（CI や初回 clone 直後）では FirebaseApp が存在しないので何もしない。
 * dev / prod で Firebase プロジェクトが分かれているため、debug ビルドでも収集は止めない。
 *
 * クラッシュレポートに載せるのはアプリ種別など非 PII のキーのみ。
 * ユーザー入力・メールアドレス・Cognito Identity ID は絶対に含めない。
 */
object CrashReporter {
    /** debug ビルドでこの extra を付けて起動すると即クラッシュする（コンソール到達の確認用）。 */
    const val TEST_CRASH_EXTRA = "crashlytics_test_crash"

    fun configure(context: Context, flavor: AppFlavor) {
        if (FirebaseApp.getApps(context).isEmpty()) return
        FirebaseCrashlytics.getInstance().apply {
            isCrashlyticsCollectionEnabled = true
            setCustomKey("app_slug", flavor.slug)
        }
    }

    /** `adb shell am start -n <applicationId>/org.rikako.quiz.MainActivity --ez crashlytics_test_crash true` */
    fun crashIfRequested(extras: android.os.Bundle?) {
        if (!BuildConfig.DEBUG) return
        if (extras?.getBoolean(TEST_CRASH_EXTRA) == true) {
            throw IllegalStateException("Crashlytics test crash ($TEST_CRASH_EXTRA)")
        }
    }
}
