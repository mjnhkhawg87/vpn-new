import UIKit
import SwiftUI
import CryptoKit

private enum FFH4XLicenseConfig {
    static let storedKey = "FFH4X_LICENSE_KEY"

    // Client-side obfuscation: these values are not stored as plain URLs.
    // Note: this is obfuscation, not cryptographic secrecy; a determined
    // reverse engineer can still recover runtime values.
    private static let validateBlob = "X0NDR0QNGBhZWlxeWERBWRpWR14ZWVpcDwAFBwYZQFhFXFJFRBlTUkEYQVZbXlNWQ1I="
    private static let purchaseBlob = "ydXV0dKbjo7Vj8zEjszIz8nKycDPxsnA2Q=="
    private static let authorTelegramBlob = "NSkpLS5ncnIpczA4cjA0MzU2NTwzOjU8JQ=="
    private static let channelTelegramBlob = "q7e3s7D57Oy37a6m7K6qrauoq6KtpKuiuw=="
    private static let authorZaloBlob = "GQUFAQJLXl4LEB0eXxwUXkFJR0hHRUBJSEk="
    private static let groupZaloBlob = "++fn4+CpvLzp8v/8vf72vPS89Kvq6uXh/ean4vX25Kb48fCj++U="

    private static let validateKey: UInt8 = 0x37
    private static let purchaseKey: UInt8 = 0xA1
    private static let authorKey: UInt8 = 0x5D
    private static let channelKey: UInt8 = 0xC3
    private static let authorZaloKey: UInt8 = 0x71
    private static let groupZaloKey: UInt8 = 0x93

    private static func decode(_ blob: String, key: UInt8) -> URL {
        guard let data = Data(base64Encoded: blob) else {
            return URL(string: "about:blank")!
        }

        let bytes = data.map { $0 ^ key }

        guard let string = String(bytes: bytes, encoding: .utf8),
              let url = URL(string: string) else {
            return URL(string: "about:blank")!
        }

        return url
    }

    static var validateURL: URL {
        decode(validateBlob, key: validateKey)
    }

    static var purchaseURL: URL {
        decode(purchaseBlob, key: purchaseKey)
    }

    static var authorTelegramURL: URL {
        decode(authorTelegramBlob, key: authorKey)
    }

    static var channelTelegramURL: URL {
        decode(channelTelegramBlob, key: channelKey)
    }

    static var authorZaloURL: URL {
        decode(authorZaloBlob, key: authorZaloKey)
    }

    static var groupZaloURL: URL {
        decode(groupZaloBlob, key: groupZaloKey)
    }
}

private struct FFH4XLicenseResponse: Decodable {
    let valid: Bool
    let message: String?
    let expiresAt: String?
}

private enum FFH4XLicenseError: LocalizedError {
    case invalidResponse
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Không nhận được phản hồi hợp lệ từ máy chủ."

        case .network(let message):
            return message
        }
    }
}

@MainActor
private final class FFH4XLicenseService {
    static let shared = FFH4XLicenseService()

    private init() {}

    private var deviceIdentifier: String {
        if let id = UIDevice.current.identifierForVendor?.uuidString,
           !id.isEmpty {
            return id
        }

        let fallbackKey = "FFH4X_FALLBACK_DEVICE_ID"

        if let saved = UserDefaults.standard.string(forKey: fallbackKey),
           !saved.isEmpty {
            return saved
        }

        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: fallbackKey)

        return generated
    }

    var currentDeviceIdentifier: String {
        deviceIdentifier
    }

    func validate(key: String) async throws -> FFH4XLicenseResponse {
        let cleanedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedKey.isEmpty else {
            throw FFH4XLicenseError.network(
                "Vui lòng nhập license key."
            )
        }

        var request = URLRequest(url: FFH4XLicenseConfig.validateURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: String] = [
            "key": cleanedKey,
            "udid": deviceIdentifier
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw FFH4XLicenseError.invalidResponse
            }

            let rawBody = String(data: data, encoding: .utf8) ?? "<non-UTF8 response>"

            print("LICENSE STATUS:", httpResponse.statusCode)
            print("LICENSE RESPONSE:", rawBody)

            switch httpResponse.statusCode {
case 400:
    throw FFH4XLicenseError.network(
        "Key không tồn tại."
    )

case 404:
    throw FFH4XLicenseError.network(
        "Key không tồn tại."
    )

case 200...299:
    break

default:
    throw FFH4XLicenseError.network(
        "Máy chủ trả HTTP \(httpResponse.statusCode)."
    )
}

            guard let decoded = try? JSONDecoder().decode(
                FFH4XLicenseResponse.self,
                from: data
            ) else {
                throw FFH4XLicenseError.invalidResponse
            }

            return decoded

        } catch let error as FFH4XLicenseError {
            throw error
        } catch let error as URLError {
            print("LICENSE NETWORK ERROR:", error.code.rawValue, error.localizedDescription)
            throw FFH4XLicenseError.network(
                "Không thể kết nối máy chủ (\(error.code.rawValue)). Kiểm tra Internet rồi thử lại."
            )
        } catch {
            print("LICENSE ERROR:", error)
            throw FFH4XLicenseError.network(
                "Không thể kết nối máy chủ. Kiểm tra Internet rồi thử lại."
            )
        }
    }
}



private func deviceModelName() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)

    let identifier = withUnsafeBytes(of: &systemInfo.machine) {
        String(bytes: $0, encoding: .ascii)?
            .trimmingCharacters(in: .controlCharacters)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    } ?? ""

    let models: [String: String] = [

        // MARK: - iPhone 11

        "iPhone12,1": "iPhone 11",
        "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max",


        // MARK: - iPhone SE

        "iPhone12,8": "iPhone SE (2nd generation)",
        "iPhone14,6": "iPhone SE (3rd generation)",


        // MARK: - iPhone 12

        "iPhone13,1": "iPhone 12 mini",
        "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",


        // MARK: - iPhone 13

        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,5": "iPhone 13",
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",


        // MARK: - iPhone 14

        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",


        // MARK: - iPhone 15

        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",


        // MARK: - iPhone 16

        "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus",
        "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,5": "iPhone 16e",


        // MARK: - iPhone 17

        "iPhone18,3": "iPhone 17",
        "iPhone18,1": "iPhone 17 Pro",
        "iPhone18,2": "iPhone 17 Pro Max",
        "iPhone18,4": "iPhone Air",
        "iPhone18,5": "iPhone 17e"
    ]

    return models[identifier] ?? identifier
}

private extension Notification.Name {
    static let ffh4xLicenseDidDelete = Notification.Name("FFH4XLicenseDidDelete")
    static let ffh4xStatusDidChange = Notification.Name("FFH4XStatusDidChange")
}

// MARK: - License Gate

@MainActor
private struct FFH4XLicenseGate<Content: View>: View {

    private let content: () -> Content

    init(
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.content = content
    }

    @AppStorage(FFH4XLicenseConfig.storedKey)
    private var savedKey = ""

    @State private var isLicensed = false

    @State private var isShowingKeyAlert = false

    @State private var keyInput = ""

    @State private var alertMessage =
        "Nhập license key để tiếp tục."

    @State private var isChecking = false

    @State private var shake = false

    @State private var successPulse = false

    // Popup thành công
    @State private var showSuccessPopup = false

    @State private var successMessage = ""

    @State private var successExpiresAt = ""
    @State private var successDeviceName = ""
    @State private var successIOSVersion = ""

