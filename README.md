# xland-mobile

**Debug hiện tại — 26/10/2026:** backend trên PC, API dành cho Android Emulator
`http://10.0.2.2:3002/api/v1`. Chạy `npm run dev:mobile` trong `xland-server`,
rồi chọn **Xland Local → Pixel 9 Pro → Run/Debug** trong Android Studio.
Cấu hình dùng `lib/main.dart`, hỗ trợ hot reload/hot restart và Google client IDs riêng
ở `.local/auth/google-client.json`. Xem [hướng dẫn chạy local](docs/LOCAL_DEVELOPMENT.md).
Bản **Xland Railway Release** tiếp tục dùng Railway;
xem [hướng dẫn Railway](docs/RAILWAY.md). Northflank được giữ để rollback.

Share implementation (21 October 2026): feed/property share sheet, copy link and
incoming content links. Railway is deployed and Android App Links are verified
on the emulator. Use **Xland Local** and **Pixel 9 Pro** in Android Studio for
debug development. **Xland Railway Release** and the release script produce the
signed release build without hot reload. See
[sharing implementation and acceptance](docs/SHARING.md).

Flutter client for XLand: property videos, discovery, details, administrative-area maps, visit requests and profiles. Google sign-in is configured; SMS OTP and live deposits remain disabled.

**0.2.4+6 — internal Android release, 26 October 2026.** Returns the API, sharing and Android App Links to Railway using the existing release certificate. Public author profiles and their video endpoints now pass Railway acceptance. See [Railway handoff](docs/RAILWAY.md) and [signing and release handoff](docs/INTERNAL_RELEASE.md).

## Development

Use Flutter 3.47.5 / Dart 3.13.4 and the committed lockfile:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run --debug --dart-define=XLAND_API_BASE_URL=http://10.0.2.2:3002/api/v1
```

For Google login, create an ignored local JSON from `tool/auth/google-client.example.json` and pass `--dart-define-from-file`. Only client IDs belong in mobile configuration; never server secrets. The **Xland Local** IDE configuration already includes this file and internal signing. Start the local API before running the app; see the local development guide for the full CLI command.

## Android release

`lib/main.dart` calls `lib/bootstrap/app_main.dart`. Release requires explicit HTTPS, disables developer tools/gallery and rejects local/demo overrides.

```powershell
& .\tool\release\build.ps1
& .\tool\release\verify-artifact.ps1
```

Helpers use the workspace's pinned local SDK and private signing configuration. Review the release guide before setup or version changes. APKs, SDKs, credentials and signing keys are excluded from Git.
