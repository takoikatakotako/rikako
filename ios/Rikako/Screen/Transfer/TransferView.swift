import SwiftUI
import CoreImage.CIFilterBuiltins

struct TransferView: View {
    @State private var viewModel: TransferViewModel
    @State private var selectedTab = 0
    @State private var showScanner = false
    @Environment(\.dismiss) private var dismiss

    init(viewModel: TransferViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("このデバイスから引き継ぐ").tag(0)
                Text("別のデバイスに引き継ぐ").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            if selectedTab == 0 {
                IssueTokenView(viewModel: viewModel)
            } else {
                ScanTokenView(viewModel: viewModel)
            }
        }
        .navigationTitle("データ引き継ぎ")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadToken() }
        .alert("引き継ぎ完了", isPresented: $viewModel.transferCompleted) {
            Button("OK") { dismiss() }
        } message: {
            Text("学習データを引き継ぎました。アプリを再起動するとデータが反映されます。")
        }
    }
}

// MARK: - このデバイスから引き継ぐ（QRコード表示）

private struct IssueTokenView: View {
    var viewModel: TransferViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("新しいデバイスでこのQRコードを読み取ってください")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text("有効期限: 3年間")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top)

                if viewModel.isLoading {
                    ProgressView()
                        .frame(width: 200, height: 200)
                } else if let token = viewModel.transferToken {
                    QRCodeView(content: token.token)
                        .frame(width: 200, height: 200)
                    Text(token.token)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await viewModel.refreshToken() }
                } label: {
                    Label("コードを更新する", systemImage: "arrow.clockwise")
                        .font(.subheadline)
                }
                .disabled(viewModel.isLoading)

                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - 別のデバイスに引き継ぐ（QRスキャン）

private struct ScanTokenView: View {
    var viewModel: TransferViewModel
    @State private var showScanner = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 80))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 8) {
                Text("旧デバイスのQRコードを読み取る")
                    .font(.headline)
                Text("引き継ぎ元のデバイスに表示されているQRコードをスキャンしてください")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Button {
                showScanner = true
            } label: {
                Group {
                    if viewModel.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Label("QRコードをスキャン", systemImage: "camera")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            .disabled(viewModel.isLoading)
            .padding(.horizontal, 32)

            Spacer()
        }
        .sheet(isPresented: $showScanner) {
            QRScannerView { token in
                showScanner = false
                Task { await viewModel.applyToken(token) }
            }
        }
    }
}

// MARK: - QRコード生成

private struct QRCodeView: View {
    let content: String

    var body: some View {
        if let image = generateQRCode(from: content) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - QRコードスキャナー

private struct QRScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        ScannerViewController(onScan: onScan)
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

import AVFoundation

private final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    let onScan: (String) -> Void
    private var captureSession: AVCaptureSession?

    init(onScan: @escaping (String) -> Void) {
        self.onScan = onScan
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCapture()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }

    private func setupCapture() {
        let session = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)

        captureSession = session
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue else { return }
        captureSession?.stopRunning()
        onScan(value)
    }
}

#Preview {
    NavigationStack {
        TransferView(
            viewModel: TransferViewModel(
                fetchTokenUseCase: PreviewAppContainer.makeLearningUseCases().fetchTransferToken,
                refreshTokenUseCase: PreviewAppContainer.makeLearningUseCases().refreshTransferToken,
                applyTokenUseCase: PreviewAppContainer.makeLearningUseCases().applyTransferToken,
                deviceIdentityProvider: PreviewDeviceIdentityProvider()
            )
        )
    }
}
