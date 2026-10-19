import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

class AreaMapFrame extends StatefulWidget {
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
  State<AreaMapFrame> createState() => _AreaMapFrameState();
}

class _AreaMapFrameState extends State<AreaMapFrame> {
  WebViewController? _controller;
  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform != TargetPlatform.android) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onFrameError(
            'Bản đồ nhúng chưa được hỗ trợ trên nền tảng này',
          );
        }
      });
      return;
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final controller = WebViewController();
      _controller = controller;
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null || uri.userInfo.isNotEmpty || uri.hasFragment) {
              return NavigationDecision.prevent;
            }
            if (request.isMainFrame) {
              return uri == widget.url
                  ? NavigationDecision.navigate
                  : NavigationDecision.prevent;
            }
            // Navigation, not a subresource allowlist. No accounts/login, arbitrary URL or paid API page.
            return uri.scheme == 'https' &&
                    uri.host == 'www.google.com' &&
                    uri.path.startsWith('/maps/')
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onPageFinished: (url) {
            if (mounted && Uri.tryParse(url) == widget.url) {
              widget.onFrameLoaded();
            }
          },
          onHttpError: (error) {
            if (mounted && error.request?.uri == widget.url) {
              widget.onFrameError('Trang bản đồ tạm thời không tải được');
            }
          },
          onWebResourceError: (error) {
            if (mounted && error.isForMainFrame == true) {
              widget.onFrameError('Không kết nối được trang bản đồ');
            }
          },
        ),
      );
      // Real URL navigation: no loadHtmlString, custom Referer, user identity or bearer headers.
      await controller.loadRequest(widget.url);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) widget.onFrameError('Chưa mở được bản đồ trên thiết bị này');
    }
  }

  @override
  Widget build(BuildContext context) => _controller == null
      ? const SizedBox.shrink()
      : WebViewWidget(controller: _controller!);
}
