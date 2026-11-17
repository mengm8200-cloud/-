import AVFoundation
import CoreImage.CIFilterBuiltins
import SwiftUI
import Vision
import VisionKit

/// The QR code people scan to add each other: it only carries a chat ID.
enum FriendCode {
    private static let prefix = "xiaoliao://add/"

    static func payload(for username: String) -> String {
        prefix + username
    }

    /// Extracts the chat ID from a scanned code, or nil when the code is not one of ours.
    static func username(from payload: String) -> String? {
        let text = payload.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard text.hasPrefix(prefix) else { return nil }
        let name = String(text.dropFirst(prefix.count))
        guard name.range(of: "^[a-z0-9_]{3,20}$", options: .regularExpression) != nil else { return nil }
        return name
    }

    static func image(for payload: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        // The generator emits one pixel per module; scale it up so it stays sharp.
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)),
              let rendered = CIContext().createCGImage(output, from: output.extent)
        else { return nil }
        return UIImage(cgImage: rendered)
    }
}

/// Shows the signed-in user's own code for a friend to scan.
struct MyCodeView: View {
    @Environment(\.dismiss) private var dismiss
    let profile: Profile

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                HStack(spacing: 12) {
                    AvatarView(path: profile.avatarPath, name: profile.displayName, size: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.displayName)
                            .font(.title3.bold())
                        Text("聊天号：\(profile.username)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                if let code = FriendCode.image(for: FriendCode.payload(for: profile.username)) {
                    Image(uiImage: code)
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .padding(16)
                        // QR codes need dark modules on a light field to scan, in dark mode too.
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .frame(maxWidth: 280)
                        .accessibilityLabel("我的二维码")
                }
                Text("让朋友在「添加好友」里点扫一扫，对准这个二维码。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
            }
            .padding(24)
            .navigationTitle("我的二维码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

/// Camera sheet that reads a friend's code and reports the chat ID it contains.
struct CodeScannerSheet: View {
    private enum Access {
        case checking, ready, denied, unsupported
    }

    @Environment(\.dismiss) private var dismiss
    let onScan: (String) -> Void

    @State private var access: Access = .checking
    @State private var hint: String?

    var body: some View {
        NavigationStack {
            Group {
                switch access {
                case .checking:
                    ProgressView()
                case .ready:
                    CodeScanner(onPayload: handle)
                        .ignoresSafeArea(edges: .bottom)
                case .denied:
                    ContentUnavailableView(
                        "无法使用相机",
                        systemImage: "camera.fill",
                        description: Text("请在系统设置里允许使用相机，或者改为手动输入聊天号。")
                    )
                case .unsupported:
                    ContentUnavailableView(
                        "这台设备不支持扫码",
                        systemImage: "qrcode.viewfinder",
                        description: Text("可以改为手动输入对方的聊天号。")
                    )
                }
            }
            .overlay(alignment: .bottom) {
                if let hint {
                    Text(hint)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.7), in: Capsule())
                        .padding(.bottom, 32)
                }
            }
            .navigationTitle("扫一扫")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .task {
                guard DataScannerViewController.isSupported else {
                    access = .unsupported
                    return
                }
                access = await AVCaptureDevice.requestAccess(for: .video) ? .ready : .denied
            }
        }
    }

    private func handle(_ payload: String) {
        if let username = FriendCode.username(from: payload) {
            dismiss()
            onScan(username)
        } else {
            hint = "这不是好友二维码"
        }
    }
}

private struct CodeScanner: UIViewControllerRepresentable {
    let onPayload: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPayload: onPayload)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        // Scanning can only start once the controller is on screen; starting twice is harmless.
        try? scanner.startScanning()
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onPayload: (String) -> Void

        init(onPayload: @escaping (String) -> Void) {
            self.onPayload = onPayload
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            for item in addedItems {
                if case .barcode(let code) = item, let payload = code.payloadStringValue {
                    onPayload(payload)
                    return
                }
            }
        }
    }
}
