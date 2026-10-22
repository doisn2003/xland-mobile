# Bản trình diễn: cache và backend thật

Branch riêng: `demo/offline-2026-10-23`. Android Studio: **Xland Demo Cache**.
Entry point `lib/main_demo.dart`; API Northflank và gói hiện có giữ nguyên.
Mã mobile trên `main` không đổi. Backend đã batch đọc danh sách ở `8f288dc`.

## Hành vi

- Snapshot công khai nền 22/10: 20 lô, 97 mục feed, 5 sự kiện, 1 CLB;
  34 file media (~75 MB), 108 tile bản đồ. Các video có thể dùng chung file.
- Bản lưu xuất hiện trước; app đọc lại server ở nền và cập nhật màn hình.
  Mở lại app cũng kiểm tra feed/danh sách/sự kiện. Cache nội dung tối đa 36 giờ.
- Feed có nút **Tải lại nội dung mới**; Khám phá kéo xuống để tải lại.
  Tải lại chủ động chờ lượt đọc mới sau khi lượt tải nền cũ hoàn tất.
- Admin thêm lô/video không cần build lại APK. Nội dung/media mới lấy từ
  API/Storage thật; video mới chưa đóng gói vẫn cần mạng lần phát đầu.
- Phiên/đăng nhập, tài khoản, bình luận, lịch trống, chính sách đặt cọc, lịch sử,
  thanh toán và mọi thao tác ghi luôn dùng backend thật, không xếp hàng gửi sau
  và không giả thành công. Không có reset dữ liệu nghiệp vụ.
- Cache theo phiên riêng bằng secure storage. Không đóng gói token, tài khoản
  hoặc tài liệu riêng. Giữ attribution bản đồ; chỉ có tile vùng xem ban đầu.

## Chuẩn bị demo

1. Cài APK như bản cập nhật Xland hiện có. Tên app là **Xland Demo**, giữ cùng
   application ID/certificate để Google login và dữ liệu máy vẫn dùng được.
   Bản này thay bản thường trên thiết bị, không cài song song.
2. Mở app khi có mạng, đăng nhập tài khoản dùng để trình diễn.
3. **Tôi → Cài đặt ứng dụng → Dữ liệu đã tải → Tải trước dữ liệu cho buổi demo**.
   Đợi hoàn tất; có thể mất vài phút vì các lượt đọc dùng API thật.
4. Mở thử feed, chi tiết, pháp lý, bản đồ và lịch hẹn trước buổi gặp khách.
5. Admin: lưu/công bố lô, duyệt video và gắn lô/media hợp lệ. Trên app bấm tải
   lại feed hoặc kéo tải lại Khám phá. Nội dung ẩn/chờ duyệt theo quyền backend.

Cần mạng để gửi thao tác ghi hoặc nhận nội dung mới. Trở về bản thường bằng
APK Northflank cũ hoặc cấu hình **Xland Northflank**; không cần xóa ứng dụng.

## Build

```powershell
node tool/demo/prepare.mjs
# Thử lại media/tile chưa tải được, giữ nội dung snapshot hiện có:
node tool/demo/prepare.mjs --reuse
& ./.local/flutter-3.47.5-native/bin/dart.bat run tool/demo/verify_snapshot.dart
& ./tool/demo/build.ps1
```

`assets/prepared-demo/` sinh cục bộ và gitignored; APK chứa dữ liệu/media.
Branch lưu mã, công cụ tái tạo và cấu hình Run. Giữ signing/Google IDs riêng
trong `android/key.properties` và `.local/auth/google-client.json` hiện có.

## Kiểm chứng

Flutter analyze sạch; toàn bộ suite: 235 ca đạt, 7 ca live/env bỏ qua theo điều
kiện có sẵn. 10 ca cache kiểm: nhận nội dung mới, manual reload, real acknowledgement, lỗi
không enqueue, phản hồi cũ không ghi đè thao tác mới, private/session luôn live,
tách tài khoản và dữ liệu sau restart. Snapshot qua 605 lượt mapper thật;
376 endpoint công khai, 34 media và 108 tile đã kiểm byte/file tồn tại.

Fixture login UI dùng expiry theo đồng hồ test cộng một giờ, thay ngày cố định
đã hết hạn 22/10; kiểm tra đăng nhập/expiry của ứng dụng thật giữ nguyên.
Ngày 23/10 đã tạo một lô và upload/duyệt một video từ admin Vercel, nhận được
cả hai trên Pixel 9 Pro API 37.2 trong Android Studio. Chi tiết lô cũng mở
đúng mã, giá và nội dung mới. APK release có ARM64/x64, tên Xland Demo, cùng
chữ ký bản Northflank thường; không chứa file riêng hay token.
Kết quả APK và ảnh thử admin → emulator nằm ở báo cáo bàn giao cục bộ
`brain/reports/demo-20261023/` trong workspace cha; đây là kiểm chứng máy ảo,
chưa phải kiểm chứng trên điện thoại vật lý của người trình diễn.
