import Foundation
import NetworkExtension
import Combine

@MainActor
final class SingBoxVPNService: ObservableObject {
    static let shared = SingBoxVPNService()

    @Published private(set) var status: NEVPNStatus = .disconnected
    @Published private(set) var errorMessage: String?
    @Published private(set) var busy = false

    private var manager: NETunnelProviderManager?
    private var observer: NSObjectProtocol?
    private let providerBundleID = "com.apple.mobile.MobileHouseArrest.extension"

    private init() {
        observer = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let connection = note.object as? NEVPNConnection else { return }
            Task { @MainActor in self?.status = connection.status }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    var isRunning: Bool {
        status == .connected || status == .connecting || status == .reasserting
    }

    func load() async {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            manager = managers.first {
                ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == providerBundleID
            }
            status = manager?.connection.status ?? .disconnected
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggle() async {
        if isRunning {
            stop()
        } else {
            await start()
        }
    }

    func start() async {
        guard !busy else { return }
        busy = true
        errorMessage = nil
        defer { busy = false }

        do {
            let tunnelManager = try await prepareManager()
            guard let session = tunnelManager.connection as? NETunnelProviderSession else {
                throw VPNError.invalidSession
            }

            guard let configURL = Bundle.main.url(forResource: "admin", withExtension: "json") else {
                throw VPNError.missingConfig
            }
            let config = try String(contentsOf: configURL, encoding: .utf8)

            // This is the same contract used by sing-box-for-apple's ExtensionProvider.
            try session.startTunnel(options: ["configContent": NSString(string: config)])
            status = session.status
        } catch {
            status = .disconnected
            errorMessage = error.localizedDescription
        }
    }

    func stop() {
        (manager?.connection as? NETunnelProviderSession)?.stopTunnel()
        status = .disconnecting
    }

    private func prepareManager() async throws -> NETunnelProviderManager {
        if let manager { return manager }

        let tunnelManager = NETunnelProviderManager()
        let tunnelProtocol = NETunnelProviderProtocol()
        tunnelProtocol.providerBundleIdentifier = providerBundleID
        tunnelProtocol.serverAddress = "sing-box"
        tunnelProtocol.disconnectOnSleep = false

        tunnelManager.protocolConfiguration = tunnelProtocol
        tunnelManager.localizedDescription = "Minh Khang VPN"
        tunnelManager.isEnabled = true

        try await tunnelManager.saveToPreferences()
        try await tunnelManager.loadFromPreferences()
        manager = tunnelManager
        return tunnelManager
    }

    enum VPNError: LocalizedError {
        case missingConfig
        case invalidSession

        var errorDescription: String? {
            switch self {
            case .missingConfig:
                return "Không tìm thấy admin.json trong app bundle."
            case .invalidSession:
                return "Không thể tạo Packet Tunnel session."
            }
        }
    }
}
