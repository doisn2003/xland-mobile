import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../data/demo/prepared_media.dart';

import '../../../../domain/xland_domain.dart';
import '../../../shared/widgets/illustrative_image.dart';
import '../../../theme/theme.dart';

class PropertyMediaViewer extends StatefulWidget {
  const PropertyMediaViewer({
    super.key,
    required this.media,
    required this.initialIndex,
    required this.illustrativeAsset,
  });
  final List<MediaAsset> media;
  final int initialIndex;
  final String illustrativeAsset;
  @override
  State<PropertyMediaViewer> createState() => _PropertyMediaViewerState();
}

class _PropertyMediaViewerState extends State<PropertyMediaViewer> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text('${_index + 1}/${widget.media.length}'),
    ),
    body: SafeArea(
      top: false,
      child: PageView.builder(
        controller: _pages,
        itemCount: widget.media.length,
        onPageChanged: (index) => setState(() => _index = index),
        itemBuilder: (_, index) {
          final item = widget.media[index];
          return item.kind == MediaKind.video
              ? _GalleryVideo(
                  key: ValueKey(item.id),
                  media: item,
                  active: _index == index,
                )
              : InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: XLandMediaImage(
                        url: item.url,
                        isIllustrative: item.isIllustrative,
                        illustrativeAsset: widget.illustrativeAsset,
                        fit: BoxFit.contain,
                        showLabel: item.isIllustrative,
                      ),
                    ),
                  ),
                );
        },
      ),
    ),
  );
}

class _GalleryVideo extends StatefulWidget {
  const _GalleryVideo({super.key, required this.media, required this.active});
  final MediaAsset media;
  final bool active;
  @override
  State<_GalleryVideo> createState() => _GalleryVideoState();
}

class _GalleryVideoState extends State<_GalleryVideo>
    with WidgetsBindingObserver {
  VideoPlayerController? _video;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    final url = widget.media.url;
    if (url == null) {
      setState(() => _failed = true);
      return;
    }
    final preparedAsset = PreparedMedia.asset(url);
    final video = preparedAsset == null
        ? VideoPlayerController.networkUrl(url)
        : VideoPlayerController.asset(preparedAsset);
    _video = video;
    try {
      await video.initialize();
      if (!mounted || _video != video) return;
      setState(() {});
      if (widget.active) await video.play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void didUpdateWidget(covariant _GalleryVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active) _video?.pause();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _video?.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
        child: Text(
          'Video tạm thời chưa khả dụng',
          style: TextStyle(color: Colors.white),
        ),
      );
    }
    final video = _video;
    if (video == null || !video.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.feedGold),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: video.value.aspectRatio,
            child: VideoPlayer(video),
          ),
          VideoProgressIndicator(video, allowScrubbing: true),
          IconButton(
            tooltip: 'Phát / tạm dừng',
            color: Colors.white,
            onPressed: () => setState(() {
              video.value.isPlaying ? video.pause() : video.play();
            }),
            icon: Icon(video.value.isPlaying ? Icons.pause : Icons.play_arrow),
          ),
        ],
      ),
    );
  }
}
