import SwiftUI
import CoreImage.CIFilterBuiltins
import PhotosUI
import Photos
import Vision
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
    @State private var saveMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("新しいデバイスでこのQRコードを読み取ってください")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if let expiresAt = viewModel.transferToken?.expiresAt {
                        Text("有効期限: \(expiresAt.formatted(.dateTime.year().month().day().hour().minute().locale(Locale(identifier: "ja_JP"))))")
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

                    Button {
                        Task { await saveQRToPhotos(makeTransferCardImage(qrSource: qrImage, expiresAt: token.expiresAt, userId: AppState.shared.userId)) }
                    } label: {
                        Label("写真に保存", systemImage: "photo.badge.plus")
                            .font(.subheadline)
                    }

                    if let msg = saveMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(msg.contains("失敗") ? .red : .green)
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

    private func saveQRToPhotos(_ image: UIImage) async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            saveMessage = "写真への保存が許可されていません"
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            saveMessage = "写真に保存しました"
        } catch {
            saveMessage = "保存に失敗しました"
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

        guard let token = request.results?
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

private func makeTransferCardImage(qrSource: UIImage, expiresAt: Date, userId: Int64?) -> UIImage {
    let w: CGFloat = 800
    let h: CGFloat = 1060
    let accentColor = UIColor(named: "main") ?? .systemGreen

    let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
    return renderer.image { ctx in
        let cg = ctx.cgContext

        // 白背景
        UIColor.white.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: w, height: h))

        // ── ヘッダー ─────────────────────────────────
        let headerH: CGFloat = 190
        accentColor.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: w, height: headerH))

        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Rikako"
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 46),
            .foregroundColor: UIColor.white
        ]
        let nameStr = appName as NSString
        let nameSize = nameStr.size(withAttributes: nameAttrs)
        nameStr.draw(at: CGPoint(x: (w - nameSize.width) / 2, y: 48), withAttributes: nameAttrs)

        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 26),
            .foregroundColor: UIColor.white.withAlphaComponent(0.88)
        ]
        let subStr = "データ引き継ぎQRコード" as NSString
        let subSize = subStr.size(withAttributes: subAttrs)
        subStr.draw(at: CGPoint(x: (w - subSize.width) / 2, y: 116), withAttributes: subAttrs)

        // ── QRカード ─────────────────────────────────
        let pad: CGFloat = 64
        let qrSide = w - pad * 2   // 672
        let qrY: CGFloat = headerH + 36

        // 外枠（薄グレー）→ 内側白
        let cardOuter = CGRect(x: pad - 16, y: qrY - 16, width: qrSide + 32, height: qrSide + 32)
        UIColor(white: 0.92, alpha: 1).setFill()
        UIBezierPath(roundedRect: cardOuter, cornerRadius: 24).fill()
        UIColor.white.setFill()
        UIBezierPath(roundedRect: cardOuter.insetBy(dx: 3, dy: 3), cornerRadius: 22).fill()

        // QRコード描画
        cg.interpolationQuality = .none
        qrSource.draw(in: CGRect(x: pad, y: qrY, width: qrSide, height: qrSide))

        // ── フッター ─────────────────────────────────
        let footerY = qrY + qrSide + 44

        let df = DateFormatter()
        df.locale = Locale(identifier: "ja_JP")
        df.dateFormat = "yyyy年M月d日 HH:mm まで有効"

        let expiresAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 22, weight: .regular),
            .foregroundColor: UIColor(white: 0.35, alpha: 1)
        ]
        let expiresStr = df.string(from: expiresAt) as NSString
        let expiresSize = expiresStr.size(withAttributes: expiresAttrs)
        expiresStr.draw(at: CGPoint(x: (w - expiresSize.width) / 2, y: footerY), withAttributes: expiresAttrs)

        if let uid = userId {
            let idAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 20, weight: .regular),
                .foregroundColor: UIColor(white: 0.5, alpha: 1)
            ]
            let idStr = "ユーザーID: \(uid)" as NSString
            let idSize = idStr.size(withAttributes: idAttrs)
            idStr.draw(at: CGPoint(x: (w - idSize.width) / 2, y: footerY + 34), withAttributes: idAttrs)
        }

        let instrAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20),
            .foregroundColor: UIColor(white: 0.6, alpha: 1)
        ]
        let instrStr = "新しいデバイスのカメラで読み取ってください" as NSString
        let instrSize = instrStr.size(withAttributes: instrAttrs)
        instrStr.draw(at: CGPoint(x: (w - instrSize.width) / 2, y: footerY + 68), withAttributes: instrAttrs)
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

#Preview("保存カード", traits: .fixedLayout(width: 400, height: 500)) {
    let qr = generateQRCode(from: "preview-token-abcdef1234567890") ?? UIImage()
    let card = makeTransferCardImage(qrSource: qr, expiresAt: Date().addingTimeInterval(3 * 365 * 24 * 3600), userId: 12345)
    Image(uiImage: card)
        .resizable()
        .scaledToFit()
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
