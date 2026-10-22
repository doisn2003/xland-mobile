import 'package:flutter/material.dart';

import '../di/prepared_content_scope.dart';

class PreparedContentControls extends StatelessWidget {
  const PreparedContentControls({super.key});
  @override
  Widget build(BuildContext context) {
    final content = PreparedContentScope.maybeOf(context);
    if (content == null) return const SizedBox.shrink();
    final date = content.snapshot.preparedAt.toLocal();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dữ liệu đã tải',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Nội dung trong bản cài: ${date.day}/${date.month}/${date.year}. '
              'Danh sách tự kiểm tra nội dung mới khi mở lại. '
              'Mọi thao tác lưu và đặt lịch vẫn gửi lên máy chủ.',
            ),
            if (content.syncError != null)
              Text(
                content.syncError!,
                style: const TextStyle(color: Colors.deepOrange),
              ),
            if (content.busy) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: content.total == 0
                    ? null
                    : content.prepared / content.total,
              ),
              Text('Đang tải ${content.prepared}/${content.total} mục…'),
            ],
            if (content.preparationError != null)
              Text(
                content.preparationError!,
                style: const TextStyle(color: Colors.red),
              ),
            if (!content.busy &&
                content.prepared > 0 &&
                content.preparationError == null)
              Text('Đã tải đủ ${content.prepared} mục cho tài khoản hiện tại.'),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: content.busy ? null : content.prepareAll,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Tải trước dữ liệu cho buổi demo'),
            ),
            const Text(
              'Cần mạng để cập nhật nội dung mới và gửi yêu cầu. '
              'Ảnh/video có sẵn trong bản cài phát từ thiết bị.',
            ),
          ],
        ),
      ),
    );
  }
}