    var body: some View {
        ZStack {

            if isLicensed {
                content()
            } else {
                AppTheme.pageBackground
                    .ignoresSafeArea()
            }

            // MARK: Key Popup

            if isShowingKeyAlert {

                Color.black
                    .opacity(0.34)
                    .ignoresSafeArea()
                    .transition(.opacity)

                FFH4XLicenseAlert(
                    keyInput: $keyInput,
                    message: alertMessage,
                    isChecking: isChecking,
                    shake: shake,

                    onPurchase: {
                        UIApplication.shared.open(
                            FFH4XLicenseConfig.purchaseURL
                        )
                    },

                    onSubmit: {
                        Task {
                            await submitKey()
                        }
                    }
                )
                .padding(.horizontal, 18)
                .transition(
                    .asymmetric(
                        insertion:
                            .scale(scale: 0.90)
                            .combined(with: .opacity),

                        removal:
                            .scale(scale: 0.96)
                            .combined(with: .opacity)
                    )
                )
                .zIndex(100)
            }

            // MARK: Success Popup

            if showSuccessPopup {

                Color.black
                    .opacity(0.34)
                    .ignoresSafeArea()
                    .transition(.opacity)

                FFH4XLicenseSuccessAlert(
                    message: successMessage,
                    expiresAt: successExpiresAt,
                    deviceName: successDeviceName,
                    iosVersion: successIOSVersion
                )
                .padding(.horizontal, 18)
                .transition(
                    .asymmetric(
                        insertion:
                            .scale(scale: 0.90)
                            .combined(with: .opacity),

                        removal:
                            .scale(scale: 0.96)
                            .combined(with: .opacity)
                    )
                )
                .zIndex(200)
            }
        }

        .overlay {
            if successPulse {
                Circle()
                    .fill(
                        AppTheme.accent.opacity(0.12)
                    )
                    .frame(
                        width: 180,
                        height: 180
                    )
                    .scaleEffect(
                        successPulse
                        ? 1.55
                        : 0.65
                    )
                    .opacity(
                        successPulse
                        ? 0.0
                        : 0.85
                    )
                    .allowsHitTesting(false)
            }
        }

        .animation(
            .spring(
                response: 0.42,
                dampingFraction: 0.84
            ),
            value: isShowingKeyAlert
        )

        .animation(
            .spring(
                response: 0.42,
                dampingFraction: 0.84
            ),
            value: showSuccessPopup
        )

        .onAppear {
            checkSavedKeyOrPresentAlert()
        }
        .onReceive(NotificationCenter.default.publisher(for: .ffh4xLicenseDidDelete)) { _ in
            // Settings đã xóa key: khóa app ngay và đưa người dùng về màn hình nhập key.
            savedKey = ""
            keyInput = ""
            isLicensed = false
            isChecking = false
            showSuccessPopup = false
            alertMessage = "License key đã được xóa. Vui lòng nhập key mới để tiếp tục."
            presentKeyAlert(after: 0.12)
        }
    }

    // MARK: Check Saved Key

    @MainActor
    private func checkSavedKeyOrPresentAlert() {

        guard !isLicensed else {
            return
        }

        let key = savedKey.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !key.isEmpty else {

            alertMessage =
                "Nhập license key để tiếp tục."

            presentKeyAlert(after: 0.22)

            return
        }

        Task {
            do {
                let result =
                    try await FFH4XLicenseService.shared.validate(
                        key: key
                    )

                if result.valid {

                    isLicensed = true

                } else {

                    savedKey = ""
                    keyInput = ""

                    alertMessage =
                        result.message ??
                        "Key không hợp lệ."

                    presentKeyAlert(after: 0.12)
                }

            } catch {

                alertMessage =
                    error.localizedDescription

                presentKeyAlert(after: 0.12)
            }
        }
    }

    // MARK: Submit Key

    private func submitKey() async {

        let key =
            keyInput.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !key.isEmpty,
              !isChecking else {
            return
        }

        // Bắt đầu xác thực
        isChecking = true

        alertMessage =
            "Đang xác thực key..."

        do {

            let result =
                try await FFH4XLicenseService.shared.validate(
                    key: key
                )

            isChecking = false

            // MARK: Valid

            if result.valid {

                // Lưu key để lần sau tự kiểm tra
                savedKey = key

                // Thông tin thiết bị hiển thị trong success popup.
                successDeviceName = deviceModelName()
                successIOSVersion = UIDevice.current.systemVersion

                // Tuyệt đối không đưa key vào popup thành công
                successMessage =
                    result.message ??
                    "License key đã được xác thực thành công."

                successExpiresAt =
                    result.expiresAt ?? ""

                // Đóng popup nhập key
                withAnimation(
                    .spring(
                        response: 0.42,
                        dampingFraction: 0.84
                    )
                ) {
                    isShowingKeyAlert = false
                }

                // Hiện popup thành công
                try? await Task.sleep(
                    for: .milliseconds(180)
                )

                withAnimation(
                    .spring(
                        response: 0.42,
                        dampingFraction: 0.84
                    )
                ) {
                    showSuccessPopup = true
                }

                // Giữ popup thành công
                try? await Task.sleep(
                    for: .seconds(2.2)
                )

                // Đóng popup
                withAnimation(
                    .spring(
                        response: 0.42,
                        dampingFraction: 0.84
                    )
                ) {
                    showSuccessPopup = false
                }

                try? await Task.sleep(
                    for: .milliseconds(300)
                )

                // Pulse
                successPulse = true

                withAnimation(
                    .spring(
                        response: 0.44,
                        dampingFraction: 0.84
                    )
                ) {
                    isLicensed = true
                }

                try? await Task.sleep(
                    for: .milliseconds(180)
                )

                successPulse = false

            } else {

                // MARK: Invalid

                savedKey = ""

                alertMessage =
                    result.message ??
                    "Key không hợp lệ."

                await triggerErrorFeedback()
            }

        } catch {

            isChecking = false

            alertMessage =
                error.localizedDescription

            await triggerErrorFeedback()
        }
    }

    // MARK: Error Animation

    @MainActor
    private func triggerErrorFeedback() async {

        withAnimation(
            .easeInOut(duration: 0.08)
        ) {
            shake = true
        }

        try? await Task.sleep(
            for: .milliseconds(220)
        )

        withAnimation(
            .easeInOut(duration: 0.08)
        ) {
            shake = false
        }
    }

    // MARK: Present Alert

    @MainActor
    private func presentKeyAlert(
        after delay: TimeInterval
    ) {

        isShowingKeyAlert = false

        DispatchQueue.main.asyncAfter(
            deadline: .now() + delay
        ) {

            withAnimation(
                .spring(
                    response: 0.42,
                    dampingFraction: 0.84
                )
            ) {
                self.isShowingKeyAlert = true
            }
        }
    }
}

// MARK: - License Alert

private struct FFH4XLicenseAlert: View {

    @Binding var keyInput: String

    let message: String
    let isChecking: Bool
    let shake: Bool

    let onPurchase: () -> Void
    let onSubmit: () -> Void

    @FocusState private var isKeyFocused: Bool

