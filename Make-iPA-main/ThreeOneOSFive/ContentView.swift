import UIKit
import SwiftUI
import CryptoKit

// MARK: - Notifications

private extension Notification.Name {
    static let ffh4xStatusDidChange = Notification.Name("FFH4XStatusDidChange")
}

// MARK: - Remote App Status

private struct FFH4XAppStatus: Decodable {
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

        status = nil

        var components = URLComponents(
            url: baseURL,
            resolvingAgainstBaseURL: false
        )

        var queryItems = components?.queryItems ?? []

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

        URLCache.shared.removeCachedResponse(for: request)
        URLCache.shared.removeAllCachedResponses()
        request.cachePolicy = .reloadIgnoringLocalCacheData

        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-cache, no-store, max-age=0", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")

        do {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.urlCache = nil
            configuration.httpShouldSetCookies = false
            let session = URLSession(configuration: configuration)

            let (data, response) = try await session.data(for: request)

            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                print("APP STATUS HTTP ERROR:", (response as? HTTPURLResponse)?.statusCode ?? -1)
                return
            }

            let decoded = try JSONDecoder().decode(
                FFH4XAppStatus.self,
                from: data
            )

            let fingerprint = SHA256.hash(data: data)
                .map { String(format: "%02x", $0) }
                .joined()

            let previousFingerprint = UserDefaults.standard.string(forKey: fingerprintKey)
            let jsonChanged = previousFingerprint != nil && previousFingerprint != fingerprint

            UserDefaults.standard.set(fingerprint, forKey: fingerprintKey)
            status = decoded

            if jsonChanged {
                print("APP STATUS JSON CHANGED — RESET TAB")
                NotificationCenter.default.post(
                    name: .ffh4xStatusDidChange,
                    object: nil
                )
            }
        } catch {
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

// MARK: - Content View

struct ContentView: View {
    @State private var selectedTab = 0
    @StateObject private var appStatus = FFH4XAppStatusService.shared
    @Environment(\.scenePhase) private var scenePhase

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private var updateAvailable: Bool {
        guard let update = appStatus.status?.update else { return false }
        guard update.enabled else { return false }

        let serverVersion = update.version.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !serverVersion.isEmpty else { return false }

        return compareVersions(currentVersion, serverVersion) == .orderedAscending
    }

    private func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").compactMap { Int($0) }
        let right = rhs.split(separator: ".").compactMap { Int($0) }
        let count = max(left.count, right.count)

        for index in 0..<count {
            let leftValue = index < left.count ? left[index] : 0
            let rightValue = index < right.count ? right[index] : 0

            if leftValue < rightValue { return .orderedAscending }
            if leftValue > rightValue { return .orderedDescending }
        }

        return .orderedSame
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Label("Trang chủ", systemImage: "house.fill")
                    }
                    .tag(0)

                VPNView()
                    .tabItem {
                        Label("Cấu hình", systemImage: "network.badge.shield.half.filled")
                    }
                    .tag(1)

                InfoView()
                    .tabItem {
                        Label("Thông tin", systemImage: "info.circle")
                    }
                    .tag(2)
            }
            .tint(AppTheme.accent)

            if let maintenance = appStatus.status?.maintenance, maintenance.enabled {
                FFH4XMaintenanceView(
                    title: maintenance.title,
                    message: maintenance.message
                )
                .zIndex(100)
            } else if updateAvailable, let update = appStatus.status?.update {
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
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedTab = 0
            }
        }
        .animation(
            .easeInOut(duration: 0.2),
            value: appStatus.status?.maintenance.enabled
        )
    }
}

// MARK: - Target App

struct LemonTargetApp: Identifiable, Hashable {
    let id: String
    let name: String
    let bundleID: String
    let iconAssetName: String
}

// MARK: - Feature Category

enum FFH4XFeatureCategory: String, CaseIterable, Identifiable, Hashable {
    case aim
    case chams
    case modSkin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aim: return "Aim"
        case .chams: return "Chams"
        case .modSkin: return "Mod Skin"
        }
    }

    var subtitle: String {
        switch self {
        case .aim: return "Hỗ trợ kéo tâm"
        case .chams: return "Định vị nhìn xuyên tường"
        case .modSkin: return "Mod skin nhân vật Alok thức tỉnh "
        }
    }

    var icon: String {
        switch self {
        case .aim: return "scope"
        case .chams: return "eye.fill"
        case .modSkin: return "tshirt.fill"
        }
    }

    var tint: Color {
        switch self {
        case .aim: return .blue
        case .chams: return .purple
        case .modSkin: return .orange
        }
    }
}

// MARK: - Home

private struct HomeView: View {
    private let apps: [LemonTargetApp] = [
        LemonTargetApp(
            id: "normal",
            name: "Free Fire",
            bundleID: "com.dts.freefireth",
            iconAssetName: "Normal"
        ),
        LemonTargetApp(
            id: "max",
            name: "Free Fire MAX",
            bundleID: "com.dts.freefiremax",
            iconAssetName: "Max"
        )
    ]

    @State private var selectedApp: LemonTargetApp?
    @State private var selectedFeature: FFH4XFeatureCategory?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageBackground
                    .ignoresSafeArea()

