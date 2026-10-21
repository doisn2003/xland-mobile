# Pinned third-party runtime sources

`lottie/` contains the unchanged runtime library, pubspec, license and upstream
documentation from **lottie 3.3.3**, used to render the supplied transaction art.
It is a local path dependency so Android Studio builds resolve its source inside
this workspace instead of the external Windows Pub Cache path that failed in
the IDE. This is not an upgrade or a fork of the player's implementation.

Source: https://pub.dev/packages/lottie/versions/3.3.3

Archive: https://pub.dev/api/archives/lottie-3.3.3.tar.gz

SHA-256: `8b6359a7422167014aa73ce763fa133fb832065dcc0ac4d1dec1f603a5cef7d0`

The archive checksum matches the previous hosted entry in `pubspec.lock`.
`lottie/UPSTREAM.json` records hashes of every included upstream file. All files
listed there are unmodified. The upstream MIT license is in `lottie/LICENSE`.
Upstream examples, development tools and tests are intentionally not vendored.
Third-party sources are excluded from application lint rules; the application's
integration remains covered by its normal analyzer and widget tests.

Update deliberately: verify the new archive's checksum, review upstream changes,
replace the package and hash manifest together, then run application analysis,
transaction widget tests and the Android Studio debug build.

## Sharing runtime packages

Android Studio also failed to read the newly installed sharing packages from
the external Pub Cache (the CLI build could read them). The same workspace-local
approach is used for the following unchanged, pinned upstream packages:

| Package | Version | Source |
| --- | --- | --- |
| share_plus | 13.3.1 | https://pub.dev/packages/share_plus/versions/13.3.1 |
| share_plus_platform_interface | 7.2.0 | https://pub.dev/packages/share_plus_platform_interface/versions/7.2.0 |
| cross_file | 0.3.5+5 | https://pub.dev/packages/cross_file/versions/0.3.5%2B5 |
| mime | 2.1.0 | https://pub.dev/packages/mime/versions/2.1.0 |

Archives were downloaded from pub.dev and their SHA-256 checksums matched the
previous hosted entries in `pubspec.lock`. Each directory includes its upstream
license, pubspec, runtime files, native platform sources where applicable and
`UPSTREAM.json` with archive/file hashes. No upstream source was modified.
Examples and upstream tests are excluded. The share plugin is a path dependency;
its three transitive dependencies are pinned through root dependency overrides.

When upgrading, verify archive checksums and update these packages deliberately,
then run `flutter analyze`, sharing tests and a build from Android Studio.
