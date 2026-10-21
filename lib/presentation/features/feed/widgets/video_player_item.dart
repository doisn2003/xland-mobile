import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

import '../../../../domain/xland_domain.dart';
import '../../../app/xland_app.dart';
import '../../../shared/di/dependencies_scope.dart';
import '../../../shared/sharing/share_sheet.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../shared/widgets/illustrative_image.dart';
import '../../../shared/utils/value_formatters.dart';
import '../../author/pages/author_profile_page.dart';
import '../../../theme/theme.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import '../../auth/widgets/login_prompt_sheet.dart';
import '../../booking/pages/booking_sheet.dart';
import '../../property_detail/pages/property_detail_page.dart';
import 'comments_sheet.dart';
import '../cubit/video_like_cubit.dart';

/// Single item in the vertical video feed.
/// Embeds video playback via [VideoPlayerController], media controls, social rail,
/// author info, and the two required CTAs: "Xem chi tiết" and "Xem thực địa".
class VideoPlayerItem extends StatefulWidget {
  const VideoPlayerItem({
    super.key,
    required this.video,
    required this.isCurrent,
    required this.isAppActive,
    this.autoplay = true,
    this.mutedByDefault = false,
    this.feedScope = FeedScope.recommended,
    this.onScopeChanged,
    this.onFilterTap,
    this.onNavigationTap,
    this.likeCubit,
  });

  final FeedVideo video;
  final bool isCurrent;
  final bool isAppActive;
  final bool autoplay;
  final bool mutedByDefault;
  final FeedScope feedScope;
  final ValueChanged<FeedScope>? onScopeChanged;
  final VoidCallback? onFilterTap;
  final VoidCallback? onNavigationTap;
  final VideoLikeCubit? likeCubit;

  @override
  State<VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<VideoPlayerItem> with RouteAware {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;
  int _playerGeneration = 0;
  bool _isRouteCovered = false;
  Animation<double>? _secondaryAnimation;
  bool _userManuallyPaused = false;

  VideoLikeCubit? _likes;
  late bool _isSaved;
  late bool _isFollowing;
  bool _isMutatingSave = false;
  bool _isMutatingFollow = false;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.video.isSaved;
    _isFollowing = widget.video.author.isFollowing;

    _initPlayer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _likes ??=
        widget.likeCubit ??
        VideoLikeCubit(widget.video, DependenciesScope.of(context).feed);
    final modalRoute = ModalRoute.of(context);
    if (modalRoute != null) {
      _isRouteCovered = !modalRoute.isCurrent;
      XLandApp.routeObserver.subscribe(this, modalRoute);
      final secAnim = modalRoute.secondaryAnimation;
      if (_secondaryAnimation != secAnim) {
        _secondaryAnimation?.removeListener(_onRouteAnimationChanged);
        _secondaryAnimation = secAnim;
        _secondaryAnimation?.addListener(_onRouteAnimationChanged);
      }
    }
  }

  void _onRouteAnimationChanged() {
    if (!mounted) return;
    final isCovered =
        _secondaryAnimation != null && !_secondaryAnimation!.isDismissed;
    if (isCovered) {
      _controller?.pause();
    } else if (!_isRouteCovered &&
        widget.isCurrent &&
        widget.isAppActive &&
        widget.autoplay &&
        !_userManuallyPaused) {
      if (_isInitialized &&
          _controller != null &&
          !_controller!.value.isPlaying &&
          !_hasError) {
        _controller?.play();
      }
    }
  }

  @override
  void didPushNext() {
    _isRouteCovered = true;
    _controller?.pause();
  }

  @override
  void didPopNext() {
    _isRouteCovered = false;
    final isCovered =
        _isRouteCovered ||
        (_secondaryAnimation != null && !_secondaryAnimation!.isDismissed);
    if (widget.isCurrent &&
        widget.isAppActive &&
        widget.autoplay &&
        !isCovered &&
        !_userManuallyPaused) {
      if (_isInitialized &&
          _controller != null &&
          !_controller!.value.isPlaying &&
          !_hasError) {
        _controller?.play();
      }
    }
  }

  String _sanitizeErrorMessage(Object? err) {
    final message = err.toString().toLowerCase();
    if (message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('connection refused') ||
        message.contains('network is unreachable')) {
      return 'Không thể kết nối. Kiểm tra mạng và thử lại.';
    }
    if (err is UnimplementedError ||
        err is PlatformException && err.code == 'Unimplemented') {
      return 'Trình phát chưa khả dụng trên thiết bị này.';
    }
    // A platform error can also be an expired URL or unavailable server.
    // Do not infer codec support or expose native details/URLs to the user.
    return 'Video tạm thời không khả dụng. Vui lòng thử lại.';
  }

