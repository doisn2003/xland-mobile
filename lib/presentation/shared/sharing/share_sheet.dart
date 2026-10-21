import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../domain/xland_domain.dart';

/// One sharing flow for all content. Resolve the link before the native action
/// so Web Share still runs directly from a user gesture.
class ShareSheet extends StatefulWidget {
  const ShareSheet({super.key, required this.loadLink, required this.title});

  final Future<ShareLink> Function() loadLink;
  final String title;

  static Future<void> show(
    BuildContext context, {
    required Future<ShareLink> Function() loadLink,
    required String title,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ShareSheet(loadLink: loadLink, title: title),
  );

  @override
  State<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<ShareSheet> {
  ShareLink? _link;
  String? _error;
  bool _loading = true;
  bool _sharing = false;
  bool _copying = false;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final link = await widget.loadLink();
      if (link.url.scheme != 'https' ||
          link.url.host.isEmpty ||
          link.url.userInfo.isNotEmpty) {
        throw const FormatException('Invalid public share URL');
      }
      if (mounted) setState(() => _link = link);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is XlandFailure
              ? error.message
              : 'Chưa thể lấy liên kết. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copy() async {
    if (_copying) return;
    setState(() => _copying = true);
    try {
      await Clipboard.setData(ClipboardData(text: _link!.url.toString()));
      if (mounted) {
        setState(() {
          _copied = true;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Không thể sao chép. Bạn có thể chọn liên kết bên dưới.',
        );
      }
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  Future<void> _share(BuildContext buttonContext) async {
    if (_sharing) return;
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() {
      _sharing = true;
      _error = null;
    });
    try {
      // URL alone lets receiving applications retrieve Open Graph metadata.
      // A subject is useful to mail clients without duplicating the URL.
      final result = await SharePlus.instance.share(
        ShareParams(
          uri: _link!.url,
          title: _link!.title,
          subject: _link!.title,
          sharePositionOrigin: origin,
          downloadFallbackEnabled: false,
          mailToFallbackEnabled: false,
        ),
      );
      if (mounted && result.status == ShareResultStatus.unavailable) {
        setState(
          () => _error = 'Nếu bảng chia sẻ không mở, hãy sao chép liên kết và dán vào ứng dụng bạn muốn gửi.',
        );
      }
      // Dismissal is normal; never claim that a message was actually sent.
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Thiết bị chưa mở được bảng chia sẻ. Bạn vẫn có thể sao chép liên kết.',
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Chia sẻ',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                tooltip: 'Đóng',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            _link?.title ?? widget.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_link != null) ...[
            Builder(
              builder: (buttonContext) => FilledButton.icon(
                onPressed: _sharing ? null : () => _share(buttonContext),
                icon: const Icon(Icons.ios_share_rounded),
                label: Text(_sharing ? 'Đang mở…' : 'Chia sẻ qua ứng dụng'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Chọn Zalo, Messenger, Facebook, WhatsApp, Email, Tin nhắn… trong bảng chia sẻ của thiết bị.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SelectableText(
                      _link!.url.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _copying ? null : _copy,
                      icon: Icon(_copied ? Icons.check : Icons.copy_rounded),
                      label: Text(
                        _copied ? 'Đã sao chép liên kết' : 'Sao chép liên kết',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, semanticsLabel: _error),
            if (_link == null && !_loading)
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
          ],
        ],
      ),
    ),
  );
}
