import 'package:flutter/material.dart';

import '../../../../domain/xland_domain.dart';
import '../../../shared/di/dependencies_scope.dart';
import '../../../shared/widgets/widgets.dart';
import '../widgets/video_player_item.dart';

/// Fetch the exact shared video; it need not be in the first feed page.
class SharedVideoPage extends StatefulWidget {
  const SharedVideoPage({
    super.key,
    required this.videoId,
    this.title = 'Video được chia sẻ',
  });
  final String videoId;
  final String title;

  @override
  State<SharedVideoPage> createState() => _SharedVideoPageState();
}

class _SharedVideoPageState extends State<SharedVideoPage>
    with WidgetsBindingObserver {
  FeedVideo? _video;
  String? _error;
  bool _loading = true;
  bool _active = true;
  bool _autoplay = true;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) setState(() => _active = state == AppLifecycleState.resumed);
  }

  Future<void> _load() async {
    if (!mounted) return;
    final deps = DependenciesScope.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final video = await deps.feed.getVideo(widget.videoId);
      var autoplay = false;
      var muted = true;
      try {
        final session = await deps.account.getSession();
        if (session != null && session.expiresAt.isAfter(DateTime.now())) {
          final settings = await deps.account.getSettings();
          autoplay = settings.feedAutoplay;
          muted = settings.feedMutedByDefault;
        } else {
          final settings =
              await deps.guestPreferences?.read() ??
              const GuestPlaybackPreferences();
          autoplay = settings.feedAutoplay;
          muted = settings.feedMutedByDefault;
        }
      } catch (_) {
        // A settings/storage outage must not hide a public shared video.
      }
      if (mounted) {
        setState(() {
          _video = video;
          _autoplay = autoplay;
          _muted = muted;
        });
      }
    } on XlandFailure catch (error) {
      if (mounted) {
        setState(
          () => _error = error.code == FailureCode.notFound
              ? 'Video không còn khả dụng hoặc đã được gỡ.'
              : 'Không tải được video. Vui lòng thử lại.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không tải được video. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: _loading
        ? const LoadingState()
        : _error != null
        ? ErrorRetryState(errorMessage: _error!, onRetry: _load)
        : VideoPlayerItem(
            video: _video!,
            isCurrent: true,
            isAppActive: _active,
            autoplay: _autoplay,
            mutedByDefault: _muted,
          ),
  );
}
