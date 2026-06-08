import AVFoundation

/// クイズの正解・不正解効果音を再生するプレイヤー。
/// 起動時にプレイヤーを生成してプリロードし、再生時のレイテンシを抑える。
final class SoundPlayer {
    static let shared = SoundPlayer()

    enum Effect: String {
        case correct
        case incorrect
    }

    /// 効果音の再生音量（0.0〜1.0）。少し控えめにする。
    private let volume: Float = 0.6

    private var players: [Effect: AVAudioPlayer] = [:]

    private init() {
        configureSession()
        preload(.correct)
        preload(.incorrect)
    }

    func play(_ effect: Effect) {
        guard let player = players[effect] else { return }
        player.currentTime = 0
        player.play()
    }

    private func preload(_ effect: Effect) {
        guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "mp3") else {
            return
        }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.volume = volume
        player?.prepareToPlay()
        players[effect] = player
    }

    private func configureSession() {
        // 他アプリの音楽とミックスし、消音スイッチを尊重する。
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    }
}
