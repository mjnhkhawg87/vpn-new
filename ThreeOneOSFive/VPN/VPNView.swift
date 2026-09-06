import SwiftUI

struct VPNView: View {
    @StateObject private var vpn = SingBoxVPNService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: "network.badge.shield.half.filled")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(AppTheme.accent)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Cấu hình")
                                    .font(.title.bold())
                                Text("sing-box TUN")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }

                        VStack(spacing: 10) {
                            Image(systemName: vpn.isRunning ? "checkmark.shield.fill" : "shield.slash.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(vpn.isRunning ? .green : .secondary)

                            Text(vpn.isRunning ? "Đang chạy" : "Đã tắt")
                                .font(.headline)

                            Text("admin.json được tích hợp sẵn — không cần chọn file")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))

                        Button {
                            Task { await vpn.toggle() }
                        } label: {
                            Label(
                                vpn.isRunning ? "TẮT VPN" : "BẬT VPN",
                                systemImage: vpn.isRunning ? "power" : "play.fill"
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(vpn.isRunning ? .red : AppTheme.accent)
                        .disabled(vpn.busy)

                        HStack(spacing: 10) {
                            Image(systemName: "doc.badge.gearshape")
                            Text("admin.json")
                                .font(.subheadline.monospaced())
                            Spacer()
                            Text("Đã tích hợp")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.green)
                        }
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))

                        if let error = vpn.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Cấu hình")
            .task { await vpn.load() }
        }
    }
}
