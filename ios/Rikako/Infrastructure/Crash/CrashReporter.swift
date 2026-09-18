import FirebaseCore
import FirebaseCrashlytics
import Foundation

/// Firebase Crashlytics の設定（#235）。
///
/// Firebase 自体の `configure` は `FirebaseAnalyticsClient.configured(slug:environment:)` が
/// 行うので、ここでは configure 済みであることを前提に Crashlytics 側の属性だけ整える。
/// dev(Debug) は `sandbox-492513`、prod(Release) は `rikako-prd` と Firebase プロジェクトが
/// 分かれているため、Debug ビルドでも収集は止めない（dev のクラッシュも見たい）。
///
/// - Note: クラッシュレポートに載せるのはアプリ種別など非 PII のキーのみ。
///   ユーザー入力・メールアドレス・Cognito Identity ID は**絶対に含めない**
///   （Analytics と同じ方針。`docs/ios.md` 参照）。
enum CrashReporter {
    /// `-crashlytics-test-crash` を起動引数に付けると DEBUG ビルドで起動直後に落とす。
    /// Crashlytics コンソールへの到達確認用。デバッガを外して起動すること
    /// （デバッガ接続中は Crashlytics がクラッシュを拾えない）。
    static let testCrashArgument = "-crashlytics-test-crash"

    static func configure(flavor: AppFlavor) {
        guard FirebaseApp.app() != nil else { return }
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.setCrashlyticsCollectionEnabled(true)
        crashlytics.setCustomValue(flavor.slug, forKey: "app_slug")

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains(testCrashArgument) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                fatalError("Crashlytics test crash (\(testCrashArgument))")
            }
        }
        #endif
    }
}
