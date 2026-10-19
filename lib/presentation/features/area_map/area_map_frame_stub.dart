import 'package:flutter/widgets.dart';

class AreaMapFrame extends StatelessWidget {
  const AreaMapFrame({
    super.key,
    required this.url,
    required this.onFrameLoaded,
    required this.onFrameError,
  });
  final Uri url;
  final VoidCallback onFrameLoaded;
  final ValueChanged<String> onFrameError;
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Bản đồ nhúng chưa hỗ trợ nền tảng này'));
}