                if let selectedApp {
                    if let selectedFeature {
                        AppDataBrowserView(
                            targetApp: selectedApp,
                            featureCategory: selectedFeature
                        ) {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                                self.selectedFeature = nil
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    } else {
                        FeatureMenuView(
                            targetApp: selectedApp,
                            onBack: {
                                withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                                    self.selectedApp = nil
                                }
                            },
                            onSelect: { feature in
                                withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                                    self.selectedFeature = feature
                                }
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    }
                } else {
                    appChooser
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var appChooser: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 12) {
                        AppLogo(size: 46)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Minh Khang")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Text("FFH4X")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .tracking(-0.8)
                        }
                    }
                }
                .padding(.top, 12)

                VStack(spacing: 12) {
                    ForEach(apps) { app in
                        Button {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                                selectedApp = app
                            }
                        } label: {
                            AppSelectionCard(app: app)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 7) {
                    Image(systemName: "checkmark.shield.fill")
                    Text("Minh Khang")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
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
    let onSelect: (FFH4XFeatureCategory) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.bold))
                            .frame(width: 40, height: 40)
                            .background(.thinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)

                    ProjectAppIcon(assetName: targetApp.iconAssetName, size: 52)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(targetApp.name)
                            .font(.system(size: 24, weight: .bold, design: .rounded))

                        Text("")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.top, 12)

                VStack(spacing: 12) {
                    ForEach(FFH4XFeatureCategory.allCases) { feature in
                        Button {
                            onSelect(feature)
                        } label: {
                            FeatureSelectionCard(feature: feature)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("Minh Khang")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
    }
}

// MARK: - Feature Card

private struct FeatureSelectionCard: View {
    let feature: FFH4XFeatureCategory

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(feature.tint.opacity(0.13))

                Image(systemName: feature.icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(feature.tint)
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.system(size: 19, weight: .semibold, design: .rounded))

                Text(feature.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
                .frame(width: 32, height: 32)
                .background(.thinMaterial, in: Circle())
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .strokeBorder(feature.tint.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.06), radius: 15, y: 7)
    }
}

// MARK: - App Selection Card

private struct AppSelectionCard: View {
    let app: LemonTargetApp

    var body: some View {
        HStack(spacing: 12) {
            ProjectAppIcon(assetName: app.iconAssetName, size: 64)

            VStack(alignment: .leading, spacing: 5) {
                Text(app.name)
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(app.bundleID)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
                .frame(width: 30, height: 30)
                .background(.thinMaterial, in: Circle())
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .strokeBorder(AppTheme.accent.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.06), radius: 16, y: 8)
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
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.23, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
            }
    }
}

// MARK: - Installed App Icon

struct InstalledAppIcon: View {
    let bundleID: String
    let size: CGFloat

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.accent.opacity(0.10))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.23, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
        }
        .task(id: bundleID) {
            image = await Task.detached(priority: .userInitiated) {
                iconForBundleID(bundleID)
            }.value
        }
    }
}

// MARK: - Info

private struct InfoView: View {
    @EnvironmentObject private var appState: AppState

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "AppReleaseDisplayVersion") as? String
        ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        infoHero

                        supportSection

                        Text("Minh Khang")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var infoHero: some View {
        VStack(spacing: 10) {
            AppLogo(size: 72)
                .shadow(color: AppTheme.accent.opacity(0.18), radius: 18, y: 8)

            Text("FFH4X")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .tracking(-0.5)

            Text("Version \(appVersion)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var supportSection: some View {
        infoSection(title: "Phiên Bản iOS", systemImage: "iphone") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: appState.isSupported ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(appState.isSupported ? Color.green : Color.red)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(appState.isSupported ? "Thiết bị được hỗ trợ" : "Thiết bị không được hỗ trợ")
                            .font(.body.weight(.semibold))

                        Text("Theo danh sách phiên bản đã xác minh")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }

                Divider()

                SupportVersionRow(
                    title: "iOS 17 – 18",
                    detail: ExploitSupportPolicy.verifiedIOS17To18Range,
                    icon: "checkmark.circle.fill",
                    tint: .green
                )

                SupportVersionRow(
                    title: "iOS 26",
                    detail: ExploitSupportPolicy.verifiedIOS26Range,
                    icon: "checkmark.circle.fill",
                    tint: .green
                )

                VStack(alignment: .leading, spacing: 9) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Color.clear
                            .frame(width: 22, height: 22)
                            .hidden()

                        Text("iOS 27")
                            .font(.body.weight(.semibold))

                        Spacer(minLength: 8)

                        Text("Beta")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.accent.opacity(0.10), in: Capsule())
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(ExploitSupportPolicy.verifiedIOS27Builds, id: \.build) { version in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.green)
                                    .frame(width: 16, alignment: .center)

                                Text("Beta \(version.beta)")
                                    .font(.caption.weight(.medium))

                                Spacer(minLength: 8)

                                Text(version.build)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private func infoSection<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.leading, 2)

            VStack(alignment: .leading, spacing: 7) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10))
            }
            .shadow(color: Color.black.opacity(0.05), radius: 14, y: 7)
        }
    }
}

// MARK: - Support Version

private struct SupportVersionRow: View {
    let title: String
    let detail: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 22, alignment: .center)

            Text(title)
                .font(.body.weight(.semibold))

            Spacer(minLength: 10)

            Text(detail)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