  void _initPlayer() {
    final mediaUrl = widget.video.media.url;
    if (mediaUrl == null) {
      _hasError = true;
      _errorMessage = 'Nguồn video chưa sẵn sàng hoặc không khả dụng';
      return;
    }

    final currentGen = ++_playerGeneration;
    _controller?.removeListener(_onPlayerStateChanged);
    _controller?.dispose();
    _controller = null;

    try {
      final controller = VideoPlayerController.networkUrl(mediaUrl);
      _controller = controller;
      controller.addListener(_onPlayerStateChanged);

      controller
          .initialize()
          .then((_) {
            if (!mounted || currentGen != _playerGeneration) {
              controller.dispose();
              return;
            }
            setState(() {
              _isInitialized = true;
              _hasError = false;
              _errorMessage = null;
            });
            controller.setLooping(true);
            if (widget.mutedByDefault) {
              controller.setVolume(0.0);
            }
            final isCovered =
                _isRouteCovered ||
                (_secondaryAnimation != null &&
                    !_secondaryAnimation!.isDismissed);
            if (widget.isCurrent &&
                widget.isAppActive &&
                widget.autoplay &&
                !isCovered &&
                !_userManuallyPaused) {
              controller.play();
            }
          })
          .catchError((Object err) {
            if (!mounted || currentGen != _playerGeneration) return;
            setState(() {
              _hasError = true;
              _errorMessage = _sanitizeErrorMessage(err);
            });
          });
    } catch (e) {
      _hasError = true;
      _errorMessage = _sanitizeErrorMessage(e);
    }
  }

