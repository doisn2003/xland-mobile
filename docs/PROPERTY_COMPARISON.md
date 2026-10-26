# So sánh hai lô đất

Trong trang chi tiết, nhấn biểu tượng kính lúp **vs** giữa Lưu và Chia sẻ.
Popup hiển thị các lô khác cùng ô tìm theo tên, mã lô hoặc khu vực. Danh sách
loại bỏ lô đang xem, tải thêm theo phân trang và cho phép thử lại khi lỗi mạng.

Chọn một lô để mở trang so sánh ngang với hai khung bằng nhau. Mỗi khung có
`PropertyDetailCubit`, bộ cuộn và `Navigator` riêng, tái sử dụng đầy đủ các tab
chi tiết. Đổi tab, xem ảnh, mở sheet chia sẻ/đặt lịch trong một khung không
thay đổi trạng thái hoặc chặn thao tác ở khung còn lại. Nút Back hệ thống đóng
route con của khung vừa tương tác trước; nút X đóng toàn bộ trang so sánh.

Trang yêu cầu `landscapeLeft`/`landscapeRight` qua `SystemChrome` và khôi phục
chính sách xoay tự do của ứng dụng khi đóng. Với viewport điện thoại mà hệ
thống không cho khóa hướng, `RotatedBox` giữ bố cục ngang. Tablet đủ rộng dùng
hai cột theo hướng hiện tại. Khi bàn phím mở, các thanh đầu/cuối tạm ẩn để chừa
chỗ nhập liệu và giữ nguyên trạng thái các tab.

## Dữ liệu

Sử dụng `PropertyRepository.search` và các API chi tiết hiện có; không thêm
endpoint hoặc thay đổi schema. Tìm kiếm debounce 300 ms, bỏ qua phản hồi cũ
khi từ khóa thay đổi, giữ cursor để thử lại trang tải thêm bị lỗi.

## Kiểm tra

```powershell
.\.local\flutter-3.47.5-native\bin\dart.bat analyze lib/presentation/features/property_detail test/presentation/property_comparison_test.dart
.\.local\flutter-3.47.5-native\bin\flutter.bat test --no-pub test/presentation/property_comparison_test.dart test/presentation/property_detail_test.dart test/presentation/sharing_test.dart test/presentation/system_insets_test.dart
```

58 tests bao gồm thứ tự icon, loại trừ lô gốc, tìm kiếm, phản hồi lỗi/cũ,
phân trang, hai khung độc lập, route ảnh/sheet riêng, Back, xoay/khôi phục,
màn hình ngang 667×375 và 844×390 với chữ 130%, bàn phím và đóng khi đang tải.

Đã build Android debug và kiểm tra trực tiếp trên emulator Pixel 9 Pro:
hai khung hiển thị ngang, cuộn và chuyển tab độc lập. Chưa kiểm tra native iOS.
