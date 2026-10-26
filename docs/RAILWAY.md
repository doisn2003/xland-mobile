# Mobile kết nối Railway — 26/10/2026

API production: `https://xland-server-production.up.railway.app/api/v1`.
Backend dùng tiếp database, tài khoản và Storage Supabase hiện có.

Trong Android Studio, chọn **Xland Railway Release** để chạy bản release với API Railway.
Cấu hình nằm ở `.run/Xland Railway Release.run.xml`.
Bản **debug** hiện dùng **Xland Local**, kết nối backend trên PC ở cổng 3002;
xem [hướng dẫn local](LOCAL_DEVELOPMENT.md). Cấu hình chạy `lib/main.dart` với
Google client IDs riêng tại `.local/auth/google-client.json`.
Khi Run/Debug từ IDE, phiên Flutter đang kết nối hỗ trợ Hot Reload và Hot Restart.
Mở APK từ biểu tượng launcher riêng sẽ không tự tạo phiên Flutter cho IDE.

Để máy giả lập hiện bên trong Android Studio: **Settings → Tools → Emulator →
Launch in the Running Devices tool window**. Chọn Pixel 9 Pro trên thanh công cụ
rồi Run; mở **View → Tool Windows → Running Devices** nếu cửa sổ đang ẩn.

Run debug nội bộ dùng `--android-project-arg=xlandInternalDebugSigning=true`
để ký bằng certificate nội bộ hiện có. Điều này cho phép cài đè APK release cùng
package trên Pixel 9 Pro, giữ dữ liệu và Google/App Links, đồng thời vẫn có debug
VM. Khóa riêng chỉ dùng trong Gradle, không được đóng gói vào APK. Debug thông
thường không truyền cờ này vẫn dùng debug key mặc định.

Chọn **Xland Railway Release** hoặc dùng script bên dưới khi cần bản release.
Release không hỗ trợ hot reload/hot restart.
Bản Railway Release không cần chạy API trên PC. Cấu hình **Xland Northflank** được giữ để quay lại
khi cần và có đủ override cho cả API, Dart sharing host lẫn Android App Links.

Build bằng Flutter 3.47.5 / Dart 3.13.4 đã có trong workspace:

```powershell
& .\tool\release\build.ps1
& .\tool\release\verify-artifact.ps1
```

Script mặc định dùng Railway; khi truyền `-ApiBaseUrl`, script lấy hostname đó
cho cả `XLAND_SHARE_HOST` và Gradle `xlandShareHost` để tránh lệch liên kết.
APK `build/app/outputs/flutter-apk/app-release.apk` là bản **0.2.5+8**, ARM64 và
x86_64, ký bằng certificate release hiện có. Không đưa secret DB/Storage vào
ứng dụng. Các file signing/client IDs riêng vẫn bị loại khỏi Git.

Ứng dụng Northflank đã cài trước đây cần cập nhật APK mới để đổi API đã được
biên dịch. Không thể đổi endpoint của APK cũ chỉ bằng thao tác deploy server.
Kết quả kiểm chứng và APK bàn giao ở `../../releases/android/railway-20261026/`
và `../../brain/reports/railway-20261026/`.

Bản thử quy hoạch ngày 26/10 nằm tại
`../../releases/android/planning-20261026/xland-0.2.5-planning.apk`.
Cài đè bản Railway đã có, mở `XL-028`/`XL-029` (Hà Nội) hoặc
`XL-030`/`XL-031`/`XL-P3-008` (Hải Phòng), chọn **Khu vực → Quy hoạch**.
Thanh độ đậm điều chỉnh 0–100%; có chế độ toàn màn hình và hướng dẫn xem quy hoạch.
Giao diện hiện không hiển thị nhãn hoặc liên kết thương hiệu của nguồn quy hoạch.
Bản đồ hiện ở mức xã/phường, chưa có vị trí/ranh thửa chính xác.
