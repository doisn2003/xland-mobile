# Chạy mobile với Northflank

Backend tạm thay Railway từ 22/10/2026:
`https://p01--xland--y56gnzgzjsqm.code.run/api/v1`.
Database, tài khoản, Storage và dữ liệu hiện có dùng tiếp Supabase của dự án.

## Android Studio

Mở thư mục `xland-mobile`, chọn cấu hình **Xland Northflank** trong danh sách Run,
chọn **Pixel 9 Pro (mobile)** và bấm Run. Cấu hình chia sẻ nằm tại
`.run/Xland Northflank.run.xml`; dùng `lib/main.dart`, release và
`--dart-define-from-file=.local/auth/google-client.json`.
File client IDs này đã có trên máy hiện tại, không được commit. Máy khác tạo từ
`tool/auth/google-client.example.json`. Chỉ dùng client IDs, không dùng server keys.

SDK trên máy hiện tại là Flutter 3.47.5 / Dart 3.13.4. Build release cần
`android/key.properties` và certificate riêng đã có. Không chạy Flutter test,
pub get và build Android cùng lúc vì chúng cùng tạo plugin registrant.

## Build APK

```powershell
& .\tool\release\build.ps1
& .\tool\release\verify-artifact.ps1
```

APK: `build/app/outputs/flutter-apk/app-release.apk`, ARM64 và x86_64.
API và host chia sẻ mặc định đều là Northflank. Server công bố assetlinks cho
certificate debug và release hiện có. Không đưa các biến DB/Storage vào ứng dụng.

Đã kiểm chứng 22/10/2026: `flutter analyze` không có lỗi, 13 test cấu hình/chia sẻ
đạt, APK ARM64/x86_64 chứa API mới và không đóng gói file riêng. Android Studio
đã build/cài/chạy release trên Pixel 9 Pro, tải feed, chi tiết lô đất và liên kết
chia sẻ Northflank. Domain App Links của bản cài đã `verified`.
Chưa kiểm tra trên điện thoại Android vật lý trong lần chuyển hosting này.

## Khi chuyển về Railway

Cập nhật API trong cấu hình Run và tham số build; đồng thời cập nhật
`XLAND_SHARE_HOST` trong Dart và Gradle property `xlandShareHost` cho Android App
Links. Chạy lại kiểm tra health, đăng nhập, dữ liệu và chia sẻ trước khi phát hành.
Không thay hoặc xóa database chỉ để đổi nhà cung cấp hosting.
