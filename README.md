# xland-mobile

Share implementation (21 October 2026): feed/property share sheet, copy link and
incoming content links. Railway is deployed and Android App Links are verified
on the emulator. Use the existing **main.dart** configuration and **Pixel 9 Pro**
in Android Studio, with `--release` and the Railway API. See
[sharing implementation and acceptance](docs/SHARING.md).

Flutter client for XLand: property videos, discovery, details, administrative-area maps, visit requests and profiles. Google sign-in is configured; SMS OTP and live deposits remain disabled.

**0.2.3+5 — internal Android release, 21 October 2026.** Includes sharing, Android App Links, updated branding and transaction animation; uses the existing release certificate and Railway API. Public author profiles require backend endpoints that are still missing from the deployed service (404/400). The catalogue remains illustrative. See [release downloads](https://github.com/doisn2003/xland-mobile/releases) and [signing and release handoff](docs/INTERNAL_RELEASE.md).

## Development

Use Flutter 3.47.5 / Dart 3.13.4 and the committed lockfile:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=XLAND_API_BASE_URL=https://xland-server-production.up.railway.app/api/v1
```

For Google login, create an ignored local JSON from `tool/auth/google-client.example.json` and pass `--dart-define-from-file`. Only client IDs belong in mobile configuration; never server secrets. Debug can use `http://10.0.2.2:3002/api/v1` with a separately started local API.

## Android release

`lib/main.dart` calls `lib/bootstrap/app_main.dart`. Release requires explicit HTTPS, disables developer tools/gallery and rejects local/demo overrides.

```powershell
& .\tool\release\build.ps1
& .\tool\release\verify-artifact.ps1
```

Helpers use the workspace's pinned local SDK and private signing configuration. Review the release guide before setup or version changes. APKs, SDKs, credentials and signing keys are excluded from Git.
