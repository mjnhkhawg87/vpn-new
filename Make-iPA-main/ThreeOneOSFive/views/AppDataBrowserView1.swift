import SwiftUI

/// Single-tab preset HUD.
/// Fetch feature configurations and payload files dynamically from a remote server.
///
/// Lưu trạng thái:
/// - AIM: KHÔNG lưu local.
/// - Các category khác: lưu theo targetAppID + categoryID + feature.id.
struct AppDataBrowserView: View {

    // MARK: - Remote JSON URL

    private var jsonURLString: String {
        let base64String =
        "aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL21pbmhraGFuZzh0aDcvTmd1eWVuTWluaEtoYW5nL3JlZnMvaGVhZHMvbWFpbi9pUEEvTm1raU9TVk4vbm1raW9zdm4uanNvbg=="

        guard let data = Data(base64Encoded: base64String),
              let decodedURL = String(data: data, encoding: .utf8) else {
            return ""
        }

        return decodedURL
    }

    // MARK: - Inputs

    let targetApp: LemonTargetApp
    let featureCategory: FFH4XFeatureCategory
    let onBack: () -> Void

    // MARK: - State

    @State private var features: [PatchHUDFeature] = []
    @State private var isLoading: Bool = true
    @State private var busyFeatureID: String?
    @State private var message: String?
    @State private var errorMessage: String?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {

                        hero

                        VStack(spacing: 12) {
                            if isLoading {
                                loadingState
                            } else if features.isEmpty {
                                emptyFeatureState
                            } else {
                                ForEach($features) { $feature in
                                    featureCard(feature: $feature)
                                }
                            }
                        }

                        if let message {
                            statusBanner(
                                message,
                                systemImage: "checkmark.circle.fill"
                            )
                            .transition(
                                .move(edge: .bottom)
                                .combined(with: .opacity)
                            )
                        }

                        if let errorMessage {
                            statusBanner(
                                errorMessage,
                                systemImage: "exclamationmark.triangle.fill",
                                isError: true
                            )
                            .transition(
                                .move(edge: .bottom)
                                .combined(with: .opacity)
                            )
                        }

                        footer
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            await fetchRemoteFeatures()
        }
        .animation(
            .spring(response: 0.32, dampingFraction: 0.82),
            value: message
        )
        .animation(
            .spring(response: 0.32, dampingFraction: 0.82),
            value: errorMessage
        )
        .animation(
            .spring(response: 0.32, dampingFraction: 0.82),
            value: isLoading
        )
    }

    // MARK: - Remote Data Fetcher

    @MainActor
    private func fetchRemoteFeatures() async {
        isLoading = true
        message = nil
        errorMessage = nil

        var loadedFeatures = await PatchHUDFeature.fetchRemote(
            from: jsonURLString,
            targetApp: targetApp,
            category: featureCategory
        )

        // JSON cung cấp giá trị mặc định.
        //
        // AIM:
        // Không restore từ UserDefaults.
        //
        // Category khác:
        // Restore trạng thái local nếu đã từng lưu.
        FeatureSettingsStore.restore(&loadedFeatures)

        features = loadedFeatures
        isLoading = false
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {

            HStack(alignment: .center, spacing: 12) {

                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.bold))
                        .frame(width: 38, height: 38)
                        .background(
                            .thinMaterial,
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)

                ProjectAppIcon(
                    assetName: targetApp.iconAssetName,
                    size: 48
                )

                VStack(alignment: .leading, spacing: 2) {

                    Text(targetApp.name)
                        .font(
                            .system(
                                size: 26,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .tracking(-0.5)

                    Text(targetApp.bundleID)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)

                    Text(featureCategory.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {

                StatusPill(
                    title: "\(features.count) chức năng",
                    icon: "slider.horizontal.3"
                )

                StatusPill(
                    title: "Sẵn sàng",
                    icon: "checkmark.shield.fill"
                )
            }
            .padding(.top, 14)
        }
        .padding(.top, 6)
    }

    // MARK: - Feature Card

    private func featureCard(
        feature: Binding<PatchHUDFeature>
    ) -> some View {

        let value = feature.wrappedValue
        let isBusy = busyFeatureID == value.id

        return HStack(spacing: 14) {

            ZStack {

                RoundedRectangle(
                    cornerRadius: 17,
                    style: .continuous
                )
                .fill(value.tint.opacity(0.14))

                RoundedRectangle(
                    cornerRadius: 17,
                    style: .continuous
                )
                .strokeBorder(
                    value.tint.opacity(0.12)
                )

                Image(systemName: value.icon)
                    .font(
                        .system(
                            size: 20,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(value.tint)
            }
            .frame(width: 54, height: 54)

            VStack(
                alignment: .leading,
                spacing: 5
            ) {

                Text(value.title)
                    .font(
                        .system(
                            size: 18,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.primary)

                Text(value.content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )

                HStack(spacing: 6) {

                    Circle()
                        .fill(
                            value.isOn
                            ? value.tint
                            : Color.secondary.opacity(0.45)
                        )
                        .frame(
                            width: 6,
                            height: 6
                        )

                    Text(
                        value.isOn
                        ? "Đang bật"
                        : "Đang tắt"
                    )
                    .font(
                        .caption.weight(.medium)
                    )
                    .foregroundStyle(
                        value.isOn
                        ? value.tint
                        : .secondary
                    )
                }
                .padding(.top, 1)
            }

            Spacer(minLength: 4)

            Toggle(
                "",
                isOn: featureToggleBinding(feature)
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(value.tint)
            .disabled(isBusy)
            .scaleEffect(1.03)
        }
        .padding(16)
        .background {
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .fill(.regularMaterial)
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .strokeBorder(
                LinearGradient(
                    colors: [
                        value.tint.opacity(
                            value.isOn
                            ? 0.34
                            : 0.12
                        ),
                        Color.white.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
        }
        .shadow(
            color: Color.black.opacity(0.06),
            radius: 14,
            x: 0,
            y: 7
        )
    }

    // MARK: - Toggle Binding

    /// Custom Binding để không dùng onChange.
    ///
    /// AIM vẫn thay đổi trạng thái trong RAM,
    /// nhưng không được lưu vào UserDefaults.
    private func featureToggleBinding(
        _ feature: Binding<PatchHUDFeature>
    ) -> Binding<Bool> {

        Binding(
            get: {
                feature.wrappedValue.isOn
            },
            set: { newValue in

                let featureID = feature.wrappedValue.id

                // Cập nhật UI ngay lập tức.
                feature.wrappedValue.isOn = newValue

                Task {
                    await toggle(
                        featureID: featureID,
                        enabled: newValue
                    )
                }
            }
        )
    }

    // MARK: - Loading

    private var loadingState: some View {
        VStack(spacing: 12) {

            ProgressView()
                .controlSize(.large)

            Text("Đang tải cấu hình từ Server...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            .regularMaterial,
            in: RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
        )
    }

    // MARK: - Empty

    private var emptyFeatureState: some View {
        VStack(spacing: 12) {

            Image(systemName: featureCategory.icon)
                .font(
                    .system(
                        size: 28,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    featureCategory.tint
                )

            Text("Chưa có chức năng")
                .font(
                    .headline.weight(.semibold)
                )

            Text(
                "Không tải được dữ liệu hoặc Server chưa cấu hình cho \(featureCategory.title)."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
        .background(
            .regularMaterial,
            in: RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
        )
    }

    // MARK: - Status Banner

    private func statusBanner(
        _ text: String,
        systemImage: String,
        isError: Bool = false
    ) -> some View {

        HStack(spacing: 10) {

            Image(systemName: systemImage)
                .font(.body.weight(.semibold))

            Text(text)
                .font(.footnote.weight(.medium))
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .foregroundStyle(
            isError
            ? Color.red
            : Color.green
        )
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            (isError ? Color.red : Color.green)
                .opacity(0.08),
            in: RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
        )
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {

            Spacer()

            Text("Minh Khang")
                .font(.caption.weight(.medium))
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .padding(.top, 2)
    }

    // MARK: - Toggle Action

    @MainActor
    private func toggle(
        featureID: String,
        enabled: Bool
    ) async {

        guard let index = features.firstIndex(
            where: { $0.id == featureID }
        ) else {
            return
        }

        let feature = features[index]

        busyFeatureID = featureID
        message = nil
        errorMessage = nil

        do {

            if enabled {

                // Apply trước.
                try await apply(feature)

                // AIM sẽ tự bỏ qua việc lưu.
                FeatureSettingsStore.set(
                    true,
                    for: feature
                )

                features[index].isOn = true

                message = "Đã bật \(feature.title)."

            } else {

                // Restore trước.
                try restore(feature)

                // AIM sẽ tự bỏ qua việc lưu.
                FeatureSettingsStore.set(
                    false,
                    for: feature
                )

                features[index].isOn = false

                message = "Đã tắt \(feature.title)."
            }

        } catch {

            // Không lưu setting khi thao tác thất bại.
            features[index].isOn = !enabled

            errorMessage = error.localizedDescription
        }

        busyFeatureID = nil
    }

    // MARK: - Apply

    private func apply(
        _ feature: PatchHUDFeature
    ) async throws {

        guard let baseURL = URL(
            string: jsonURLString
        )?.deletingLastPathComponent() else {

            throw PatchHUDError.invalidServerURL
        }

        let payloadURL =
            baseURL.appendingPathComponent(
                feature.replacementFilename
            )

        let data: Data

        do {

            let (
                downloadedData,
                response
            ) = try await URLSession.shared.data(
                from: payloadURL
            )

            if let httpResponse =
                response as? HTTPURLResponse,
               httpResponse.statusCode != 200 {

                throw PatchHUDError.payloadEmpty(
                    feature.replacementFilename
                )
            }

            data = downloadedData

        } catch let error as PatchHUDError {

            throw error

        } catch {

            throw PatchHUDError.payloadDownloadFailed(
                feature.replacementFilename
            )
        }

        guard !data.isEmpty else {

            throw PatchHUDError.payloadEmpty(
                feature.replacementFilename
            )
        }

        let project = feature.makeProject(
            replacementData: data
        )

        _ = try DevicePatchService.apply(
            project: project
        )
    }

    // MARK: - Restore

    private func restore(
        _ feature: PatchHUDFeature
    ) throws {

        let projectID = feature.projectID

        guard let receipt =
                DevicePatchService.latestReceipt(
                    projectID: projectID
                ) else {

            throw PatchHUDError.nothingToRestore
        }

        try DevicePatchService.restore(
            receipt: receipt
        )
    }
}

// MARK: - Local Feature Settings Store

/// Quản lý trạng thái ON/OFF.
///
/// QUAN TRỌNG:
///
/// categoryID == "aim"
/// → KHÔNG BAO GIỜ lưu vào UserDefaults.
///
/// Các category khác
/// → vẫn lưu bình thường.
///
/// Vì key chứa targetAppID nên:
///
/// normal + chams
/// và
/// max + chams
///
/// vẫn là hai setting riêng.
private enum FeatureSettingsStore {

    private static let prefix =
        "FFH4X.feature"

    // MARK: - Non-Persistent Categories

    /// Những category không được lưu local.
    ///
    /// Hiện tại chỉ có AIM.
    private static func shouldPersist(
        _ feature: PatchHUDFeature
    ) -> Bool {

        return feature.categoryID != "aim"
    }

    // MARK: - Key

    private static func key(
        for feature: PatchHUDFeature
    ) -> String {

        return [
            prefix,
            feature.targetAppID,
            feature.categoryID,
            feature.id
        ]
        .joined(separator: ".")
    }

    // MARK: - Get

    static func get(
        _ feature: PatchHUDFeature
    ) -> Bool {

        // AIM:
        // Không đọc UserDefaults.
        //
        // Luôn lấy giá trị trực tiếp từ JSON.
        guard shouldPersist(feature) else {
            return feature.isOn
        }

        let settingKey = key(
            for: feature
        )

        // Chưa từng lưu local.
        //
        // Khi đó dùng giá trị isOn từ JSON.
        guard UserDefaults.standard.object(
            forKey: settingKey
        ) != nil else {

            return feature.isOn
        }

        return UserDefaults.standard.bool(
            forKey: settingKey
        )
    }

    // MARK: - Set

    static func set(
        _ value: Bool,
        for feature: PatchHUDFeature
    ) {

        // AIM:
        // Không ghi UserDefaults.
        guard shouldPersist(feature) else {
            return
        }

        let settingKey = key(
            for: feature
        )

        UserDefaults.standard.set(
            value,
            forKey: settingKey
        )
    }

    // MARK: - Restore All

    static func restore(
        _ features: inout [PatchHUDFeature]
    ) {

        for index in features.indices {

            features[index].isOn = get(
                features[index]
            )
        }
    }

    // MARK: - Remove One Setting

    static func remove(
        _ feature: PatchHUDFeature
    ) {

        // AIM vốn không lưu.
        guard shouldPersist(feature) else {
            return
        }

        UserDefaults.standard.removeObject(
            forKey: key(for: feature)
        )
    }

    // MARK: - Clear All Settings

    static func clearAll() {

        let defaults =
            UserDefaults.standard

        let dictionary =
            defaults.dictionaryRepresentation()

        for key in dictionary.keys {

            if key.hasPrefix(
                "\(prefix)."
            ) {

                defaults.removeObject(
                    forKey: key
                )
            }
        }
    }
}

// MARK: - Status Pill

private struct StatusPill: View {

    let title: String
    let icon: String

    var body: some View {

        Label(
            title,
            systemImage: icon
        )
        .font(
            .caption.weight(.semibold)
        )
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            .thinMaterial,
            in: Capsule()
        )
    }
}

// MARK: - Feature Model

private struct PatchHUDFeature:
    Identifiable,
    Decodable {

    let id: String
    let title: String
    let subtitle: String
    let content: String
    let icon: String
    let tintHex: String

    let targetAppID: String
    let categoryID: String

    let bundleID: String
    let relativePath: String
    let replacementFilename: String

    let projectID: UUID

    /// Giá trị mặc định từ JSON.
    ///
    /// Đối với AIM:
    /// giá trị này sẽ luôn được sử dụng khi load lại.
    ///
    /// Đối với category khác:
    /// UserDefaults có thể override giá trị này.
    var isOn: Bool

    var tint: Color {
        Color(hex: tintHex)
    }

    // MARK: - Make Project

    func makeProject(
        replacementData: Data
    ) -> PatchProject {

        PatchProject(
            id: projectID,
            name: "HUD • \(title)",
            rules: [
                PatchRule(
                    bundleID: bundleID,
                    relativePath: relativePath,
                    replacementFilename:
                        replacementFilename,
                    replacementData:
                        replacementData
                )
            ]
        )
    }

    // MARK: - Fetch Remote

    static func fetchRemote(
        from urlString: String,
        targetApp: LemonTargetApp,
        category: FFH4XFeatureCategory
    ) async -> [PatchHUDFeature] {

        guard let url = URL(
            string: urlString
        ) else {
            return []
        }

        do {

            let (
                data,
                response
            ) = try await URLSession.shared.data(
                from: url
            )

            if let httpResponse =
                response as? HTTPURLResponse,
               httpResponse.statusCode != 200 {

                return []
            }

            let items =
                try JSONDecoder().decode(
                    [PatchHUDFeature].self,
                    from: data
                )

            return items.filter { item in

                item.targetAppID ==
                    targetApp.id
                &&
                item.categoryID ==
                    category.id
            }

        } catch {

            print(
                "Lỗi fetch JSON remote: \(error.localizedDescription)"
            )

            return []
        }
    }
}

// MARK: - Color Hex Extension

private extension Color {

    init(hex: String) {

        let hexClean =
            hex.trimmingCharacters(
                in:
                    CharacterSet
                        .alphanumerics
                        .inverted
            )

        var int: UInt64 = 0

        Scanner(
            string: hexClean
        ).scanHexInt64(&int)

        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64

        switch hexClean.count {

        case 3:

            (
                a,
                r,
                g,
                b
            ) = (
                255,
                (int >> 8) * 17,
                (int >> 4 & 0xF) * 17,
                (int & 0xF) * 17
            )

        case 6:

            (
                a,
                r,
                g,
                b
            ) = (
                255,
                int >> 16,
                int >> 8 & 0xFF,
                int & 0xFF
            )

        case 8:

            (
                a,
                r,
                g,
                b
            ) = (
                int >> 24,
                int >> 16 & 0xFF,
                int >> 8 & 0xFF,
                int & 0xFF
            )

        default:

            (
                a,
                r,
                g,
                b
            ) = (
                255,
                0,
                0,
                0
            )
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Errors

private enum PatchHUDError:
    LocalizedError {

    case invalidServerURL
    case payloadEmpty(String)
    case payloadDownloadFailed(String)
    case nothingToRestore

    var errorDescription: String? {

        switch self {

        case .invalidServerURL:

            return "Đường dẫn máy chủ không hợp lệ."

        case .payloadEmpty(let filename):

            return "Nội dung tệp \(filename) trên máy chủ bị rỗng."

        case .payloadDownloadFailed(let filename):

            return "Không thể tải tệp \(filename) từ máy chủ."

        case .nothingToRestore:

            return "Không có thay đổi trước đó để khôi phục."
        }
    }
}
