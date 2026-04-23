import Foundation

/// お知らせの既読状態を UserDefaults で管理する。
/// 「公開日から7日超過したものは自動的に既読扱い」のルールと組み合わせて未読を判定する。
final class AnnouncementReadStore {
    private let defaults: UserDefaults
    private let key = "announcementReadIds"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private var readIDs: Set<Int64> {
        get {
            let array = defaults.array(forKey: key) as? [NSNumber] ?? []
            return Set(array.map { $0.int64Value })
        }
        set {
            let array = newValue.map { NSNumber(value: $0) }
            defaults.set(array, forKey: key)
        }
    }

    func isRead(id: Int64) -> Bool {
        readIDs.contains(id)
    }

    func markRead(id: Int64) {
        var ids = readIDs
        ids.insert(id)
        readIDs = ids
    }

    /// 現在の announcement 一覧に存在しない ID を UserDefaults から削除する。
    /// 7日ルールで未読対象にならない古いIDが溜まり続けるのを防ぐ。
    func prune(existingIDs: Set<Int64>) {
        readIDs = readIDs.intersection(existingIDs)
    }
}
