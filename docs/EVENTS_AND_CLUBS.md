# Sự kiện & Câu lạc bộ

Tab Sự kiện tải CLB ở trên và sự kiện ở dưới từ các repository/API hiện có.
Mỗi lần tải tối đa bốn mục, bố trí hai cột (2×2 khi có đủ bốn mục); nút
“Xem thêm” nối trang kế tiếp. Danh sách lẻ giữ đúng số bản ghi, không tạo thẻ giả.

- Thẻ CLB có ảnh, giới thiệu, khu vực và liên kết đến chi tiết theo ID thật.
- Thẻ sự kiện có ảnh, chủ đề, ngày giờ Việt Nam, địa điểm, trạng thái, số chỗ và phí.
- Bộ lọc Đang mở / Hết chỗ / Đã đóng / Đã hủy dùng bộ lọc status của API.
- Kéo để làm mới cả hai phần. Tải lỗi có nút thử lại riêng; lỗi một phần không
  chặn phần còn lại. Tải trang sau thất bại vẫn giữ danh sách và cursor trước đó.
- Đổi bộ lọc hoặc làm mới bỏ qua kết quả cũ còn đang tải. Trở về từ chi tiết sự
  kiện tải lại số chỗ để phản ánh đăng ký vừa thực hiện.

Seed nằm trong `xland-server/scripts/seed-community.ts`. Đã thêm trực tiếp vào
Supabase mẫu ngày 26/10/2026: CLB Bất động sản XLand và sáu sự kiện tháng 11/2026,
gồm bốn sự kiện bất động sản, chạy bộ Hồ Tây và workshop gốm. Dữ liệu cũ được giữ.
Ảnh và lịch là nội dung minh họa; API thanh toán/đăng ký giữ hành vi hiện có.

Kiểm tra:

```powershell
flutter analyze
flutter test test/presentation/events_tab_test.dart test/presentation/navbar_shell_test.dart test/presentation/w2_features_test.dart test/presentation/system_insets_test.dart test/data/event_design_fields_test.dart
```

Widget tests dùng font Roboto của ứng dụng, kiểm tra hai cột ở 320/390 px với cỡ
chữ 200%, thứ tự các phần, điều hướng, phân trang, lỗi mạng, retry, refresh và
kết quả trả về trễ. Payload thực từ API local và Railway đã được kiểm tra bằng
`mapClub`/`mapXlandEvent` của mobile, bao gồm trường media nullable bắt buộc.
