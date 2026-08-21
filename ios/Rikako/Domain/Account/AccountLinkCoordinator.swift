import Foundation
import Observation

/// `/account/link` が未完了かどうかを端末に残す。
/// ログイン成功時に立て、リンク成功で下ろす。アプリを再起動しても残るので、
/// 通信エラーなどでリンクに失敗したまま終了しても次回起動でやり直せる。
struct AccountLinkPendingStore {
    private let key = "jp.conol.rikako.accountLinkPending"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var isPending: Bool {
        // キーが無い状態でログイン済みなら、pending を持たない頃のビルドから
        // 持ち越した端末（リンク未実行）とみなす。新規インストールは未ログインなので
        // ensureLinked 側の判定で弾かれ、余計なリクエストにはならない。
        guard userDefaults.object(forKey: key) != nil else { return true }
        return userDefaults.bool(forKey: key)
    }

    func set(_ pending: Bool) {
        userDefaults.set(pending, forKey: key)
    }
}

/// 匿名データのアカウントへの紐付けを、成功するまで見届ける。
///
/// リンクが失敗したままだと、ログイン済みなので通常 API は canonical user を
/// 読み書きできる一方、**ログイン前にこの端末に溜まった学習記録だけが取り残される**。
/// ログイン直後に加えて、保存済みセッションで起動したときにも再試行する。
@Observable
@MainActor
final class AccountLinkCoordinator {
    enum State: Equatable {
        case idle
        case linking
        case failed
    }

    private(set) var state: State = .idle

    private let session: AccountSession
    private let pendingStore: AccountLinkPendingStore
    private let link: () async throws -> Void

    init(
        session: AccountSession,
        pendingStore: AccountLinkPendingStore,
        link: @escaping () async throws -> Void
    ) {
        self.session = session
        self.pendingStore = pendingStore
        self.link = link
    }

    /// 未完了のリンクがあれば実行する（冪等）。起動時とログイン直後の両方から呼ぶ。
    func ensureLinked() async {
        guard session.isLoggedIn, pendingStore.isPending, state != .linking else { return }

        state = .linking
        do {
            try await link()
            pendingStore.set(false)
            state = .idle
        } catch {
            // pending は落とさない。次回起動または明示的な再試行でやり直す。
            state = .failed
        }
    }

    /// 失敗表示からの明示的な再試行。
    func retry() async {
        guard state == .failed else { return }
        state = .idle
        await ensureLinked()
    }
}
