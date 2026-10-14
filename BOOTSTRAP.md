# XLand Phase 1

Flutter **3.47.5**, Dart **3.13.4**, package `xland_mobile` (application ID `vn.xland.xland_mobile`, provisional for A review). SDK installed only at `C:/Users/Admin/AppData/Local/XLandTools/flutter-3.47.5`; no machine PATH changes.

PowerShell, from this repo:
```
$env:Path = 'C:\Users\Admin\AppData\Local\XLandTools\flutter-3.47.5\bin;' + $env:Path
flutter --version
flutter pub get --enforce-lockfile
flutter analyze
flutter test test/bootstrap test/domain test/data
dart format --output=none --set-exit-if-changed lib test
flutter run -d chrome
```

Only run test directories that exist. `lib/main.dart` starts C's temporary bootstrap shell. B owns `presentation/app/xland_app.dart`; no UI feature is supplied by this shell. Constructor DI and BLoC/Cubit are the accepted approach. Domain imports only Dart. Business data goes through Express; no direct Supabase table access.

Assets: B owns files under assets/images, assets/icons, assets/fonts and provides source/license metadata. C declares existing files/font weights in pubspec after B's dependency request. No remote runtime font downloads. Android/iOS/web templates copied from an isolated generator directory without replacing README, .gitignore, .env, presentation or assets.

SDK sources: [official archive](https://docs.flutter.dev/install/archive), pinned [3.47.5 release](https://github.com/flutter/flutter/tree/3.47.5). SDK clone needed repository-local `core.longpaths=true` on Windows; no global Git setting was changed. Android/iOS builds are separate checks; web smoke does not validate those targets.
