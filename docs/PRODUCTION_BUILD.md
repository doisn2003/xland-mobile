# Build Xland production — Android APK và iOS IPA

Cập nhật 28/10/2026. Phiên bản source: **0.2.6+9**.
API: `https://xland-server-production.up.railway.app/api/v1`.
Website user: `https://xland-alpha.vercel.app`; admin: `/admin`.
API, tài khoản và dữ liệu dùng chung giữa web và mobile. Bản phát hành không cần
server trên PC. Backend vẫn dùng dataset pilot hiện có; kết nối production không
chứng minh tính xác thực pháp lý của dữ liệu.

## 1. Chuẩn bị chung

- Checkout nhánh `main` đã push. Dùng **Flutter 3.47.5 / Dart 3.13.4**, giữ
  `pubspec.lock` và các package vendored trong `third_party/`.
- Chạy `flutter pub get --enforce-lockfile`, `flutter analyze --no-pub`,
  `flutter test --no-pub` trước khi build. Các test opt-in có skip được ghi riêng.
- Release dùng `lib/main.dart`, HTTPS rõ ràng; không dùng `dev_main.dart`,
  report mode, demo media hoặc địa chỉ `10.0.2.2`.
- `tool/release/production.json` chứa endpoint/hostname công khai cho iOS/CLI.
  Android helper mặc định cùng endpoint và đồng bộ host vào Dart/manifest.
- Tăng số sau dấu `+` trong `pubspec.yaml` cho mỗi bản cập nhật phân phối.
  Không đổi package/bundle ID hoặc tạo lại signing key để build thường ngày.
- Không commit `.env`, `.local`, `key.properties`, keystore, chứng chỉ, IPA/APK.
  OAuth client ID là cấu hình công khai; **client secret** không thuộc ứng dụng.

## 2. Android APK trên Windows

Máy cần Android SDK và JDK tương thích Flutter (Android Studio hiện có đáp ứng).
Chuẩn bị hai đầu vào riêng qua kênh lưu trữ an toàn:

1. `android/key.properties`, trỏ tới keystore release hiện có, gồm `storeFile`,
   `storePassword`, `keyAlias`, `keyPassword`. `storeFile` được Gradle giải quyết
   từ `android/app`; ưu tiên đường dẫn tuyệt đối dùng dấu `/` trên Windows.
2. `.local/auth/google-client.json` theo `tool/auth/google-client.example.json`.
   Android cần `GOOGLE_SERVER_CLIENT_ID` loại Web đã được backend chấp nhận;
   `GOOGLE_CLIENT_ID` để rỗng trên Android. Google Console cần Android OAuth
   client đúng package `vn.xland.xland_mobile` và SHA-1 của certificate release.

Trong PowerShell tại repo mobile:

```powershell
# Chỉ cần đặt nếu SDK không nằm trong .local/flutter-3.47.5-native.
$env:XLAND_FLUTTER_SDK = 'C:/duong-dan/flutter-3.47.5'
./tool/release/build.ps1
./tool/release/verify-artifact.ps1
```

Output: `build/app/outputs/flutter-apk/app-release.apk`, ARM64 và x86_64.
Script kiểm SDK và lockfile, ký bằng key hiện có; verifier kiểm API trong cả hai
AOT, đủ engine và không có file secret. Kiểm chữ ký thêm bằng Android build-tools:

```powershell
apksigner verify --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb shell pm get-app-links vn.xland.xland_mobile
```

`apksigner`/`adb` cần có trong PATH hoặc gọi bằng đường dẫn Android SDK. Certificate
release SHA-1 hiện có: `53:8A:B5:44:D1:71:F8:04:60:CF:06:18:DC:C7:EF:95:2B:0E:3C:D2`.
Không uninstall để xử lý lỗi chữ ký nếu chưa sao lưu/được phép xóa dữ liệu.
Google Play cần `.aab`; có thể dùng cùng cờ build với `flutter build appbundle`,
nhưng helper APK và bằng chứng APK không thay cho kiểm AAB/Play Console.

Android Studio: **Xland Railway Release** chạy release production. **Xland Local**
là debug API trên PC, dùng khi phát triển; không phân phối bản đó cho người dùng.

## 3. iOS IPA trên macOS

Không build IPA trên Windows. Cần Mac, Xcode, SDK iOS, Flutter đúng phiên bản và
Apple Developer Team có certificate/provisioning cho **`vn.xland.xlandMobile`**
(bundle iOS khác cách viết package Android). Chưa có ID thì đăng ký với Apple
và tạo app record trong App Store Connect bằng tài khoản của chủ dự án.

