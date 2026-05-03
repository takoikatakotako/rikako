import Foundation
import Observation

@Observable
@MainActor
final class TransferViewModel {
    var transferToken: TransferToken?
    var deviceIdentityId: String?
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
            deviceIdentityId = try? await deviceIdentityProvider.getIdentityId()
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
        do {
            let identityId = try await applyTokenUseCase.execute(token: token)
            deviceIdentityProvider.overrideIdentityId(identityId)
            transferCompleted = true
        } catch APIError.sameDevice {
            errorMessage = "このQRコードは同じデバイスで発行されています。別のデバイスのQRコードを読み取ってください"
        } catch {
            errorMessage = "引き継ぎに失敗しました。コードが正しいか確認してください"
        }
    }
}