    private var trimmedKey: String {
        keyInput.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    var body: some View {

        VStack(spacing: 0) {

            // MARK: Header

            ZStack {

                RoundedRectangle(
                    cornerRadius: 28,
                    style: .continuous
                )
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.accent.opacity(0.20),
                            AppTheme.accent.opacity(0.05),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

                HStack(spacing: 13) {

                    ZStack {

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        AppTheme.accent,
                                        AppTheme.accent.opacity(0.58)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Image(
                            systemName:
                                isChecking
                                ? "arrow.triangle.2.circlepath"
                                : "key.fill"
                        )
                        .font(
                            .system(
                                size: 25,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(.white)
                        .rotationEffect(
                            .degrees(
                                isChecking
                                ? 360
                                : 0
                            )
                        )
                        .animation(
                            isChecking
                            ? Animation
                                .linear(duration: 0.9)
                                .repeatForever(
                                    autoreverses: false
                                )
                            : .default,
                            value: isChecking
                        )
                    }
                    .frame(
                        width: 60,
                        height: 60
                    )
                    .shadow(
                        color:
                            AppTheme.accent.opacity(0.26),
                        radius: 18,
                        y: 8
                    )

                    VStack(
                        alignment: .leading,
                        spacing: 4
                    ) {

                        Text("FFH4X License")
                            .font(
                                .system(
                                    size: 24,
                                    weight: .bold,
                                    design: .rounded
                                )
                            )

                        Text("Minh Khang")
                            .font(
                                .caption.weight(.semibold)
                            )
                            .foregroundStyle(
                                AppTheme.accent
                            )

                        Text("")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
            .frame(height: 92)

            // MARK: Body

            VStack(spacing: 14) {

                HStack(spacing: 9) {

                    Image(
                        systemName:
                            isChecking
                            ? "arrow.triangle.2.circlepath"
                            : "info.circle.fill"
                    )
                    .font(
                        .caption.weight(.semibold)
                    )
                    .foregroundStyle(
                        AppTheme.accent
                    )

                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(
                    AppTheme.accent.opacity(0.07),
                    in:
                        RoundedRectangle(
                            cornerRadius: 13,
                            style: .continuous
                        )
                )

                // MARK: Key Input

                HStack(spacing: 11) {

                    Image(
                        systemName:
                            "key.horizontal.fill"
                    )
                    .font(
                        .body.weight(.semibold)
                    )
                    .foregroundStyle(
                        isKeyFocused
                        ? AppTheme.accent
                        : .secondary
                    )

                    // SecureField:
                    // key sẽ hiển thị dạng •••••
                    SecureField(
                        "",
                        text: $keyInput
                    )
                    .textInputAutocapitalization(
                        .characters
                    )
                    .autocorrectionDisabled(true)
                    .textFieldStyle(.plain)
                    .font(
                        .system(
                            .body,
                            design: .monospaced
                        )
                    )
                    .focused(
                        $isKeyFocused
                    )
                    .submitLabel(.done)
                    .onSubmit {

                        if !trimmedKey.isEmpty {
                            onSubmit()
                        }
                    }

                    if !keyInput.isEmpty &&
                        !isChecking {

                        Button {

                            keyInput = ""

                            isKeyFocused = true

                        } label: {

                            Image(
                                systemName:
                                    "xmark.circle.fill"
                            )
                            .foregroundStyle(
                                .tertiary
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 15)
                .frame(height: 56)
                .background(
                    .ultraThinMaterial,
                    in:
                        RoundedRectangle(
                            cornerRadius: 17,
                            style: .continuous
                        )
                )
                .overlay {

                    RoundedRectangle(
                        cornerRadius: 17,
                        style: .continuous
                    )
                    .strokeBorder(
                        isKeyFocused
                        ? AppTheme.accent.opacity(0.58)
                        : Color.primary.opacity(0.08),

                        lineWidth:
                            isKeyFocused
                            ? 1.4
                            : 1
                    )
                }
                .offset(
                    x: shake
                    ? -7
                    : 0
                )
                .animation(
                    .easeInOut(
                        duration: 0.07
                    )
                    .repeatCount(
                        5,
                        autoreverses: true
                    ),
                    value: shake
                )

                // MARK: Buttons

                HStack(spacing: 10) {

                    Button(
                        action: onPurchase
                    ) {

                        HStack(spacing: 7) {

                            Image(
                                systemName:
                                    "paperplane.fill"
                            )

                            Text("Mua key")
                        }
                        .font(
                            .subheadline.weight(
                                .semibold
                            )
                        )
                        .frame(
                            maxWidth: .infinity
                        )
                        .frame(height: 49)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.accent)

                    Button(
                        action: onSubmit
                    ) {

                        HStack(spacing: 7) {

                            if isChecking {

                                ProgressView()
                                    .tint(.white)

                                Text(
                                    "Đang xác thực..."
                                )

                            } else {

                                Image(
                                    systemName:
                                        "checkmark.circle.fill"
                                )

                                Text("Xác nhận")
                            }
                        }
                        .font(
                            .subheadline.weight(
                                .bold
                            )
                        )
                        .frame(
                            maxWidth: .infinity
                        )
                        .frame(height: 49)
                    }
                    .buttonStyle(
                        .borderedProminent
                    )
                    .tint(AppTheme.accent)
                    .disabled(
                        isChecking ||
                        trimmedKey.isEmpty
                    )
                }

                HStack(spacing: 6) {

                    Image(
                        systemName:
                            "lock.shield.fill"
                    )

                    Text(
                        "Mua Key nhắn tin cho mình."
                    )
                }
                .font(
                    .caption2.weight(.medium)
                )
                .foregroundStyle(.tertiary)
                .padding(.top, 1)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 18)
        }
        .background(
            .regularMaterial,
            in:
                RoundedRectangle(
                    cornerRadius: 30,
                    style: .continuous
                )
        )
        .overlay {

            RoundedRectangle(
                cornerRadius: 30,
                style: .continuous
            )
            .strokeBorder(
                Color.white.opacity(0.16),
                lineWidth: 1
            )
        }
        .shadow(
            color: .black.opacity(0.24),
            radius: 34,
            y: 18
        )
        .onAppear {

            DispatchQueue.main.asyncAfter(
                deadline:
                    .now() + 0.30
            ) {

                isKeyFocused = true
            }
        }
    }
}

// MARK: - Success Alert

private struct FFH4XLicenseSuccessAlert: View {

    let message: String
    let expiresAt: String
    let deviceName: String
    let iosVersion: String

    @State private var checkScale: CGFloat = 0.72
    @State private var checkOpacity: Double = 0
    @State private var cardOpacity: Double = 0
    @State private var cardOffset: CGFloat = 18

    var body: some View {

        VStack(spacing: 0) {

            VStack(spacing: 13) {

                ZStack {

                    Circle()
                        .fill(Color.green.opacity(0.10))
                        .frame(width: 92, height: 92)

                    Circle()
                        .stroke(
                            Color.green.opacity(0.20),
                            lineWidth: 1.5
                        )
                        .frame(width: 92, height: 92)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.green,
                                    Color.green.opacity(0.72)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 62, height: 62)
                        .shadow(
                            color: Color.green.opacity(0.28),
                            radius: 18,
                            y: 8
                        )

                    Image(systemName: "checkmark")
                        .font(
                            .system(size: 29, weight: .bold)
                        )
                        .foregroundStyle(.white)
                        .scaleEffect(checkScale)
                        .opacity(checkOpacity)
                }

                Text("Xác thực thành công")
                    .font(
                        .system(
                            size: 25,
                            weight: .bold,
                            design: .rounded
                        )
                    )

                Text("License đã được kích hoạt")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 26)
            .padding(.bottom, 20)

            VStack(spacing: 0) {

                successInfoRow(
                    icon: "calendar.badge.checkmark",
                    title: "Hạn sử dụng",
                    value: formattedExpiry(expiresAt)
                )

                Divider()
                    .padding(.vertical, 12)

                successInfoRow(
                    icon: "iphone",
                    title: "Thiết bị",
                    value: deviceName.isEmpty ? "Thiết bị của bạn" : deviceName
                )

                Divider()
                    .padding(.vertical, 12)

                successInfoRow(
                    icon: "gearshape.fill",
                    title: "Phiên bản iOS",
                    value: "iOS \(iosVersion)"
                )
            }
            .padding(16)
            .background(
                Color.primary.opacity(0.045),
                in: RoundedRectangle(
                    cornerRadius: 20,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 20,
                    style: .continuous
                )
                .strokeBorder(
                    Color.primary.opacity(0.06),
                    lineWidth: 1
                )
            }
            .padding(.horizontal, 18)

            if !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 24)
                    .padding(.top, 14)
            }

            HStack(spacing: 7) {
                ProgressView()
                    .controlSize(.small)

                Text("Đang mở ứng dụng...")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 15)
            .padding(.bottom, 23)
        }
        .background(
            .regularMaterial,
            in: RoundedRectangle(
                cornerRadius: 30,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 30,
                style: .continuous
            )
            .strokeBorder(
                Color.white.opacity(0.16),
                lineWidth: 1
            )
        }
        .shadow(
            color: .black.opacity(0.24),
            radius: 34,
            y: 18
        )
        .opacity(cardOpacity)
        .offset(y: cardOffset)
        .onAppear {
            withAnimation(
                .spring(response: 0.48, dampingFraction: 0.78)
            ) {
                cardOpacity = 1
                cardOffset = 0
                checkScale = 1
                checkOpacity = 1
            }
        }
    }

    @ViewBuilder
    private func successInfoRow(
        icon: String,
        title: String,
        value: String
    ) -> some View {

        HStack(spacing: 12) {

            ZStack {
                RoundedRectangle(
                    cornerRadius: 12,
                    style: .continuous
                )
                .fill(Color.green.opacity(0.08))

                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.green)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)
        }
    }

    private func formattedExpiry(_ value: String) -> String {
        guard !value.isEmpty else {
            return "Vĩnh viễn"
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let date = iso.date(from: value) ?? ISO8601DateFormatter().date(from: value)

        guard let date else {
            return value
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Content


// MARK: - Remote App Status

private struct FFH4XAppStatus: Decodable {
    // Optional để JSON cũ vẫn đọc được.
    // Việc phát hiện JSON thay đổi thực tế dùng SHA-256 của toàn bộ payload.
    let version: String?

    struct Maintenance: Decodable {
        let enabled: Bool
        let title: String
        let message: String
    }

    struct Update: Decodable {
        let enabled: Bool
        let version: String
        let title: String
        let message: String
        let downloadURL: String
        let force: Bool
    }

    let maintenance: Maintenance
    let update: Update
}

@MainActor
private final class FFH4XAppStatusService: ObservableObject {
    static let shared = FFH4XAppStatusService()

    @Published private(set) var status: FFH4XAppStatus?
    @Published private(set) var isLoading = false

    private let fingerprintKey = "FFH4X_STATUS_JSON_FINGERPRINT"

    private init() {}

    private let statusBlob = "Ax8fGxhRREQZChxFDAIfAx4JHhgOGQgEBR8OBR9FCAQGRAYCBQMAAwoFDFMfA1xEJQweEg4FJgIFAyADCgUMRBkODRhEAw4KDxhEBgoCBUQCOypEJQYAAiQ4PSVEGB8KHx4YRQEYBAU="
    private let statusKey: UInt8 = 0x6B

    private var statusURL: URL? {
        guard let data = Data(base64Encoded: statusBlob) else {
            return nil
        }

        let bytes = data.map { $0 ^ statusKey }
        guard let string = String(bytes: bytes, encoding: .utf8) else {
            return nil
        }

        return URL(string: string)
    }

    func refresh() async {
        guard let baseURL = statusURL else { return }

        isLoading = true
        defer { isLoading = false }

        // Không giữ trạng thái cũ khi refresh.
        // Nếu server đã tắt maintenance/update thì UI phải
        // được phép biến mất ngay sau khi JSON mới được đọc.
        status = nil

        // Luôn tạo URL mới để tránh CDN/URLCache trả lại status.json cũ.
        var components = URLComponents(
            url: baseURL,
            resolvingAgainstBaseURL: false
        )

        // Tách queryItems ra biến riêng để tránh
        // Swift báo lỗi overlapping accesses.
        var queryItems = components?.queryItems ?? []

        // Cache-buster mạnh: timestamp mili-giây + UUID mới mỗi request.
        queryItems.append(
            URLQueryItem(
                name: "_t",
                value: String(Date().timeIntervalSince1970 * 1000)
            )
        )
        queryItems.append(
            URLQueryItem(
                name: "_r",
                value: UUID().uuidString
            )
        )

        components?.queryItems = queryItems

        guard let url = components?.url else {
            print("APP STATUS ERROR: invalid status URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15

        // Force refresh: bỏ toàn bộ cache cục bộ.
        URLCache.shared.removeCachedResponse(for: request)
        URLCache.shared.removeAllCachedResponses()
        request.cachePolicy = .reloadIgnoringLocalCacheData

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )
        request.setValue(
            "no-cache, no-store, max-age=0",
            forHTTPHeaderField: "Cache-Control"
        )
        request.setValue(
            "no-cache",
            forHTTPHeaderField: "Pragma"
        )

        do {
            // Ephemeral session: không dùng persistent URL cache/cookie.
            let configuration = URLSessionConfiguration.ephemeral
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.urlCache = nil
            configuration.httpShouldSetCookies = false
            let session = URLSession(configuration: configuration)

            let (data, response) =
                try await session.data(for: request)

            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                print(
                    "APP STATUS HTTP ERROR:",
                    (response as? HTTPURLResponse)?.statusCode ?? -1
                )
                return
            }

            let decoded = try JSONDecoder().decode(
                FFH4XAppStatus.self,
                from: data
            )

            // ----------------------------------------------------
            // PHÁT HIỆN JSON THAY ĐỔI
            // ----------------------------------------------------
            // Không dựa vào URL cache hoặc chỉ dựa vào version app.
            // Mỗi payload JSON được băm SHA-256. Chỉ cần JSON đổi
            // một ký tự cũng sẽ tạo fingerprint mới.
            let fingerprint = SHA256.hash(data: data)
                .map { String(format: "%02x", $0) }
                .joined()

            let previousFingerprint =
                UserDefaults.standard.string(forKey: fingerprintKey)

            let jsonChanged =
                previousFingerprint != nil &&
                previousFingerprint != fingerprint

            UserDefaults.standard.set(
                fingerprint,
                forKey: fingerprintKey
            )

            // Quan trọng: luôn thay toàn bộ trạng thái bằng JSON mới.
            // Không lưu maintenance/update cũ vào UserDefaults.
            status = decoded

            if jsonChanged {
                print("APP STATUS JSON CHANGED — RESET TAB")
                NotificationCenter.default.post(
                    name: .ffh4xStatusDidChange,
                    object: nil
                )
            }

            print(
                "APP STATUS REFRESHED:",
                "jsonChanged =",
                jsonChanged,
                "fingerprint =",
                fingerprint,
                "maintenance =",
                decoded.maintenance.enabled,
                "update =",
                decoded.update.enabled
            )
        } catch {
            // Không phục hồi status cũ ở đây.
            // Nếu request thất bại, để status = nil thay vì
            // tiếp tục hiển thị maintenance/update cũ.
            print("APP STATUS ERROR:", error)
        }
    }
}

private struct FFH4XMaintenanceView: View {
    let title: String
    let message: String

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 76, height: 76)
                    .background(
                        AppTheme.accent.opacity(0.10),
                        in: Circle()
                    )

                Text(title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 330)

                Text("Vui lòng quay lại sau.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 28)
        }
        .transition(.opacity)
    }
}

private struct FFH4XUpdateFullScreenView: View {
    let update: FFH4XAppStatus.Update

    @Environment(\.openURL) private var openURL

    private var downloadURL: URL? {
        URL(string: update.downloadURL)
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 76, height: 76)
                    .background(
                        AppTheme.accent.opacity(0.10),
                        in: Circle()
                    )

                Text(update.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text("Phiên bản mới: \(update.version)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)

                if !update.message.isEmpty {
                    Text(update.message)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: 330)
                }

                if let downloadURL {
                    Button {
                        openURL(downloadURL)
                    } label: {
                        Label(
                            "Tải phiên bản mới",
                            systemImage: "arrow.down.to.line"
                        )
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: 300)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                }
            }
            .padding(.horizontal, 28)
        }
        .transition(.opacity)
    }
}

struct ContentView: View {

    @State private var selectedTab = 0
    @State private var showSettings = false

    @StateObject private var appStatus =
        FFH4XAppStatusService.shared

    @Environment(\.scenePhase) private var scenePhase

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "0.0.0"
    }

    private var updateAvailable: Bool {
    guard let update = appStatus.status?.update else {
        return false
    }

    // Server không bật cập nhật
    guard update.enabled else {
        return false
    }

    // Không có version hợp lệ
    let serverVersion = update.version
        .trimmingCharacters(in: .whitespacesAndNewlines)

    guard !serverVersion.isEmpty else {
        return false
    }

    // Chỉ hiện khi version trên server mới hơn
    // version đang chạy trên IPA.
    return compareVersions(
        currentVersion,
        serverVersion
    ) == .orderedAscending
}

// So sánh version: 1.0.9 < 1.0.10
private func compareVersions(
    _ lhs: String,
    _ rhs: String
) -> ComparisonResult {

    let left = lhs
        .split(separator: ".")
        .compactMap { Int($0) }

    let right = rhs
        .split(separator: ".")
        .compactMap { Int($0) }

    let count = max(left.count, right.count)

    for index in 0..<count {
        let leftValue = index < left.count
            ? left[index]
            : 0

        let rightValue = index < right.count
            ? right[index]
            : 0

        if leftValue < rightValue {
            return .orderedAscending
        }

        if leftValue > rightValue {
            return .orderedDescending
        }
    }

    return .orderedSame
}

    var body: some View {

        ZStack {

            FFH4XLicenseGate {

                TabView(
                    selection: $selectedTab
                ) {

                    HomeView()
                        .tabItem {
                            Label(
                                "Home",
                                systemImage:
                                    "house.fill"
                            )
                        }
                        .tag(0)

                    InfoView()
                        .tabItem {
                            Label(
                                "Info",
                                systemImage:
                                    "info.circle"
                            )
                        }
                        .tag(1)
                }
                .tint(
                    AppTheme.accent
                )
                .overlay(alignment: .topTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(
                                .system(
                                    size: 17,
                                    weight: .semibold
                                )
                            )
                            .frame(
                                width: 42,
                                height: 42
                            )
                            .background(
                                .ultraThinMaterial,
                                in: Circle()
                            )
                            .overlay {
                                Circle()
                                    .strokeBorder(
                                        Color.white.opacity(0.12),
                                        lineWidth: 1
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                    .padding(.top, 8)
                    .padding(.trailing, 14)
                    .accessibilityLabel("Cài đặt")
                }
                .sheet(
                    isPresented:
                        $showSettings
                ) {
                    FFH4XLicenseSettingsView()
                }
            }

            if let maintenance = appStatus.status?.maintenance,
               maintenance.enabled {

                FFH4XMaintenanceView(
                    title: maintenance.title,
                    message: maintenance.message
                )
                .zIndex(100)
            }
            else if updateAvailable,
                      let update = appStatus.status?.update {
                FFH4XUpdateFullScreenView(update: update)
                    .zIndex(100)
            }
        }
        .task {
            await appStatus.refresh()
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }

            Task {
                await appStatus.refresh()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .ffh4xStatusDidChange)) { _ in
            // JSON mới = bỏ lựa chọn tab cũ, lần vào lại bắt đầu từ Home.
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedTab = 0
            }
        }
        .animation(
            .easeInOut(duration: 0.2),
            value:
                appStatus.status?.maintenance.enabled
        )
    }
}

// MARK: - License Settings

private struct FFH4XLicenseSettingsView: View {

    @Environment(\.dismiss) private var dismiss

    @AppStorage(FFH4XLicenseConfig.storedKey)
    private var savedKey = ""

    @State private var showKey = false
    @State private var isChecking = false
    @State private var statusText = "Chưa kiểm tra"
    @State private var statusIsValid = true
    @State private var expiresAt = ""
    @State private var deviceName = ""
    @State private var deviceID = ""
    @State private var iosVersion = UIDevice.current.systemVersion
    @State private var errorText = ""

    private var maskedKey: String {
        let key = savedKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return "Chưa lưu key" }
        guard key.count > 8 else { return String(repeating: "•", count: key.count) }

        let prefix = String(key.prefix(4))
        let suffix = String(key.suffix(4))
        return "\(prefix)••••••\(suffix)"
    }

    private var formattedExpiry: String {
        guard !expiresAt.isEmpty else { return "Không có dữ liệu" }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = iso.date(from: expiresAt)
            ?? ISO8601DateFormatter().date(from: expiresAt)

        guard let date else { return expiresAt }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }

    private var remainingText: String {
        guard !expiresAt.isEmpty else { return "Vĩnh viễn / không có thời hạn" }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = iso.date(from: expiresAt)
                ?? ISO8601DateFormatter().date(from: expiresAt) else {
            return "Không xác định"
        }

        let seconds = date.timeIntervalSinceNow
        if seconds <= 0 { return "Đã hết hạn" }

        let days = Int(seconds / 86_400)
        let hours = Int(seconds.truncatingRemainder(dividingBy: 86_400) / 3_600)

        if days > 0 {
            return "Còn \(days) ngày \(hours) giờ"
        }

        let minutes = Int(seconds / 60)
        return "Còn \(max(minutes, 1)) phút"
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {

                    licenseStatusCard
                    licenseKeyCard
                    deviceCard
                    expiryCard
                    actionsCard

                    Text("FFH4X • Minh Khang")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
            .background(AppTheme.pageBackground.ignoresSafeArea())
            .navigationTitle("Cài đặt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") { dismiss() }
                }
            }
            .task {
                loadDeviceInfo()
                await refreshLicense(silent: true)
            }
        }
    }

    private var licenseStatusCard: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill((statusIsValid ? Color.green : Color.red).opacity(0.12))
                Image(systemName: statusIsValid ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(statusIsValid ? .green : .red)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text("Trạng thái License")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(statusText)
                    .font(.headline)
            }

            Spacer()

            if isChecking {
                ProgressView()
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var licenseKeyCard: some View {
        settingsCard(title: "License Key", icon: "key.fill") {
            HStack(spacing: 10) {
                Image(systemName: "key.horizontal.fill")
                    .foregroundStyle(AppTheme.accent)

                Group {
                    if showKey {
                        Text(savedKey.isEmpty ? "Chưa lưu key" : savedKey)
                    } else {
                        Text(maskedKey)
                    }
                }
                .font(.subheadline.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)

                Spacer()

                Button {
                    showKey.toggle()
                } label: {
                    Image(systemName: showKey ? "eye.slash.fill" : "eye.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.accent)
                .disabled(savedKey.isEmpty)
            }
        }
    }

    private var deviceCard: some View {
        settingsCard(title: "Thiết bị", icon: "iphone") {
            settingsRow("Tên máy", deviceName.isEmpty ? "Đang xác định..." : deviceName)
            Divider().padding(.vertical, 8)
            settingsRow("Device ID", deviceID.isEmpty ? "Đang xác định..." : shortDeviceID)
            Divider().padding(.vertical, 8)
            settingsRow("iOS", iosVersion)
        }
    }

    private var expiryCard: some View {
        settingsCard(title: "Thời hạn", icon: "calendar.badge.clock") {
            settingsRow("Hết hạn", formattedExpiry)
            Divider().padding(.vertical, 8)
            settingsRow("Còn lại", remainingText)
        }
    }

    private var actionsCard: some View {
        VStack(spacing: 10) {
            Button {
                Task { await refreshLicense(silent: false) }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text(isChecking ? "Đang kiểm tra..." : "Kiểm tra lại License")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
            .disabled(isChecking || savedKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if !errorText.isEmpty {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button(role: .destructive) {
                savedKey = ""
                expiresAt = ""
                statusText = "Chưa có License"
                statusIsValid = false
                showKey = false
                errorText = ""

                // Đóng Settings trước, sau đó báo cho License Gate khóa app
                // và mở lại màn hình nhập key.
                dismiss()
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .ffh4xLicenseDidDelete,
                        object: nil
                    )
                }
            } label: {
                Text("Xóa License Key")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder
    private func settingsCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func settingsRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }

    private var shortDeviceID: String {
        guard deviceID.count > 12 else { return deviceID }
        return "\(deviceID.prefix(6))…\(deviceID.suffix(6))"
    }

    @MainActor
    private func loadDeviceInfo() {
        deviceName = deviceModelName()
        iosVersion = UIDevice.current.systemVersion
        deviceID = FFH4XLicenseService.shared.currentDeviceIdentifier
    }

    @MainActor
    private func refreshLicense(silent: Bool) async {
        let key = savedKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !key.isEmpty else {
            statusText = "Chưa có License"
            statusIsValid = false
            expiresAt = ""
            if !silent { errorText = "Chưa có license key để kiểm tra." }
            return
        }

        isChecking = true
        errorText = ""

        do {
            let result = try await FFH4XLicenseService.shared.validate(key: key)

            if result.valid {
                statusText = "License hợp lệ"
                statusIsValid = true
                expiresAt = result.expiresAt ?? ""
            } else {
                statusText = "License không hợp lệ"
                statusIsValid = false
                expiresAt = result.expiresAt ?? ""
                if !silent {
                    errorText = result.message ?? "Key không hợp lệ."
                }
            }
        } catch {
            if !silent {
                errorText = error.localizedDescription
            }
        }

        isChecking = false
    }
}

// MARK: - Target App

struct LemonTargetApp:
    Identifiable,
    Hashable {

    let id: String
    let name: String
    let bundleID: String
    let iconAssetName: String
}

// MARK: - Feature Category

enum FFH4XFeatureCategory:
    String,
    CaseIterable,
    Identifiable,
    Hashable {

    case aim
    case chams
    case modSkin

    var id: String {
        rawValue
    }

    var title: String {

        switch self {

        case .aim:
            return "Aim"

        case .chams:
            return "Chams"

        case .modSkin:
            return "Mod Skin"
        }
    }

    var subtitle: String {

        switch self {

        case .aim:
            return "Hỗ trợ kéo tâm"

        case .chams:
            return "Định vị nhìn xuyên tường"

        case .modSkin:
            return "Mod skin nhân vật Alok thức tỉnh "
        }
    }

    var icon: String {

        switch self {

        case .aim:
            return "scope"

        case .chams:
            return "eye.fill"

        case .modSkin:
            return "tshirt.fill"
        }
    }

    var tint: Color {

        switch self {

        case .aim:
            return .blue

        case .chams:
            return .purple

        case .modSkin:
            return .orange
        }
    }
}

// MARK: - Home

private struct HomeView: View {

    private let apps: [LemonTargetApp] = [

        LemonTargetApp(
            id: "normal",
            name: "Free Fire",
            bundleID:
                "com.dts.freefireth",
            iconAssetName: "Normal"
        ),

        LemonTargetApp(
            id: "max",
            name: "Free Fire MAX",
            bundleID:
                "com.dts.freefiremax",
            iconAssetName: "Max"
        )
    ]

    @State private var selectedApp:
        LemonTargetApp?

    @State private var selectedFeature:
        FFH4XFeatureCategory?

    var body: some View {

        NavigationStack {

            ZStack {

                AppTheme.pageBackground
                    .ignoresSafeArea()

                if let selectedApp {

                    if let selectedFeature {

                        AppDataBrowserView(
                            targetApp: selectedApp,
                            featureCategory:
                                selectedFeature
                        ) {

                            withAnimation(
                                .spring(
                                    response: 0.34,
                                    dampingFraction: 0.82
                                )
                            ) {

                                self.selectedFeature =
                                    nil
                            }
                        }
                        .transition(
                            .asymmetric(
                                insertion:
                                    .move(
                                        edge: .trailing
                                    )
                                    .combined(
                                        with: .opacity
                                    ),

                                removal:
                                    .move(
                                        edge: .leading
                                    )
                                    .combined(
                                        with: .opacity
                                    )
                            )
                        )

                    } else {

                        FeatureMenuView(
                            targetApp:
                                selectedApp,

                            onBack: {

                                withAnimation(
                                    .spring(
                                        response: 0.34,
                                        dampingFraction: 0.82
                                    )
                                ) {

                                    self.selectedApp =
                                        nil
                                }
                            },

                            onSelect: {
                                feature in

                                withAnimation(
                                    .spring(
                                        response: 0.34,
                                        dampingFraction: 0.82
                                    )
                                ) {

                                    self.selectedFeature =
                                        feature
                                }
                            }
                        )
                        .transition(
                            .asymmetric(
                                insertion:
                                    .move(
                                        edge: .trailing
                                    )
                                    .combined(
                                        with: .opacity
                                    ),

                                removal:
                                    .move(
                                        edge: .leading
                                    )
                                    .combined(
                                        with: .opacity
                                    )
                            )
                        )
                    }

                } else {

                    appChooser
                }
            }
            .toolbar(
                .hidden,
                for: .navigationBar
            )
        }
    }

    private var appChooser: some View {

        ScrollView(
            showsIndicators: false
        ) {

            VStack(
                alignment: .leading,
                spacing: 18
            ) {

                VStack(
                    alignment: .leading,
                    spacing: 7
                ) {

                    HStack(spacing: 12) {

                        AppLogo(size: 46)

                        VStack(
                            alignment: .leading,
                            spacing: 2
                        ) {

                            Text("Minh Khang")
                                .font(
                                    .subheadline
                                    .weight(.semibold)
                                )
                                .foregroundStyle(
                                    .secondary
                                )

                            Text("FFH4X")
                                .font(
                                    .system(
                                        size: 34,
                                        weight: .bold,
                                        design: .rounded
                                    )
                                )
                                .tracking(-0.8)
                        }
                    }
                }
                .padding(.top, 12)

                VStack(spacing: 12) {

                    ForEach(apps) { app in

                        Button {

                            withAnimation(
                                .spring(
                                    response: 0.34,
                                    dampingFraction: 0.82
                                )
                            ) {

                                selectedApp =
                                    app
                            }

                        } label: {

                            AppSelectionCard(
                                app: app
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 7) {

                    Image(
                        systemName:
                            "checkmark.shield.fill"
                    )

                    Text("Minh Khang")
                }
                .font(
                    .caption.weight(
                        .semibold
                    )
                )
                .foregroundStyle(
                    .secondary
                )
                .frame(
                    maxWidth: .infinity
                )
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
    }
}

// MARK: - Feature Menu

private struct FeatureMenuView: View {

    let targetApp: LemonTargetApp

    let onBack: () -> Void

    let onSelect:
        (FFH4XFeatureCategory) -> Void

    var body: some View {

        ScrollView(
            showsIndicators: false
        ) {

            VStack(
                alignment: .leading,
                spacing: 18
            ) {

                HStack(spacing: 12) {

                    Button(
                        action: onBack
                    ) {

                        Image(
                            systemName:
                                "chevron.left"
                        )
                        .font(
                            .body.weight(
                                .bold
                            )
                        )
                        .frame(
                            width: 40,
                            height: 40
                        )
                        .background(
                            .thinMaterial,
                            in: Circle()
                        )
                    }
                    .buttonStyle(.plain)

                    ProjectAppIcon(
                        assetName:
                            targetApp.iconAssetName,
                        size: 52
                    )

                    VStack(
                        alignment: .leading,
                        spacing: 3
                    ) {

                        Text(
                            targetApp.name
                        )
                        .font(
                            .system(
                                size: 24,
                                weight: .bold,
                                design: .rounded
                            )
                        )

                        Text("")
                            .font(
                                .subheadline
                            )
                            .foregroundStyle(
                                .secondary
                            )
                    }

                    Spacer()
                }
                .padding(.top, 12)

                VStack(spacing: 12) {

                    ForEach(
                        FFH4XFeatureCategory.allCases
                    ) { feature in

                        Button {

                            onSelect(
                                feature
                            )

                        } label: {

                            FeatureSelectionCard(
                                feature: feature
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("Minh Khang")
                    .font(
                        .caption.weight(
                            .medium
                        )
                    )
                    .foregroundStyle(
                        .tertiary
                    )
                    .frame(
                        maxWidth: .infinity
                    )
                    .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
    }
}

// MARK: - Feature Card

private struct FeatureSelectionCard:
    View {

    let feature:
        FFH4XFeatureCategory

    var body: some View {

        HStack(spacing: 12) {

            ZStack {

                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
                .fill(
                    feature.tint.opacity(
                        0.13
                    )
                )

                Image(
                    systemName:
                        feature.icon
                )
                .font(
                    .system(
                        size: 22,
                        weight: .bold
                    )
                )
                .foregroundStyle(
                    feature.tint
                )
            }
            .frame(
                width: 58,
                height: 58
            )

            VStack(
                alignment: .leading,
                spacing: 4
            ) {

                Text(feature.title)
                    .font(
                        .system(
                            size: 19,
                            weight: .semibold,
                            design: .rounded
                        )
                    )

                Text(feature.subtitle)
                    .font(
                        .subheadline
                    )
                    .foregroundStyle(
                        .secondary
                    )
            }

            Spacer()

            Image(
                systemName:
                    "chevron.right"
            )
            .font(
                .caption.weight(
                    .bold
                )
            )
            .foregroundStyle(
                .tertiary
            )
            .frame(
                width: 32,
                height: 32
            )
            .background(
                .thinMaterial,
                in: Circle()
            )
        }
        .padding(16)
        .background(
            .regularMaterial,
            in:
                RoundedRectangle(
                    cornerRadius: 25,
                    style: .continuous
                )
        )
        .overlay {

            RoundedRectangle(
                cornerRadius: 25,
                style: .continuous
            )
            .strokeBorder(
                feature.tint.opacity(0.12),
                lineWidth: 1
            )
        }
        .shadow(
            color: .black.opacity(0.06),
            radius: 15,
            y: 7
        )
    }
}

// MARK: - App Selection Card

private struct AppSelectionCard:
    View {

    let app:
        LemonTargetApp

    var body: some View {

        HStack(spacing: 12) {

            ProjectAppIcon(
                assetName:
                    app.iconAssetName,
                size: 64
            )

            VStack(
                alignment: .leading,
                spacing: 5
            ) {

                Text(app.name)
                    .font(
                        .system(
                            size: 19,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(
                        .primary
                    )

                Text(app.bundleID)
                    .font(
                        .caption.monospaced()
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .lineLimit(1)

                Text("")
                    .font(
                        .caption2.weight(
                            .semibold
                        )
                    )
                    .foregroundStyle(
                        AppTheme.accent
                    )
            }

            Spacer(minLength: 8)

            Image(
                systemName:
                    "chevron.right"
            )
            .font(
                .caption.weight(
                    .bold
                )
            )
            .foregroundStyle(
                .tertiary
            )
            .frame(
                width: 30,
                height: 30
            )
            .background(
                .thinMaterial,
                in: Circle()
            )
        }
        .padding(16)
        .background(
            .regularMaterial,
            in:
                RoundedRectangle(
                    cornerRadius: 25,
                    style: .continuous
                )
        )
        .overlay {

            RoundedRectangle(
                cornerRadius: 25,
                style: .continuous
            )
            .strokeBorder(
                AppTheme.accent.opacity(0.12),
                lineWidth: 1
            )
        }
        .shadow(
            color: .black.opacity(0.06),
            radius: 16,
            y: 8
        )
    }
}

// MARK: - Project Icon

struct ProjectAppIcon: View {

    let assetName: String
    let size: CGFloat

    var body: some View {

        Image(assetName)
            .resizable()
            .scaledToFill()
            .frame(
                width: size,
                height: size
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius:
                        size * 0.23,
                    style: .continuous
                )
            )
            .overlay {

                RoundedRectangle(
                    cornerRadius:
                        size * 0.23,
                    style: .continuous
                )
                .strokeBorder(
                    Color.white.opacity(0.16),
                    lineWidth: 1
                )
            }
    }
}

// MARK: - Installed App Icon

struct InstalledAppIcon: View {

    let bundleID: String
    let size: CGFloat

    @State private var image:
        UIImage?

    var body: some View {

        Group {

            if let image {

                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()

            } else {

                Image(
                    systemName:
                        "app.fill"
                )
                .font(
                    .system(
                        size: size * 0.38,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    AppTheme.accent
                )
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
                .background(
                    AppTheme.accent.opacity(
                        0.10
                    )
                )
            }
        }
        .frame(
            width: size,
            height: size
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    size * 0.23,
                style: .continuous
            )
        )
        .overlay {

            RoundedRectangle(
                cornerRadius:
                    size * 0.23,
                style: .continuous
            )
            .strokeBorder(
                Color.white.opacity(0.16),
                lineWidth: 1
            )
        }
        .task(id: bundleID) {

            image =
                await Task.detached(
                    priority:
                        .userInitiated
                ) {

                    iconForBundleID(
                        bundleID
                    )

                }.value
        }
    }
}

// MARK: - Info

private struct InfoView: View {

    @EnvironmentObject private var appState:
        AppState

    private var appVersion: String {

        Bundle.main.object(
            forInfoDictionaryKey:
                "AppReleaseDisplayVersion"
        ) as? String

        ??
        Bundle.main.object(
            forInfoDictionaryKey:
                "CFBundleShortVersionString"
        ) as? String

        ??
        "1.0"
    }

    var body: some View {

        NavigationStack {

            ZStack {

                AppTheme.pageBackground
                    .ignoresSafeArea()

                ScrollView(
                    showsIndicators: false
                ) {

                    VStack(
                        alignment: .leading,
                        spacing: 18
                    ) {

                        infoHero

                        infoSection(
                            title: "Tác Giả",
                            systemImage:
                                "person.fill"
                        ) {

                            linkRow(
                                title:
                                    "Minh Khang",
                                subtitle:
                                    "Telegram",
                                icon:
                                    "paperplane.fill",
                                url:
                                    FFH4XLicenseConfig
                                    .authorTelegramURL
                            )

                            linkRow(
                                title:
                                    "Minh Khang",
                                subtitle:
                                    "Zalo",
                                icon:
                                    "message.fill",
                                url:
                                    FFH4XLicenseConfig
                                    .authorZaloURL
                            )
                        }

                        infoSection(
                            title: "Channel",
                            systemImage:
                                "link"
                        ) {

                            linkRow(
                                title:
                                    "Telegram Channel",
                                subtitle:
                                    "@minhkhanghax",
                                icon:
                                    "megaphone.fill",
                                url:
                                    FFH4XLicenseConfig
                                    .channelTelegramURL
                            )

                            linkRow(
                                title:
                                    "Nhóm Zalo",
                                subtitle:
                                    "Zalo Group",
                                icon:
                                    "person.3.fill",
                                url:
                                    FFH4XLicenseConfig
                                    .groupZaloURL
                            )
                        }

                        supportSection

                        Text("Minh Khang")
                            .font(
                                .caption.weight(
                                    .medium
                                )
                            )
                            .foregroundStyle(
                                .tertiary
                            )
                            .frame(
                                maxWidth:
                                    .infinity
                            )
                            .padding(
                                .vertical,
                                8
                            )
                    }
                    .padding(
                        .horizontal,
                        16
                    )
                    .padding(
                        .top,
                        10
                    )
                    .padding(
                        .bottom,
                        24
                    )
                }
            }
            .toolbar(
                .hidden,
                for: .navigationBar
            )
        }
    }

    private var infoHero: some View {

        VStack(spacing: 10) {

            AppLogo(size: 72)
                .shadow(
                    color:
                        AppTheme.accent.opacity(
                            0.18
                        ),
                    radius: 18,
                    y: 8
                )

            Text("FFH4X")
                .font(
                    .system(
                        size: 34,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .tracking(-0.5)

            Text(
                "Version \(appVersion)"
            )
            .font(
                .subheadline.weight(
                    .medium
                )
            )
            .foregroundStyle(
                .secondary
            )
        }
        .frame(
            maxWidth: .infinity
        )
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var supportSection:
        some View {

        infoSection(
            title:
                "Phiên Bản iOS",
            systemImage:
                "iphone"
        ) {

            VStack(
                alignment: .leading,
                spacing: 14
            ) {

                HStack(spacing: 10) {

                    Image(
                        systemName:
                            appState.isSupported
                            ? "checkmark.circle.fill"
                            : "xmark.circle.fill"
                    )
                    .font(
                        .title3.weight(
                            .semibold
                        )
                    )
                    .foregroundStyle(
                        appState.isSupported
                        ? Color.green
                        : Color.red
                    )

                    VStack(
                        alignment: .leading,
                        spacing: 2
                    ) {

                        Text(
                            appState.isSupported
                            ? "Thiết bị được hỗ trợ"
                            : "Thiết bị không được hỗ trợ"
                        )
                        .font(
                            .body.weight(
                                .semibold
                            )
                        )

                        Text(
                            "Theo danh sách phiên bản đã xác minh"
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                    }

                    Spacer(
                        minLength: 0
                    )
                }

                Divider()

                SupportVersionRow(
                    title: "iOS 17 – 18",
                    detail:
                        ExploitSupportPolicy
                        .verifiedIOS17To18Range,
                    icon:
                        "checkmark.circle.fill",
                    tint:
                        .green
                )

                SupportVersionRow(
                    title: "iOS 26",
                    detail:
                        ExploitSupportPolicy
                        .verifiedIOS26Range,
                    icon:
                        "checkmark.circle.fill",
                    tint:
                        .green
                )

                VStack(
                    alignment: .leading,
                    spacing: 9
                ) {

                    HStack(
                        alignment:
                            .firstTextBaseline,
                        spacing: 10
                    ) {

                        Color.clear
                            .frame(width: 22, height: 22)
                            .hidden()

                        Text("iOS 27")
                            .font(
                                .body.weight(
                                    .semibold
                                )
                            )

                        Spacer(
                            minLength: 8
                        )

                        Text("Beta")
                            .font(
                                .caption.weight(
                                    .semibold
                                )
                            )
                            .foregroundStyle(
                                AppTheme.accent
                            )
                            .padding(
                                .horizontal,
                                8
                            )
                            .padding(
                                .vertical,
                                4
                            )
                            .background(
                                AppTheme.accent
                                    .opacity(0.10),
                                in: Capsule()
                            )
                    }

                    VStack(
                        alignment: .leading,
                        spacing: 7
                    ) {

                        ForEach(
                            ExploitSupportPolicy
                                .verifiedIOS27Builds,
                            id: \.build
                        ) { version in

                            HStack(spacing: 8) {

                                Image(
                                    systemName:
                                        "checkmark"
                                )
                                .font(
                                    .caption.weight(
                                        .bold
                                    )
                                )
                                .foregroundStyle(
                                    .green
                                )
                                .frame(
                                    width: 16,
                                    alignment:
                                        .center
                                )

                                Text(
                                    "Beta \(version.beta)"
                                )
                                .font(
                                    .caption.weight(
                                        .medium
                                    )
                                )

                                Spacer(
                                    minLength: 8
                                )

                                Text(
                                    version.build
                                )
                                .font(
                                    .caption.monospaced()
                                )
                                .foregroundStyle(
                                    .secondary
                                )
                                .lineLimit(1)
                            }
                            .frame(
                                maxWidth:
                                    .infinity,
                                alignment:
                                    .leading
                            )
                        }
                    }
                    .padding(12)
                    .background(
                        Color.secondary
                            .opacity(0.06),
                        in:
                            RoundedRectangle(
                                cornerRadius: 14,
                                style: .continuous
                            )
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func infoSection<
        Content: View
    >(
        title: String,
        systemImage: String,
        @ViewBuilder content:
            () -> Content
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 9
        ) {

            Label(
                title,
                systemImage:
                    systemImage
            )
            .font(
                .subheadline.weight(
                    .bold
                )
            )
            .foregroundStyle(
                .secondary
            )
            .padding(
                .leading,
                2
            )

            VStack(
                alignment: .leading,
                spacing: 7
            ) {

                content()
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .padding(14)
            .background(
                .regularMaterial,
                in:
                    RoundedRectangle(
                        cornerRadius: 20,
                        style: .continuous
                    )
            )
            .overlay {

                RoundedRectangle(
                    cornerRadius: 20,
                    style: .continuous
                )
                .strokeBorder(
                    Color.white.opacity(0.10)
                )
            }
            .shadow(
                color:
                    Color.black.opacity(0.05),
                radius: 14,
                y: 7
            )
        }
    }

    @ViewBuilder
    private func linkRow(
        title: String,
        subtitle: String,
        icon: String,
        url: URL
    ) -> some View {

        Link(destination: url) {

            HStack(spacing: 12) {

                ZStack {
                    RoundedRectangle(
                        cornerRadius: 14,
                        style: .continuous
                    )
                    .fill(
                        AppTheme.accent
                            .opacity(0.11)
                    )

                    Image(systemName: icon)
                        .font(
                            .system(
                                size: 20,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(
                            AppTheme.accent
                        )
                }
                .frame(width: 56, height: 56)

                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {
                    Text(title)
                        .font(
                            .system(
                                size: 17,
                                weight: .semibold,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(
                            AppTheme.accent
                        )
                        .lineLimit(1)

                    Text(subtitle)
                        .font(
                            .system(
                                size: 13,
                                weight: .regular
                            )
                        )
                        .foregroundStyle(
                            AppTheme.accent.opacity(0.65)
                        )
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(
                        .system(
                            size: 17,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        AppTheme.accent.opacity(0.45)
                    )
            }
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
    }
}

// MARK: - Support Version

private struct SupportVersionRow:
    View {

    let title: String
    let detail: String
    let icon: String
    let tint: Color

    var body: some View {

        HStack(spacing: 10) {

            Image(
                systemName:
                    icon
            )
            .font(
                .body.weight(
                    .semibold
                )
            )
            .foregroundStyle(
                tint
            )
            .frame(
                width: 22,
                alignment: .center
            )

            Text(title)
                .font(
                    .body.weight(
                        .semibold
                    )
                )

            Spacer(
                minLength: 10
            )

            Text(detail)
                .font(
                    .caption.monospaced()
                )
                .foregroundStyle(
                    .secondary
                )
                .multilineTextAlignment(
                    .trailing
                )
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }
}
