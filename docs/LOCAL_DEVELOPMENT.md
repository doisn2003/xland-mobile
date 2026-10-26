# Debug trên Android Emulator với backend local

Trong Android Studio, **Xland Local** chạy `lib/main.dart` ở chế độ debug,
kết nối `http://10.0.2.2:3002/api/v1`. `10.0.2.2` là địa chỉ Android Emulator
dùng để truy cập máy tính đang chạy Android Studio. Trên PC, API là
`http://localhost:3002/api/v1`.

## Khởi động xland-server

Mở PowerShell hoặc Terminal trong Android Studio:

```powershell
cd C:\OwnProject\XLAND-PROJECT\xland-server
npm run dev:mobile
```

Đợi dòng `Xland local API ready: http://localhost:3002/api/v1`.
Giữ terminal mở trong lúc dùng ứng dụng. `Ctrl+C` dừng server; sửa mã server
sẽ tự khởi động lại nhờ `tsx watch`. Không cần build server trước.
Nếu mới tải source hoặc thiếu `node_modules`, chạy `npm ci` trước một lần.
Workspace dùng Node 24.19.0 / npm 11.17.0.

Kiểm tra API trên PC tại `http://localhost:3002/health/ready`, hoặc:

```powershell
Invoke-RestMethod http://localhost:3002/health/ready
```

Lệnh này đọc `.env.supabase-mock` và các cấu hình riêng hiện có:
`.env.auth`, `.env.maps`, `.env.geoapify`, `.env.p3-enrichment`.
Backend chạy trên PC nhưng **database vẫn là Supabase mẫu hiện có**, gồm các
lô đất Hà Nội/Hải Phòng. Cần Internet để truy cập Supabase và nguồn bản đồ.
Lệnh khởi động không migrate hoặc seed lại dữ liệu. Các file `.env` chỉ ở server.
Lớp quy hoạch được bật mặc định trong lệnh này; nền Geoapify dùng cấu hình riêng.
Liên kết chia sẻ công khai vẫn dùng trang HTTPS Railway cho cùng dữ liệu mẫu.

## Chạy mobile và hot reload

1. Chọn cấu hình **Xland Local** và thiết bị **Pixel 9 Pro** trong Android Studio.
2. Stop phiên app cũ, rồi **Run** hoặc **Debug** lại một lần để nhận URL API mới.
   Hot reload/hot restart không đổi được `--dart-define` của phiên đã chạy.
3. Khi app chạy, kiểm tra nhãn môi trường **API LOCAL**. Sau đó dùng **Hot Reload**
   khi sửa giao diện, hoặc **Hot Restart** khi cần chạy lại trạng thái Dart.

Để emulator nằm trong IDE, bật **Settings → Tools → Emulator → Launch in the
Running Devices tool window**, rồi mở **View → Tool Windows → Running Devices**.

Cấu hình IDE giữ Google client IDs ở `.local/auth/google-client.json` và cờ
`xlandInternalDebugSigning=true` để cài đè APK nội bộ trên emulator. Nếu chạy CLI
trong thư mục `xland-mobile`, dùng cùng cấu hình:

```powershell
& .\.local\flutter-3.47.5-native\bin\flutter.bat run --debug -d emulator-5554 --dart-define=XLAND_API_BASE_URL=http://10.0.2.2:3002/api/v1 --dart-define=XLAND_SHARE_HOST=xland-server-production.up.railway.app --android-project-arg=xlandShareHost=xland-server-production.up.railway.app --android-project-arg=xlandInternalDebugSigning=true --dart-define-from-file=.local/auth/google-client.json
```

Nếu emulator có ID khác, xem bằng `flutter devices` rồi thay `-d`.
Nếu server báo `EADDRINUSE`, kiểm tra terminal đã chạy server ở cổng 3002.
Nếu app không kết nối, kiểm tra `/health/ready`, chọn đúng emulator và chạy lại
cấu hình **Xland Local**. `localhost` bên trong Android chỉ chính emulator.

Bản **Xland Railway Release** và script release tiếp tục dùng API Railway.
