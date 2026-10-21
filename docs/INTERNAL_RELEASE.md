# Internal release — Android

## Current: 0.2.3+5 — 21 October 2026

Packages the current mobile source, including native sharing and incoming links,
branding, the transaction animation and direct backend author-profile requests.
Uses `lib/main.dart`, explicit Railway HTTPS and the existing release key for
ARM64/x64. Android Studio uses the existing **main.dart** configuration and
**Pixel 9 Pro** device. No extra emulator or run configuration is required.

Pre-publication validation: 225 Flutter tests passed, 7 opt-in tests skipped;
`flutter analyze` reported no issues. All 250 vendored upstream files matched
their recorded SHA-256 hashes. Private signing/configuration files remain
excluded from Git. Vendored sources retain their original bytes on checkout.

The APK is distributed separately from Git as a GitHub Release asset. Download
the latest internal build from [GitHub Releases](https://github.com/doisn2003/xland-mobile/releases).
Older APK files are removed during this handoff; the following sections retain
historical checksums and acceptance results, rather than active download paths.

Known deployment limitation: the live author-profile endpoint returns 404 and
the paginated author-video endpoint returns 400. Share creation returns 200.
These are read-only checks against Railway on 21 October 2026. This internal
build includes the direct endpoint implementation and does not restore the
temporary compatibility workaround. Author-profile production completion
requires the backend deployment described below. The catalogue is illustrative.

## Backend author endpoints required

The temporary compatibility path has been removed at the owner's request.
Profiles and author videos now use their backend endpoints exclusively. The
production fix remains incomplete until the backend is deployed and direct live
acceptance passes. The previous 0.2.2+4 build is historical evidence of the
workaround, not the final fix. Its APK is superseded by the current internal
release. See [author-profile contract and rollout](AUTHOR_PROFILES.md).

## Historical workaround: 0.2.2+4 — 21 October 2026

Fixes public author profiles on the API currently running on Railway. The new
author endpoints were present locally but absent from the deployed server,
causing the profile screen to show `Resource not found`. The app now verifies
the author through the source video when those endpoints are unavailable,
supports ordinary posters and consultant authors, and filters public videos by
the author ID. Property contact actions retain the assigned consultant ID.
Unavailable totals are omitted. See [profile behavior and verification](AUTHOR_PROFILES.md).

37 targeted Flutter tests pass, including real HTTPS requests to Railway;
analyzer reports no issues. On Pixel 9 Pro, the signed release was installed
over the existing app with the same certificate, preserving app data. Both
avatars and the name opened Ngọc Anh, her video loaded and pagination completed,
and property contact opened Quang Quân. No live follow/booking writes were made.

Artifact: `../releases/android/0.2.2+4/XLand-0.2.2+4-internal.apk`.
59,221,837 bytes; SHA-256
`d0ec2ad2b4753fa1a95cc81fba565b5fa33d871b4e8ff37aef7845282fa1d67a`.
Signature v2, versionCode 4, ARM64/x64 AOT, configured HTTPS API and absence of
private files were verified. Backend deployment is still subject to Railway's
current build/deploy incident; this Android fix works with the existing server.
No database migration or seed is required.

## Previous: 0.2.1+3 — 21 October 2026

Adds feed/property native sharing, copy link, incoming content links and verified
Android App Links against `xland-server-production.up.railway.app`. Built in real
Flutter release mode with the existing internal release key, with no report/demo
overrides. Use the existing Android Studio configuration **main.dart** and
device **Pixel 9 Pro**. The extra release configuration and emulator were removed
at the owner's request after the acceptance recorded below. A debug-signed app
must be uninstalled before installing the differently signed release, so local
data removal requires the owner's approval.

The owner subsequently approved removing the debug app on Pixel 9 Pro. The
portable signed release 0.2.1+3 is now installed there; Android confirms the
release certificate, non-debuggable package and verified Railway App Links.

Artifact: `../releases/android/0.2.1+3/XLand-0.2.1+3-internal.apk`.
59,221,837 bytes; SHA-256
`1d34b501229be58dd9b14e037a968d1a71855411e3db398e0916989242f89db8`.
Verified release certificate, versionCode 3, non-debuggable manifest, ARM64/x64
AOT/engine libraries, explicit Railway origin in both AOT binaries and absence
of private configuration/key files. Configuration/sharing tests: 13 passed;
analyzer: no issues. Android Studio built and launched the release on the new
emulator; Android and Google verified its App Links. Feed/video native sharing
was visually checked. Further UI inspection stopped on a capture-helper GPU
error; see the sharing acceptance for the exact scope.
See [sharing acceptance](SHARING.md) for scope and evidence. Catalogue data remains
illustrative; this is an internal signed release, not a claim that all services
and production data are ready for commercial launch.

## Previous: 0.2.0+2 — 19 October 2026

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
