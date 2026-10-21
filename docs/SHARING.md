# Share feature — 21 October 2026

Feed video and property detail now use the common `ShareSheet`: load the canonical
HTTPS URL, open the platform share UI, or copy/select the link. Errors support
retry and never expose raw platform exceptions. Dismissing the sheet is not
reported as a sent message. Web sharing is initiated from a separate button after
the URL loads to preserve browser user activation; unsupported browsers can copy.

`ContentLink` accepts the configured HTTPS host, supported content paths and UUIDs.
`XLandApp` routes both cold and warm links, retaining Home below cold-start content.
`SharedVideoPage` fetches the specific video, respects playback preferences and
app lifecycle, and offers a retry/unavailable state. A covered feed does not play
behind the deep-linked screen. Existing auth requirements still apply to actions.

The default host is `xland-server-production.up.railway.app`. Android's manifest
and iOS Associated Domains are configured for that origin; server association
files must contain the real signing identities before verified links work.
An old APK will not gain native incoming-link support by updating the server.

The companion server supplies public HTML with Open Graph metadata and a browser
fallback. The independent mock website does not need a share button or new data
for this design. See [server architecture and rollout](../../xland-server/docs/SHARING.md).

Verify with `flutter analyze`, `flutter test` and an Android build. Targeted
coverage is in `test/presentation/sharing_test.dart`: both UI entry points,
native payload/anchor, copy, retry, cancellation, disposal, invalid links, cold and
warm navigation, exact video loading, and narrow/landscape layouts with large text.
Real Zalo/Messenger/Facebook/WhatsApp/TikTok card rendering and iOS Universal Links
require device acceptance; the OS and receiving app control destination support.

## Current signed release — 0.2.1+3, 21 October 2026

Use the existing **main.dart** configuration and **Pixel 9 Pro** in Android
Studio. The extra **XLand Railway RELEASE** configuration and **XLand Release
API 37** emulator were removed at the owner's request. The existing main.dart
configuration uses `--release`, the Railway `/api/v1` API and the private Google
client configuration, with no report/demo override. A debug-signed installation
on Pixel cannot be updated in place with the release certificate; uninstalling
that app loses its local data and requires the owner's approval. The earlier
release acceptance on the subsequently removed emulator is recorded below.

After explicit owner approval, the debug app on **Pixel 9 Pro** was uninstalled
and the verified portable release 0.2.1+3 was installed successfully. Android
reports the release certificate, no DEBUGGABLE flag, and Railway domain
`verified`. The existing `main.dart` configuration is saved with `--release`,
the Railway API and Google client configuration. Installation evidence is in
`.local/share-release-acceptance/pixel-installation.json` and `pixel-*.txt`.

The earlier configuration omitted `--release`, which made Android Studio run a
debug build with developer Gallery. The debug banner also incorrectly hardcoded
`API LOCAL` even when the API was Railway. It now derives the environment label
from the actual API host. Release mode disables developer routes and the banner
and rejects local/demo/report configurations.

```powershell
flutter build apk --release --target-platform android-arm64,android-x64 --dart-define=XLAND_API_BASE_URL=https://xland-server-production.up.railway.app/api/v1 --dart-define-from-file=.local/auth/google-client.json
```

Portable artifact: `../releases/android/0.2.1+3/XLand-0.2.1+3-internal.apk`,
59,221,837 bytes. SHA-256:
`1d34b501229be58dd9b14e037a968d1a71855411e3db398e0916989242f89db8`.
Verified versionCode 3, versionName 0.2.1, no debuggable manifest flag, AOT and
engine libraries for ARM64/x64, the Railway API in both AOT binaries, and no
private configuration/key files in the archive. Certificate SHA-256:
`DF:50:77:55:0E:D2:FC:D0:B8:40:34:69:B8:C2:8A:A7:EB:0C:66:A3:16:4E:A8:34:0A:7B:FF:80:C8:67:EB:9C`.
All 13 configuration/sharing tests passed for this revision; `flutter analyze`
reported no issues. Android Studio then built, installed and launched release
successfully on **XLand Release API 37** at 13:52 local time. Its device-specific
APK is 39,729,643 bytes, SHA-256
`2f9e81cf980bd727af1a2062db945db6d7727417c223f1c3f09adb54671b1288`.
Use the portable artifact above for phones; Flutter Run rebuilds
`build/app/outputs/flutter-apk/app-release.apk` for the selected device.

Android reports the installed version 0.2.1+3, no DEBUGGABLE flag, and Railway
domain `verified` with the release certificate. Google's Digital Asset Links
check independently returned `linked: true` for that certificate. The feed
screen visibly has no DEV ribbon. Local binary, signing and device evidence is
under `.local/share-release-acceptance/`.

