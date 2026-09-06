# Make-iPA + sing-box integration

The VPN integration follows the current `SagerNet/sing-box-for-apple` structure instead of reimplementing its Packet Tunnel engine:

- `SingBoxEngine/sing-box.xcodeproj` is embedded as a subproject.
- The upstream `Extension` target is used as the Packet Tunnel provider.
- The upstream `Library` target is used by that extension.
- The Make-iPA app embeds `Extension.appex` and `Library.framework` from the subproject.
- `ThreeOneOSFive/VPN/SingBoxVPNService.swift` only creates the `NETunnelProviderManager` and sends `configContent`.
- `ThreeOneOSFive/VPN/admin.json` is bundled into the app, so the user does not select/import a JSON file.
- The UI is `Trang chủ / Cấu hình / Thông tin`.

## Important

`Libbox.xcframework` is intentionally absent from the supplied `sing-box-for-apple` source tree. The upstream project ignores it because it is a large generated binary. The official sing-box build script generates it with `gomobile bind` from `experimental/libbox` and copies it into `sing-box-for-apple`.

Before building the IPA, place the matching `Libbox.xcframework` at:

`SingBoxEngine/Libbox.xcframework`

It must match the sing-box source used by this copy of `sing-box-for-apple`.

The Packet Tunnel is an iOS Network Extension and must be tested on a physical iOS device; a simulator is not sufficient for the real VPN tunnel.
