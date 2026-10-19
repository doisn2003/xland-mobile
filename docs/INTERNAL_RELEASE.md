# Internal release 0.2.0+2 — Android

19 October 2026 · `vn.xland.xland_mobile` · Flutter 3.47.5 / Dart 3.13.4.

## Milestones

1. **Phase 3 features:** presentation/components and API composition; Google/session transitions; video/social, discovery, details, calculator, booking/history/profile; flutter_map/Geoapify and Google Maps links.
2. **Data and verification:** generated scenery/portraits and licensed fonts, data/session regressions, responsive/presentation tests and isolated native/booking scenarios. Backend mock enrichment is in xland-server.
3. **Phase 4 delivery:** release signing, XLand launcher identity, ARM64/x64 packaging, explicit HTTPS, no DEV gallery/banner, build/content/snapshot helpers and handoff.

## Configuration and signing

Android 7+ (minSdk24), ARM64 phones and x64 emulators. Both ABIs contain AOT and engine libraries; plugin-only ARMv7 libraries do not advertise unsupported devices.

Private files, excluded from Git: `.local/auth/google-client.json` (Web OAuth client ID as GOOGLE_SERVER_CLIENT_ID), `.local/signing/xland-internal-release.jks`, signing `credentials.json`, and `android/key.properties`.

The owner already provisioned and registered the release certificate. **Do not regenerate it for routine builds.** Back up the key/passwords outside this working disk. Keep package/key and increment versionCode for updates. Debug APKs use another certificate; do not uninstall or clear user data as the default update path.

Release SHA-1: `53:8A:B5:44:D1:71:F8:04:60:CF:06:18:DC:C7:EF:95:2B:0E:3C:D2`.

`tool/release/build.ps1` uses the pinned local SDK/private inputs and disables a stale Gradle daemon in this workspace. Release entry requires HTTPS and rejects demo/report/local overrides. Verify the APK after every build.

## Artifact and checks

The artifact is handed off outside Git: `../releases/android/0.2.0+2/XLand-0.2.0+2-internal.apk` in the shared workspace. It is not a public GitHub release.

- 57,501,724 bytes; SHA-256 `744b071e76c0cb36650a4fba7d5605c55d506733722fbd53f340dd7dc10d3c4e`.
- API `https://xland-server-production.up.railway.app/api/v1`; no PC server required.
- Android v2 signature/certificate/package/ABI verified; expected HTTPS URL in both AOT binaries; no private key/config files packaged.
- Flutter analyzer0; 165 tests passed; 6 screenshot tests skipped because capture is opt-in. Backend: 21 unit tests and 22 real HTTPS check groups passed.
- **Pending:** owner said they will install and report back. Google/video/maps/restart on this exact release have not yet been accepted on a phone.

Shared backlog and operations handoff are in `../brain/19_PHASE3_REMAINING.md` and `21_INTERNAL_RELEASE_RUNBOOK.md`, outside this repository.

## Internal tester guide

Transfer the signed APK to an Android 64-bit phone and open it in the file manager. Allow installation from that source if Android asks. Browse as guest or choose Tôi → Đăng nhập → Google. If OAuth is in Testing, add permitted accounts through Google Auth Platform as required; never request passwords.

Test login, video, like/unlike and retained state, map and both Google buttons, restart, logout/relogin. Report device/Android version, action and time without credentials. The catalogue is mock; visit requests are not confirmed appointments. Do not transfer deposits: payment/SePay and SMS are disabled. Private documents, some sharing links, iOS, chatbot/admin/NFT remain deferred.