On this release, the feed Share button opened the common sheet with the exact
public video URL, and its share action opened Android's native chooser with the
same URL. Screenshots were saved. After cancelling the chooser, the capture
helper failed with `Direct3D11CaptureFramePool.CreateFreeThreaded`, GPU suspended,
`0x887A0005`; one window re-selection/retry also failed. Further UI inspection
stopped. The release menu and property Share were not visually rechecked after
that failure; developer routes are disabled by release composition, and both
share entry points passed automated tests. The earlier property UI acceptance
below was on the debug build and must not be presented as release UI evidence.

Release packaging does not change the maturity or provenance of backend data:
the Railway catalogue remains illustrative. Receiving-app preview cards still
require testing inside those applications.

## Earlier debug acceptance — superseded for release handoff

The previous **XLand Railway Share** configuration ran on the Pixel 9 Pro
emulator in debug mode. The following results are historical debug evidence;
use the signed release configuration above for current acceptance.

The debug APK was rebuilt with:

```powershell
flutter build apk --debug --target-platform android-arm64,android-x64 --dart-define=XLAND_API_BASE_URL=https://xland-server-production.up.railway.app/api/v1 --dart-define-from-file=.local/auth/google-client.json
```

Final artifact: `build/app/outputs/flutter-apk/app-debug.apk`, rebuilt from Android
Studio at 13:16 on 21 October 2026 for the x64 emulator (164,074,736 bytes).
SHA-256: `388394D28772A7F1131B50C0041B785A52C94D9E109C5267059C7E4BE53AAC81`.
The command above builds both phone ARM64 and emulator x64 when a portable debug
APK is needed. The final IDE run built, installed and launched successfully.
Installed with an in-place update on `emulator-5554`; existing app data retained.
The installed package is `vn.xland.xland_mobile`. Android reports
`xland-server-production.up.railway.app: verified` after re-verification.
Railway publishes both this workstation's debug and the internal release
certificate fingerprints. A different developer workstation must register its
own debug fingerprint, or use a build signed with the registered release key.

Both feed and property-detail Share buttons opened the common sheet with the
matching `/videos/:id` and `/properties/:id` URLs. The video action also opened
the Android system chooser with the exact HTTPS link. Copy displayed its success
state. The emulator's
installed share destinations include Messages, Gmail and Chrome; commercial chat
apps require installation and actual card acceptance on the owner's device.

On this Windows workstation an already-running Kotlin compiler daemon initially
produced an empty plugin output, causing `SharePlusPlugin` to be missing at Java
compilation. Compiling in the fresh Gradle process produces the actual native
class. A reused Gradle daemon also held a stale plugin directory. Project-local
`android/gradle.properties` now disables daemon reuse and uses in-process,
non-incremental Kotlin compilation, so the normal Flutter/IDE build succeeds.
The equivalent explicit command is:

```powershell
cd android
.\gradlew.bat :app:assembleDebug --no-daemon '-Pkotlin.compiler.execution.strategy=in-process' '-Pkotlin.incremental=false'
```

No upstream package source, global Gradle configuration or unrelated running
daemon was changed for this workaround; clean builds can be slower.

The first actual IDE run then exposed a separate missing-file error while reading
the new packages in the external Pub Cache, despite a successful CLI build.
Following this repository's existing Lottie setup, `share_plus` 13.3.1 and its
three new transitive runtime packages now use unchanged workspace-local sources.
See `third_party/README.md` and each `UPSTREAM.json` for archive checksums, licenses
and per-file hashes. All archive checksums match the original hosted lockfile.
The final IDE run succeeded after this fix. Analyzer and all 10 sharing tests
also passed against the workspace-local dependencies.

Native verification scope: the domain was verified by Android and Google's
Digital Asset Links service. Cold/warm routing passed widget tests. A separate
ADB activity-launch probe was rejected by automatic policy review with only
`blocked by policy`; no claim is made that that probe ran successfully. Opening
links from a receiving chat app remains part of device acceptance.

Local verification completed: `flutter analyze` clean; the full Flutter run
passed 211 tests (6 existing skips), then the final targeted share suite passed
10 tests including three additional responsive cases. The share sheet was rendered
and visually checked at 390 × 844. Android `:app:assembleDebug` passed with the
command above. After rollout, analyze and all 10 targeted sharing tests passed
again. iOS build/device validation and actual receiving-app previews remain
pending; the server and Android debug build are now deployed for testing.
