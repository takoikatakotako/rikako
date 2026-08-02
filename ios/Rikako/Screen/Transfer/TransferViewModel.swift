import Foundation
import Observation

@Observable
@MainActor
final class TransferViewModel {
    var transferToken: TransferToken?
    var isLoading = false
    var errorMessage: String?
    var transferCompleted = false

    private let fetchTokenUseCase: FetchTransferTokenUseCase
    private let refreshTokenUseCase: RefreshTransferTokenUseCase
    private let applyTokenUseCase: ApplyTransferTokenUseCase
    private let deviceIdentityProvider: DeviceIdentityProviding

    init(
        fetchTokenUseCase: FetchTransferTokenUseCase,
        refreshTokenUseCase: RefreshTransferTokenUseCase,
        applyTokenUseCase: ApplyTransferTokenUseCase,
        deviceIdentityProvider: DeviceIdentityProviding
    ) {
        self.fetchTokenUseCase = fetchTokenUseCase
        self.refreshTokenUseCase = refreshTokenUseCase
        self.applyTokenUseCase = applyTokenUseCase
        self.deviceIdentityProvider = deviceIdentityProvider
    }

    func loadToken() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            transferToken = try await fetchTokenUseCase.execute()
        } catch {
            errorMessage = "引き継ぎコードの取得に失敗しました"
        }
    }

    func refreshToken() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            transferToken = try await refreshTokenUseCase.execute()
        } catch {
            errorMessage = "引き継ぎコードの更新に失敗しました"
        }
    }

    func applyToken(_ token: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let analytics = AppContainer.shared.analytics
        analytics.log(.transferStarted)
        do {
            let identityId = try await applyTokenUseCase.execute(token: token)
            deviceIdentityProvider.overrideIdentityId(identityId)
            transferCompleted = true
            analytics.log(.transferCompleted)
        } catch APIError.sameDevice {
            errorMessage = "このQRコードは同じデバイスで発行されています。別のデバイスのQRコードを読み取ってください"
            analytics.log(.transferFailed(reason: .unknown))
        } catch {
            errorMessage = "引き継ぎに失敗しました。コードが正しいか確認してください"
            analytics.log(.transferFailed(reason: AnalyticsFailureReason(error)))
        }
    }
}
