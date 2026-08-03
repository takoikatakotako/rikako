import Foundation

enum Links {
    static let termsOfService = URL(string: "https://rikako.org/terms")!
    static let privacyPolicy = URL(string: "https://rikako.org/privacy")!
    // App Store URL はフレーバー別のため AppFlavor.current.appStoreURL を使う。
}
