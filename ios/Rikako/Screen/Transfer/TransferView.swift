import SwiftUI
import CoreImage.CIFilterBuiltins
import PhotosUI
import Vision
import UniformTypeIdentifiers
import AVFoundation

struct TransferView: View {
    @State private var viewModel: TransferViewModel
    @State private var selectedTab = 0
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

// MARK: - このデバイスから引き継ぐ（QRコード表示・書き出し）

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
                    if let expiresAt = viewModel.transferToken?.expiresAt {
                        Text("有効期限: \(expiresAt.formatted(.dateTime.year().month().day().locale(Locale(identifier: "ja_JP"))))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top)

                if viewModel.isLoading {
                    ProgressView()
                        .frame(width: 200, height: 200)
                } else if let token = viewModel.transferToken,
                          let qrImage = generateQRCode(from: token.token) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)

                    Text(token.token)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    ShareLink(
                        item: QRCodePNG(image: scaledQRCode(qrImage)),
                        preview: SharePreview("引き継ぎQRコード", image: Image(uiImage: qrImage))
                    ) {
                        Label("画像として書き出す", systemImage: "square.and.arrow.up")
                            .font(.subheadline)
                    }
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

// MARK: - 別のデバイスに引き継ぐ（QRスキャン・画像読み込み）

private struct ScanTokenView: View {
    var viewModel: TransferViewModel
    @State private var showScanner = false
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 80))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 8) {
                Text("旧デバイスのQRコードを読み取る")
                    .font(.headline)
                Text("引き継ぎ元のデバイスに表示されているQRコードをスキャン、または保存した画像から読み込んでください")
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

            VStack(spacing: 12) {
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

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("画像から読み込む", systemImage: "photo")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundStyle(Color.accentColor)
                        .cornerRadius(12)
                }
                .disabled(viewModel.isLoading)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .sheet(isPresented: $showScanner) {
            QRScannerView { token in
                showScanner = false
                Task { await viewModel.applyToken(token) }
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                await decodeQRFromPhoto(item)
                selectedPhoto = nil
            }
        }
    }

    private func decodeQRFromPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data),
              let cgImage = uiImage.cgImage else {
            viewModel.errorMessage = "画像の読み込みに失敗しました"
            return
        }

        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])

        guard let token = (request.results as? [VNBarcodeObservation])?
            .first(where: { $0.symbology == .qr })?
            .payloadStringValue else {
            viewModel.errorMessage = "QRコードが見つかりませんでした"
            return
        }

        await viewModel.applyToken(token)
    }
}

// MARK: - QRコード生成ヘルパー

private func generateQRCode(from string: String) -> UIImage? {
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(string.utf8)
    filter.correctionLevel = "M"
    guard let outputImage = filter.outputImage,
          let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }
    return UIImage(cgImage: cgImage)
}

private func scaledQRCode(_ source: UIImage, size: CGFloat = 1024) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
    return renderer.image { ctx in
        ctx.cgContext.interpolationQuality = .none
        source.draw(in: CGRect(origin: .zero, size: CGSize(width: size, height: size)))
    }
}

// MARK: - PNG書き出し用Transferable

private struct QRCodePNG: Transferable {
    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            item.image.pngData() ?? Data()
        }
    }
}

// MARK: - QRコードスキャナー（カメラ）

private struct QRScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        ScannerViewController(onScan: onScan)
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

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