Repo dùng **Swift Package Manager**, không có Podfile. Helper bật SPM trong Flutter
trên máy build; nếu thao tác thủ công, chạy `flutter config --enable-swift-package-manager`.
Chạy `flutter pub get`
để Flutter tạo package plugin, rồi mở `ios/Runner.xcworkspace` trong Xcode.
Chọn Runner → Signing & Capabilities → đúng Team, signing profile, Associated
Domains và Keychain Sharing. Giữ deployment target ít nhất iOS 15.0.

Tạo `.local/auth/google-client-ios.json` theo mẫu sau, thay bằng ID thật:

```json
{
  "GOOGLE_CLIENT_ID": "IOS_CLIENT_ID.apps.googleusercontent.com",
  "GOOGLE_SERVER_CLIENT_ID": "WEB_SERVER_CLIENT_ID.apps.googleusercontent.com"
}
```

ID thứ nhất phải thuộc OAuth client **iOS** gắn với bundle trên. ID thứ hai là
Web/server client hiện đang dùng trên Android và có trong `GOOGLE_AUTH_AUDIENCES`
của backend. Không dùng Android client ID thay cho iOS client ID.

```bash
export XLAND_APPLE_TEAM_ID='YOURTEAMID'
export XLAND_FLUTTER_SDK='/duong-dan/flutter-3.47.5'
bash tool/release/build-ios.sh
```

Helper yêu cầu Team ID thật (10 ký tự) và đủ OAuth IDs, tự tạo file ignored
`ios/Flutter/GoogleSignIn.xcconfig` chứa callback URL scheme và Team. Info.plist
đã nối scheme này; Dart nhận client IDs qua build defines. Không ghi secret vào
Xcode project. Script chỉ build, không upload hay gửi app đi xét duyệt.

Output: `build/ios/archive/*.xcarchive` và `build/ios/ipa/*.ipa`.
Mặc định export `app-store` để dùng TestFlight/App Store. Với thiết bị đã đăng ký:

```bash
XLAND_IOS_EXPORT_METHOD=ad-hoc bash tool/release/build-ios.sh
```

Profile phải hỗ trợ đúng phương thức export và UDID thiết bị nếu cần. Khi build
báo thiếu signing/provisioning, sửa trong Xcode, không tắt code signing để gọi đó
là IPA có thể cài. Kiểm archive bằng Xcode Organizer → Validate App, rồi upload
qua Organizer hoặc Transporter khi chủ dự án sẵn sàng phát hành.

Để Universal Links iOS mở ứng dụng, đặt biến **`SHARE_APPLE_APP_ID`** trên Railway
bằng `<App ID prefix>.vn.xland.xlandMobile`, với prefix thực tế từ provisioning
profile (thường là Team ID), rồi redeploy. Kiểm endpoint
`/.well-known/apple-app-site-association` có đúng appID và thử trên iPhone.
Chưa có Apple Team/provisioning thì không thể nghiệm thu IPA hoặc Universal Links.

## 4. Kiểm tra bản cài

Trên Android/iPhone thật: mở feed, phát video, danh sách/chi tiết/lô con, bộ lọc,
bản đồ, đăng nhập, lưu tài sản, sửa hồ sơ, đóng/mở lại app, đăng xuất và mở link
chia sẻ. So sánh cùng tài khoản trên website. Không tạo lịch hẹn/giao dịch thật
chỉ để kiểm thử. SMS/thanh toán/NFT vẫn theo capability và policy của backend.

Khi rollback, chọn deployment server/web trước đó tương thích schema; không xóa
database. Mobile chỉ đổi endpoint sau khi build/cài phiên bản mới. Hạ versionCode
không phải cập nhật APK hợp lệ; dùng build number mới ngay cả khi revert source.

## Tài liệu chính thức

- [Flutter: Android release](https://docs.flutter.dev/deployment/android)
- [Flutter: iOS archive, export và ký](https://docs.flutter.dev/deployment/ios)
- [Google Sign-In iOS: client ID và URL scheme](https://pub.dev/packages/google_sign_in_ios)

Các hướng dẫn trên đã đối chiếu ngày 28/10/2026. IPA, TestFlight và thiết bị iOS
vẫn cần nghiệm thu trên Mac/iPhone; test Flutter trên Windows không thay bước đó.