  void _onPlayerStateChanged() {
    if (!mounted) return;
    if (_controller != null && _controller!.value.hasError) {
      setState(() {
        _hasError = true;
        _errorMessage = _sanitizeErrorMessage(
          _controller!.value.errorDescription,
        );
      });
      return;
    }
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant VideoPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.likeCubit != widget.likeCubit ||
        oldWidget.video.id != widget.video.id) {
      if (oldWidget.likeCubit == null) _likes?.close();
      _likes =
          widget.likeCubit ??
          VideoLikeCubit(widget.video, DependenciesScope.of(context).feed);
    }
    if (oldWidget.video.id != widget.video.id ||
        oldWidget.video.media.url != widget.video.media.url) {
      _userManuallyPaused = false;
      _initPlayer();
      return;
    }
    if (oldWidget.mutedByDefault != widget.mutedByDefault) {
      if (widget.mutedByDefault) {
        _controller?.setVolume(0.0);
      } else {
        _controller?.setVolume(1.0);
      }
    }
    // Visibility changes (tab/route) do not change the user's playback intent.
    // Only a different video/source, or an explicit play tap, resets it.
    if (oldWidget.isCurrent != widget.isCurrent ||
        oldWidget.isAppActive != widget.isAppActive ||
        oldWidget.autoplay != widget.autoplay) {
      final isCovered =
          _isRouteCovered ||
          (_secondaryAnimation != null && !_secondaryAnimation!.isDismissed);
      if (widget.isCurrent &&
          widget.isAppActive &&
          widget.autoplay &&
          !isCovered &&
          !_userManuallyPaused) {
        if (_isInitialized &&
            _controller != null &&
            !_controller!.value.isPlaying &&
            !_hasError) {
          _controller?.play();
        }
      } else {
        _controller?.pause();
      }
    }
  }

  @override
  void dispose() {
    if (widget.likeCubit == null) _likes?.close();
    XLandApp.routeObserver.unsubscribe(this);
    _secondaryAnimation?.removeListener(_onRouteAnimationChanged);
    _controller?.removeListener(_onPlayerStateChanged);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _userManuallyPaused = true;
        _controller!.pause();
      } else {
        _userManuallyPaused = false;
        _controller!.play();
      }
    });
  }

  Future<void> _handleLike() async {
    if (_likes!.state.pending) return;
    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) {
      final didLogin = await LoginPromptSheet.show(
        context,
        title: 'Đăng nhập để thích video',
        message:
            'Vui lòng đăng nhập để tương tác và lưu vào mục yêu thích của bạn.',
      );
      if (!didLogin || !mounted) return;
    }

    final currentAuth = context.read<AuthCubit>();
    final owner = currentAuth.state;
    if (owner is! AuthAuthenticated) return;
    final likes = _likes!;
    try {
      await likes.toggle();
    } catch (e) {
      final activeAuth = currentAuth.state;
      if (mounted &&
          identical(likes, _likes) &&
          activeAuth is AuthAuthenticated &&
          activeAuth.session.profile.id == owner.session.profile.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is XlandFailure
                  ? e.message
                  : 'Không thể cập nhật lượt thích. Vui lòng thử lại.',
            ),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _handleSaveVideo() async {
    if (_isMutatingSave) return;
    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) {
      final didLogin = await LoginPromptSheet.show(
        context,
        title: 'Đăng nhập để lưu video',
        message:
            'Vui lòng đăng nhập để lưu video vào danh sách xem lại của bạn.',
      );
      if (!didLogin || !mounted) return;
    }

    final nextSaved = !_isSaved;
    setState(() {
      _isMutatingSave = true;
      _isSaved = nextSaved;
    });

    try {
      final deps = DependenciesScope.of(context);
      await deps.feed.setSaved(widget.video.id, nextSaved);
      if (!mounted) return;
      setState(() => _isMutatingSave = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextSaved ? 'Đã lưu video vào danh sách' : 'Đã bỏ lưu video',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaved = !nextSaved;
          _isMutatingSave = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể lưu video: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _handleFollow() async {
    if (_isMutatingFollow) return;
    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) {
      final didLogin = await LoginPromptSheet.show(
        context,
        title: 'Đăng nhập để theo dõi chuyên viên',
        message:
            'Vui lòng đăng nhập để cập nhật bài viết mới nhất từ chuyên viên.',
      );
      if (!didLogin || !mounted) return;
    }

    final nextFollowing = !_isFollowing;
    setState(() {
      _isMutatingFollow = true;
      _isFollowing = nextFollowing;
    });

    try {
      final deps = DependenciesScope.of(context);
      await deps.feed.setFollowing(widget.video.author.id, nextFollowing);
      if (mounted) setState(() => _isMutatingFollow = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFollowing = !nextFollowing;
          _isMutatingFollow = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể cập nhật theo dõi: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _handleShare() async {
    final deps = DependenciesScope.of(context);
    await ShareSheet.show(
      context,
      title: widget.video.caption,
      loadLink: () => deps.feed.getShareLink(widget.video.id),
    );
  }

  void _openDetail() {
    _controller?.pause();
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) =>
                PropertyDetailPage(propertyId: widget.video.propertyId),
          ),
        )
        .then((_) {
          _resumeAfterNavigation();
        });
  }

  Future<void> _openBooking() async {
    _controller?.pause();
    await BookingSheet.show(context, propertyId: widget.video.propertyId);
    _resumeAfterNavigation();
  }

  void _resumeAfterNavigation() {
    final covered =
        _isRouteCovered ||
        (_secondaryAnimation != null && !_secondaryAnimation!.isDismissed);
    if (mounted &&
        widget.isCurrent &&
        widget.isAppActive &&
        widget.autoplay &&
        !_userManuallyPaused &&
        !covered &&
        _isInitialized &&
        !_hasError) {
      _controller?.play();
    }
  }

  Future<void> _openAuthor() async {
    final authorId = widget.video.author.id;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AuthorProfilePage(authorId: authorId),
      ),
    );
    if (!mounted || widget.video.author.id != authorId) return;
    try {
      final profile = await DependenciesScope.of(context).feed
          .getAuthorProfile(authorId);
      if (mounted && widget.video.author.id == authorId) {
        setState(() => _isFollowing = profile.author.isFollowing);
      }
    } catch (_) {
      // Keep the feed usable when refreshing follow state fails.
    }
  }

  Widget _avatar(double size) => SizedBox(
    width: size,
    height: size,
    child: ClipOval(
      child: XLandMediaImage(
        url: widget.video.author.avatarUrl,
        isIllustrative: widget.video.isIllustrative,
        illustrativeAsset: IllustrativeAssets.consultant,
        showLabel: false,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final v = widget.video;
    final p = v.property;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final direction = formatPropertyDirection(p.direction);
    final landType = formatLandType(p.landType);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 720;
        final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.1;
        final actionHeight = largeText && constraints.maxWidth < 400
            ? 80.0
            : 48.0;
        final footerExtent = actionHeight + 22;
        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: _togglePlayPause,
              child: ColoredBox(
                color: const Color(0xFF0C1514),
                child: _isInitialized && _controller != null && !_hasError
                    ? ClipRect(
                        child: SizedBox.expand(
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _controller!.value.size.width,
                              height: _controller!.value.size.height,
                              child: VideoPlayer(_controller!),
                            ),
                          ),
                        ),
                      )
                    : XLandMediaImage(
                        url: _hasError && v.isIllustrative
                            ? null
                            : v.media.thumbnailUrl,
                        isIllustrative: v.isIllustrative,
                        illustrativeAsset: IllustrativeAssets.portrait,
                        showLabel: false,
                      ),
              ),
            ),
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, .22, .48, .72, 1],
                    colors: [
                      Color(0x66000000),
                      Colors.transparent,
                      Colors.transparent,
                      Color(0x990C1514),
                      Color(0xFF0C1514),
                    ],
                  ),
                ),
              ),
            ),
            if (!_isInitialized || _hasError)
              Positioned(
                top: constraints.maxHeight * .33 - 40,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 80),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_hasError)
                        const CircularProgressIndicator(
                          color: AppColors.goldDecorative,
                        )
                      else ...[
                        const Icon(
                          Icons.play_circle_outline_rounded,
                          size: 46,
                          color: Colors.white70,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _errorMessage ?? 'Video chưa khả dụng',
                          textAlign: TextAlign.center,
                          style: AppTypography.compact.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _hasError = false;
                              _isInitialized = false;
                            });
                            _initPlayer();
                          },
                          child: const Text(
                            'Thử lại',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            if (_isInitialized &&
                _controller != null &&
                !_controller!.value.isPlaying &&
                !_hasError)
              const Center(
                child: IgnorePointer(
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 64,
                    color: Colors.white70,
                  ),
                ),
              ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _scopeTab(
                              'Dành cho bạn',
                              FeedScope.recommended,
                            ),
                          ),
                          Expanded(
                            child: _scopeTab(
                              'Đang theo dõi',
                              FeedScope.following,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Material(
                            color: AppColors.mediaPillOverlay,
                            borderRadius: BorderRadius.circular(28),
                            child: InkWell(
                              onTap: widget.onNavigationTap,
                              borderRadius: BorderRadius.circular(28),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 9,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    XLandLogo(
                                      variant: XLandLogoVariant.onGreen,
                                      height: 22,
                                    ),
                                    SizedBox(width: 4),
                                    Icon(
                                      Icons.keyboard_arrow_down,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Flexible(
                            child: _glassPill(
                              v.approximateArea,
                              icon: Icons.location_on_rounded,
                              onTap: widget.onFilterTap,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            onPressed: widget.onFilterTap,
                            tooltip: 'Tìm đất theo nhu cầu',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black38,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.tune_rounded, size: 22),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: bottom + (compact ? 220 : 265) + (actionHeight - 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 48,
                    height: 56,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GestureDetector(
                          key: const ValueKey('feed-author-avatar'),
                          onTap: _openAuthor,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            child: _avatar(46),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 12,
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: IconButton.filled(
                              onPressed: _isMutatingFollow
                                  ? null
                                  : _handleFollow,
                              padding: EdgeInsets.zero,
                              tooltip: _isFollowing
                                  ? 'Bỏ theo dõi'
                                  : 'Theo dõi',
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.goldDecorative,
                              ),
                              icon: Icon(
                                _isFollowing ? Icons.check : Icons.add,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  BlocBuilder<VideoLikeCubit, VideoLikeState>(
                    bloc: _likes!,
                    builder: (context, state) => _buildRailButton(
                      icon: state.liked
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: state.liked ? AppColors.danger : Colors.white,
                      label: '${state.count}',
                      semanticLabel:
                          '${state.liked ? 'Bỏ thích' : 'Thích'} video, ${state.count} lượt thích',
                      onTap: _handleLike,
                    ),
                  ),
                  _buildRailButton(
                    icon: Icons.mode_comment_outlined,
                    color: Colors.white,
                    label: '${v.commentCount}',
                    semanticLabel: 'Bình luận, ${v.commentCount} bình luận',
                    onTap: () => CommentsSheet.show(context, videoId: v.id),
                  ),
                  _buildRailButton(
                    icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: _isSaved ? AppColors.goldDecorative : Colors.white,
                    label: 'Lưu',
                    semanticLabel: _isSaved ? 'Đã lưu video' : 'Lưu video',
                    onTap: _handleSaveVideo,
                  ),
                  _buildRailButton(
                    icon: Icons.share_rounded,
                    color: Colors.white,
                    label: 'Share',
                    semanticLabel: 'Chia sẻ video',
                    onTap: _handleShare,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: bottom + footerExtent + 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 62),
                    child: Row(
                      children: [
                        GestureDetector(
                          key: const ValueKey('feed-author-inline-avatar'),
                          onTap: _openAuthor,
                          child: _avatar(38),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: InkWell(
                                      key: const ValueKey('feed-author-name'),
                                      onTap: _openAuthor,
                                      child: Text(
                                        v.author.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.bodyStrong
                                            .copyWith(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: _handleFollow,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.white60,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _isFollowing
                                            ? 'Đã theo dõi'
                                            : 'Theo dõi',
                                        style: AppTypography.compact.copyWith(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (v.author.isVerified)
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.verified,
                                      size: 13,
                                      color: Color(0xFF28C39C),
                                    ),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        'Danh tính đã xác minh',
                                        style: AppTypography.compact.copyWith(
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 9),
                  Padding(
                    padding: const EdgeInsets.only(right: 56),
                    child: Text(
                      p.title,
                      style: AppTypography.pageHero.copyWith(
                        color: Colors.white,
                        fontSize: compact ? 22 : 25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        formatCompactVnd(p.priceTotal),
                        style: AppTypography.priceHero.copyWith(
                          color: AppColors.feedGold,
                          fontSize: compact ? 30 : 34,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        '|',
                        style: TextStyle(color: Colors.white38, fontSize: 21),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          '${formatCompactVnd(p.pricePerM2)}/m²',
                          style: AppTypography.bodyStrong.copyWith(
                            color: AppColors.feedGold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatMeasurement(p.areaM2, 'm²')}   •   Mặt tiền ${formatMeasurement(p.frontageM, 'm')}   •   Đường ${formatMeasurement(p.roadWidthM, 'm')}',
                    style: AppTypography.compactStrong.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      _glassPill(
                        landType,
                        icon: Icons.layers_outlined,
                        small: true,
                      ),
                      if (p.direction != null)
                        _glassPill(
                          'Hướng $direction',
                          icon: Icons.wb_sunny_outlined,
                          small: true,
                        ),
                      _glassPill(
                        '${p.code} • ${formatUpdatedAt(p.updatedAt)}',
                        small: true,
                      ),
                    ],
                  ),
                  if (p.highlights.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      p.highlights.map((h) => h.title).join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.compact.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                  const SizedBox(height: 9),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      InkWell(
                        onTap: () => _openDetailAt(2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 15,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Vị trí tương đối',
                              style: AppTypography.compact.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: Colors.white70,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(12, 10, 12, bottom + 12),
                decoration: const BoxDecoration(
                  color: Color(0xCC0C1514),
                  border: Border(top: BorderSide(color: Colors.white12)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlineButton(
                        label: 'Xem chi tiết',
                        inverse: true,
                        height: actionHeight,
                        icon: const Icon(
                          Icons.description_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: _openDetail,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 44,
                      height: actionHeight,
                      child: IconButton.filled(
                        tooltip: 'Mở điều hướng',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.feedGold,
                          foregroundColor: AppColors.textPrimary,
                        ),
                        onPressed: widget.onNavigationTap,
                        icon: const Icon(Icons.keyboard_arrow_up_rounded),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Xem thực địa',
                        height: actionHeight,
                        icon: const Icon(Icons.map_outlined, size: 20),
                        onPressed: _openBooking,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isInitialized && _controller != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: bottom,
                child: VideoProgressIndicator(
                  _controller!,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: AppColors.feedGold,
                    bufferedColor: Colors.white24,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _openDetailAt(int tab) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PropertyDetailPage(
        propertyId: widget.video.propertyId,
        initialTab: tab,
      ),
    ),
  );

  Widget _scopeTab(String title, FeedScope scope) => InkWell(
    onTap: () => widget.onScopeChanged?.call(scope),
    child: Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.fromLTRB(4, 14, 8, 9),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            width: 2,
            color: widget.feedScope == scope
                ? AppColors.feedGold
                : Colors.transparent,
          ),
        ),
      ),
      child: Text(
        title,
        style: AppTypography.compactStrong.copyWith(
          color: widget.feedScope == scope ? Colors.white : Colors.white60,
        ),
      ),
    ),
  );

  Widget _glassPill(
    String label, {
    IconData? icon,
    bool small = false,
    VoidCallback? onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(24),
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: small ? 5 : 9),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(24),
        border: small ? Border.all(color: Colors.white24) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: small ? AppColors.feedGold : Colors.white,
              size: small ? 14 : 17,
            ),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.compact.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildRailButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    String? semanticLabel,
  }) => Semantics(
    button: true,
    label: semanticLabel ?? label,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: SizedBox(
          width: 48,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: color,
                size: 30,
                shadows: const [Shadow(blurRadius: 8, color: Colors.black38)],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTypography.bodyStrong.copyWith(
                  color: Colors.white,
                  shadows: const [Shadow(blurRadius: 4, color: Colors.black87)],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
