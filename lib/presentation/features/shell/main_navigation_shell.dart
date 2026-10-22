import 'dart:async';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/xland_domain.dart';
import '../../app/xland_app.dart';
import '../../shared/di/dependencies_scope.dart';
import '../../shared/utils/timezone_utils.dart';
import '../../shared/utils/value_formatters.dart';
import '../../shared/widgets/widgets.dart';
import '../../theme/theme.dart';
import '../account/pages/edit_profile_page.dart';
import '../account/pages/saved_properties_page.dart';
import '../account/pages/settings_page.dart';
import '../auth/cubit/auth_cubit.dart';
import '../auth/cubit/auth_state.dart';
import '../auth/pages/login_page.dart';
import '../booking/pages/booking_detail_page.dart';
import '../booking/pages/booking_sheet.dart';
import '../discovery/pages/discovery_page.dart';
import '../discovery/widgets/property_filter_sheet.dart';
import '../auth/widgets/login_prompt_sheet.dart';
import '../feed/pages/saved_videos_page.dart';
import '../feed/widgets/video_player_item.dart';
import '../feed/cubit/video_like_cubit.dart';
import '../property_detail/pages/property_detail_page.dart';
import '../transactions/widgets/transaction_nft_hero.dart';

/// Main navigation shell holding the 4 core tabs of XLand:
/// 0. Trang chủ (Feed video ngắn)
/// 1. Khám phá (Discovery / Listing)
/// 2. Giao dịch (Lịch sử thực địa & Giới thiệu NFT)
/// 3. Tôi (Hồ sơ cá nhân & Cài đặt)
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({
    super.key,
    this.initialIndex = 0,
    this.onOpenGallery,
    this.forcePlaceholder = false,
  });

  final int initialIndex;
  final VoidCallback? onOpenGallery;
  final bool forcePlaceholder;

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell>
    with WidgetsBindingObserver, RouteAware {
  late int _currentIndex;
  bool _isAppActive = true;
  bool _isRouteCovered = false;
  final _transactionsScrollController = ScrollController();
  final _bookingHistoryAnchor = GlobalKey();
  double _transactionHeroExtent = 0;
  bool _transactionHeroVisible = true;

  bool _feedAutoplay = true;
  bool _feedMutedByDefault = false;
  bool _settingsReady = false;
  String? _lastUserId;

  List<FeedVideo> _feedVideos = [];
  final Map<String, VideoLikeCubit> _feedLikes = {};
  bool _isLoadingFeed = false;
  bool _isRefreshingFeed = false;
  String? _feedError;
  String? _feedCursor;
  bool _hasMoreFeed = false;
  bool _isLoadingMoreFeed = false;
  int _activeFeedIndex = 0;
  FeedScope _feedScope = FeedScope.recommended;

  List<Booking> _bookingHistory = [];
  String? _bookingCursor;
  bool _hasMoreBookings = false;
  bool _isLoadingBookings = false;
  bool _isLoadingMoreBookings = false;
  String? _bookingHistoryError;

  int _bookingEpoch = 0;
  int _feedEpoch = 0;
  int _settingsEpoch = 0;
  StreamSubscription<Set<String>>? _contentSubscription;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    WidgetsBinding.instance.addObserver(this);
    _transactionsScrollController.addListener(_onTransactionsScrolled);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialFeed();
      if (_currentIndex == 2) {
        _loadInitialBookings();
      }
    });
  }

  @override
  void didUpdateWidget(covariant MainNavigationShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex) {
      _currentIndex = widget.initialIndex;
      if (_currentIndex == 2 &&
          _bookingHistory.isEmpty &&
          !_isLoadingBookings) {
        _loadInitialBookings();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _contentSubscription ??= DependenciesScope.maybeOf(context)?.contentChanges
        ?.listen((paths) {
          if (mounted && paths.contains('/feed')) {
            _loadInitialFeed(refreshSettings: false, silent: true);
          }
        });
    final modalRoute = ModalRoute.of(context);
    if (modalRoute != null) {
      _isRouteCovered = !modalRoute.isCurrent;
      XLandApp.routeObserver.subscribe(this, modalRoute);
    }
  }

  @override
  void didPushNext() {
    setState(() => _isRouteCovered = true);
  }

  @override
  void didPopNext() {
    setState(() => _isRouteCovered = false);
  }

  @override
  void dispose() {
    _contentSubscription?.cancel();
    _transactionsScrollController.dispose();
    _clearFeedLikes();
    XLandApp.routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _clearFeedLikes() {
    for (final likes in _feedLikes.values) {
      likes.close();
    }
    _feedLikes.clear();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isResumed = state == AppLifecycleState.resumed;
    if (_isAppActive != isResumed) {
      setState(() => _isAppActive = isResumed);
    }
  }

  Future<void> _loadSettings() async {
    final deps = DependenciesScope.maybeOf(context);
    if (deps == null) return;
    final currentEpoch = ++_settingsEpoch;
    try {
      final session = await deps.account.getSession();
      if (!mounted || currentEpoch != _settingsEpoch) return;
      if (session != null && session.expiresAt.isAfter(DateTime.now())) {
        final s = await deps.account.getSettings();
        if (mounted && currentEpoch == _settingsEpoch) {
          setState(() {
            _feedAutoplay = s.feedAutoplay;
            _feedMutedByDefault = s.feedMutedByDefault;
          });
        }
      } else {
        if (mounted && currentEpoch == _settingsEpoch) {
          final guestData =
              await deps.guestPreferences?.read() ??
              const GuestPlaybackPreferences();
          if (!mounted || currentEpoch != _settingsEpoch) return;
          setState(() {
            _feedAutoplay = guestData.feedAutoplay;
            _feedMutedByDefault = guestData.feedMutedByDefault;
          });
        }
      }
    } catch (_) {
      if (mounted && currentEpoch == _settingsEpoch) {
        _feedAutoplay = false;
      }
    } finally {
      if (mounted && currentEpoch == _settingsEpoch) {
        setState(() => _settingsReady = true);
      }
    }
  }

  Future<void> _loadInitialFeed({
    bool refreshSettings = true,
    bool silent = false,
    bool forceRefresh = false,
  }) async {
    final deps = DependenciesScope.maybeOf(context);
    if (deps == null || widget.forcePlaceholder) return;
    final currentEpoch = ++_feedEpoch;
    setState(() {
      _isLoadingFeed = !silent;
      _feedError = null;
    });

    try {
      if (forceRefresh) await deps.refreshContent?.call('/feed');
      // Session/settings validation may take several remote trips; it must not
      // hold the public feed behind it. Playback waits for _settingsReady.
      if (refreshSettings) unawaited(_loadSettings());
      final page = await deps.feed.getFeed(
        const PageQuery(limit: 10),
        feedScope: _feedScope,
      );
      if (!mounted || currentEpoch != _feedEpoch) return;
      setState(() {
        _feedVideos = List.of(page.items);
        _activeFeedIndex = 0;
        _feedCursor = page.nextCursor;
        _hasMoreFeed = page.hasMore;
        _isLoadingFeed = false;
      });
    } on XlandFailure catch (e) {
      if (!mounted || currentEpoch != _feedEpoch) return;
      _feedLoadFailed(e.message, silent: silent);
    } catch (e) {
      if (!mounted || currentEpoch != _feedEpoch) return;
      _feedLoadFailed('Không thể tải feed video: $e', silent: silent);
    }
  }

  void _feedLoadFailed(String message, {required bool silent}) {
    final keepContent = silent && _feedVideos.isNotEmpty;
    setState(() {
      _feedError = keepContent ? null : message;
      _isLoadingFeed = false;
    });
    if (keepContent) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Chưa cập nhật được. $message')));
    }
  }

  Future<void> _refreshFeed() async {
    if (_isRefreshingFeed) return;
    setState(() => _isRefreshingFeed = true);
    try {
      await _loadInitialFeed(
        forceRefresh: true,
        silent: true,
        refreshSettings: false,
      );
    } finally {
      if (mounted) setState(() => _isRefreshingFeed = false);
    }
  }

  Future<void> _loadMoreFeed() async {
    if (_isLoadingMoreFeed || !_hasMoreFeed) return;
    final deps = DependenciesScope.maybeOf(context);
    if (deps == null) return;
    final currentEpoch = _feedEpoch;
    setState(() => _isLoadingMoreFeed = true);

    try {
      final page = await deps.feed.getFeed(
        PageQuery(cursor: _feedCursor, limit: 10),
        feedScope: _feedScope,
      );
      if (!mounted || currentEpoch != _feedEpoch) return;
      final existingIds = _feedVideos.map((v) => v.id).toSet();
      final newItems = page.items
          .where((v) => !existingIds.contains(v.id))
          .toList();
      setState(() {
        _feedVideos.addAll(newItems);
        _feedCursor = page.nextCursor;
        _hasMoreFeed = page.hasMore;
        _isLoadingMoreFeed = false;
      });
    } catch (e) {
      if (mounted && currentEpoch == _feedEpoch) {
        setState(() => _isLoadingMoreFeed = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể tải thêm video: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _loadInitialBookings({bool silent = false}) async {
    final deps = DependenciesScope.maybeOf(context);
    if (deps == null) return;
    final currentEpoch = ++_bookingEpoch;
    final currentTargetUserId = _lastUserId;

    if (currentTargetUserId == null) {
      if (mounted) {
        setState(() {
          _bookingHistory.clear();
          _bookingCursor = null;
          _hasMoreBookings = false;
          _isLoadingBookings = false;
          _isLoadingMoreBookings = false;
          _bookingHistoryError = null;
        });
      }
      return;
    }

    if (!silent) {
      setState(() {
        _isLoadingBookings = true;
        _bookingHistoryError = null;
      });
    }
    try {
      final page = await deps.bookings.getHistory(const PageQuery(limit: 10));
      if (!mounted ||
          currentEpoch != _bookingEpoch ||
          currentTargetUserId != _lastUserId) {
        return;
      }
      setState(() {
        _bookingHistory = List.of(page.items);
        _bookingCursor = page.nextCursor;
        _hasMoreBookings = page.hasMore;
        _isLoadingBookings = false;
        _bookingHistoryError = null;
      });
    } on XlandFailure catch (e) {
      if (!mounted ||
          currentEpoch != _bookingEpoch ||
          currentTargetUserId != _lastUserId) {
        return;
      }
      setState(() {
        _bookingHistoryError = e.message;
        _isLoadingBookings = false;
      });
    } catch (e) {
      if (!mounted ||
          currentEpoch != _bookingEpoch ||
          currentTargetUserId != _lastUserId) {
        return;
      }
      setState(() {
        _bookingHistoryError = 'Không thể tải lịch sử: $e';
        _isLoadingBookings = false;
      });
    }
  }

  Future<void> _loadMoreBookings() async {
    if (_isLoadingMoreBookings || !_hasMoreBookings) return;
    final deps = DependenciesScope.maybeOf(context);
    if (deps == null) return;
    final currentEpoch = _bookingEpoch;
    final currentTargetUserId = _lastUserId;
    if (currentTargetUserId == null) return;

    setState(() => _isLoadingMoreBookings = true);
    try {
      final page = await deps.bookings.getHistory(
        PageQuery(cursor: _bookingCursor, limit: 10),
      );
      if (!mounted ||
          currentEpoch != _bookingEpoch ||
          currentTargetUserId != _lastUserId) {
        return;
      }
      final existingIds = _bookingHistory.map((b) => b.id).toSet();
      final newItems = page.items
          .where((b) => !existingIds.contains(b.id))
          .toList();
      setState(() {
        _bookingHistory.addAll(newItems);
        _bookingCursor = page.nextCursor;
        _hasMoreBookings = page.hasMore;
        _isLoadingMoreBookings = false;
      });
    } catch (e) {
      if (!mounted ||
          currentEpoch != _bookingEpoch ||
          currentTargetUserId != _lastUserId) {
        return;
      }
      setState(() => _isLoadingMoreBookings = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể tải thêm lịch hẹn: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
      if (index == 2 &&
          _bookingHistory.isEmpty &&
          !_isLoadingBookings &&
          _lastUserId != null) {
        _loadInitialBookings();
      }
    } else if (index == 2 && _lastUserId != null) {
      _loadInitialBookings();
    }
  }

  void _onTransactionsScrolled() {
    final visible =
        _transactionsScrollController.offset < _transactionHeroExtent;
    if (visible != _transactionHeroVisible) {
      setState(() => _transactionHeroVisible = visible);
    }
  }

  void _openBookingHistory() {
    _onTabTapped(2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final historyContext = _bookingHistoryAnchor.currentContext;
      if (historyContext == null) return;
      Scrollable.ensureVisible(
        historyContext,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasDeps =
        DependenciesScope.maybeOf(context) != null && !widget.forcePlaceholder;
    AuthState? authState;
    if (hasDeps) {
      try {
        authState = context.watch<AuthCubit>().state;
      } catch (_) {}
    }
    final currentUserId = authState is AuthAuthenticated
        ? authState.session.profile.id
        : null;
    if (currentUserId != _lastUserId) {
      _lastUserId = currentUserId;
      _feedEpoch++;
      _clearFeedLikes();
      _feedVideos = [];
      _feedCursor = null;
      _hasMoreFeed = false;
      _isLoadingMoreFeed = false;
      _feedError = null;
      _isLoadingFeed = true;
      if (currentUserId == null) _feedScope = FeedScope.recommended;
      _settingsReady = false;
      _bookingEpoch++;
      _bookingHistory.clear();
      _bookingCursor = null;
      _hasMoreBookings = false;
      _isLoadingBookings = false;
      _isLoadingMoreBookings = false;
      _bookingHistoryError = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadInitialFeed();
          if (_currentIndex == 2 && currentUserId != null) {
            _loadInitialBookings();
          }
        }
      });
    }

    final isEdgeToEdge = _currentIndex == 0 || _currentIndex == 2;
    final transactionOverlay =
        (_transactionHeroVisible
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark)
            .copyWith(
              statusBarColor: Colors.transparent,
              systemStatusBarContrastEnforced: false,
              systemNavigationBarColor: AppColors.surface,
              systemNavigationBarIconBrightness: Brightness.dark,
            );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _currentIndex == 0
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: const Color(0xFF0C1514),
            )
          : _currentIndex == 2
          ? transactionOverlay
          : SystemUiOverlayStyle.dark,
      child: XLandScaffold(
        safeAreaTop: !isEdgeToEdge,
        safeAreaBottom: _currentIndex != 0,
        backgroundColor: _currentIndex == 0 ? const Color(0xFF0C1514) : null,
        body: IndexedStack(
          index: _currentIndex,
          children: [
            hasDeps ? _buildDynamicFeedTab() : _buildFeedTab(),
            hasDeps ? const DiscoveryPage() : _buildExploreTabPlaceholder(),
            hasDeps
                ? _buildDynamicTransactionsTab()
                : _buildTransactionsTabPlaceholder(),
            hasDeps ? _buildDynamicProfileTab() : _buildProfileTabPlaceholder(),
          ],
        ),
        bottomNavigationBar: _currentIndex == 0
            ? null
            : XLandBottomNavBar(
                currentIndex: _currentIndex,
                onTap: _onTabTapped,
              ),
      ),
    );
  }

  Widget _buildDynamicFeedTab() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: [
            Expanded(
              child: _isLoadingFeed
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.feedGold,
                      ),
                    )
                  : _feedError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.pageGutter),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.danger,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _feedError!,
                              style: AppTypography.body.copyWith(
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            PrimaryButton(
                              label: 'Thử lại',
                              onPressed: _loadInitialFeed,
                            ),
                          ],
                        ),
                      ),
                    )
                  : _feedVideos.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.pageGutter),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.video_collection_outlined,
                              color: Colors.white70,
                              size: 56,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Chưa có video thực địa nào',
                              style: AppTypography.sectionTitle.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            PrimaryButton(
                              label: 'Tải lại',
                              onPressed: _loadInitialFeed,
                            ),
                          ],
                        ),
                      ),
                    )
                  : PageView.builder(
                      key: ObjectKey(_feedVideos),
                      scrollDirection: Axis.vertical,
                      itemCount: _feedVideos.length,
                      onPageChanged: (index) {
                        setState(() => _activeFeedIndex = index);
                        if (index >= _feedVideos.length - 2) {
                          _loadMoreFeed();
                        }
                      },
                      itemBuilder: (context, index) {
                        final video = _feedVideos[index];
                        return VideoPlayerItem(
                          key: ValueKey(
                            '$_lastUserId-${_feedScope.name}-${video.id}',
                          ),
                          video: video,
                          likeCubit: _feedLikes.putIfAbsent(
                            video.id,
                            () => VideoLikeCubit(
                              video,
                              DependenciesScope.of(context).feed,
                            ),
                          ),
                          feedScope: _feedScope,
                          onScopeChanged: _changeFeedScope,
                          onFilterTap: _openFeedFilter,
                          onNavigationTap: _showFeedNavigation,
                          onRefresh:
                              DependenciesScope.of(context).refreshContent !=
                                  null
                              ? _refreshFeed
                              : null,
                          isRefreshing: _isRefreshingFeed,
                          isCurrent:
                              _currentIndex == 0 &&
                              _activeFeedIndex == index &&
                              !_isRouteCovered,
                          isAppActive: _isAppActive,
                          autoplay: _settingsReady && _feedAutoplay,
                          mutedByDefault: _feedMutedByDefault,
                        );
                      },
                    ),
            ),
          ],
        ),
        if (_feedVideos.isEmpty || _feedError != null)
          Positioned(
            top: 0,
            left: 8,
            right: 8,
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => _changeFeedScope(FeedScope.recommended),
                    child: const Text(
                      'Dành cho bạn',
                      style: TextStyle(color: AppColors.feedGold),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Mở điều hướng',
                    onPressed: _showFeedNavigation,
                    icon: const Icon(
                      Icons.keyboard_arrow_up,
                      color: AppColors.feedGold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _changeFeedScope(FeedScope scope) async {
    if (_feedScope == scope) return;
    final auth = context.read<AuthCubit>();
    if (scope == FeedScope.following && auth.state is! AuthAuthenticated) {
      await LoginPromptSheet.show(
        context,
        title: 'Đang theo dõi',
        message: 'Đăng nhập để xem video từ người bạn theo dõi.',
        onAuthenticated: () async {
          if (mounted) _setFeedScope(scope);
        },
      );
      return;
    }
    _setFeedScope(scope);
  }

  void _setFeedScope(FeedScope scope) {
    setState(() => _feedScope = scope);
    _loadInitialFeed();
  }

  Future<void> _openFeedFilter() async {
    final deps = DependenciesScope.of(context);
    final filter = await PropertyFilterSheet.show(
      context,
      propertyRepository: deps.properties,
      currentFilter: PropertyFilter(
        regions: const [],
        areaBands: const [],
        landTypes: const [],
        savedOnly: false,
        sort: PropertySort.relevant,
      ),
    );
    if (filter == null || !mounted) return;
    // The property catalogue supports the full filter. Keep its exact draft
    // when opening from the feed rather than silently dropping criteria.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DiscoveryPage(initialFilter: filter),
      ),
    );
  }

  Future<void> _showFeedNavigation() async {
    final index = await showXLandBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: XLandLogo(),
              ),
              if (widget.onOpenGallery != null)
                ListTile(
                  leading: const Icon(Icons.widgets_outlined),
                  title: const Text('Gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onOpenGallery!();
                  },
                ),
              for (final item in [
                (0, Icons.play_circle_outline, 'Trang chủ'),
                (1, Icons.search, 'Khám phá'),
                (2, Icons.event_note_outlined, 'Giao dịch'),
                (3, Icons.person_outline, 'Tôi'),
              ])
                ListTile(
                  leading: Icon(item.$2, color: AppColors.brandPrimary),
                  title: Text(item.$3),
                  trailing: item.$1 == _currentIndex
                      ? const Icon(Icons.check, color: AppColors.goldDecorative)
                      : null,
                  onTap: () => Navigator.pop(context, item.$1),
                ),
            ],
          ),
        ),
      ),
    );
    if (index != null && mounted) _onTabTapped(index);
  }

  /// Tab 0: Trang chủ (Feed video placeholder for forcePlaceholder mode)
  Widget _buildFeedTab() {
    return Column(
      children: [
        XLandAppBar(
          variant: XLandAppBarVariant.green,
          showLogo: true,
          actions: [
            IconActionButton(
              icon: Icons.keyboard_arrow_up,
              semanticLabel: 'Mở điều hướng',
              foregroundColor: AppColors.onPrimary,
              onPressed: _showFeedNavigation,
            ),
            if (widget.onOpenGallery != null)
              TextButton.icon(
                onPressed: widget.onOpenGallery,
                icon: const Icon(
                  Icons.widgets_outlined,
                  size: 18,
                  color: AppColors.onPrimary,
                ),
                label: Text(
                  'Gallery',
                  style: AppTypography.compactStrong.copyWith(
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
            IconActionButton(
              icon: Icons.notifications_none_rounded,
              semanticLabel: 'Thông báo',
              onPressed: () {},
            ),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.pageGutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DemoDataNotice(
                  message: 'Tab Trang chủ (S00) — Đang ở bước UI Foundation Phase 1. Chưa kết nối video feed thật.',
                ),
                const SizedBox(height: AppSpacing.s16),
                XLandCard(
                  isLarge: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          StatusBadge(
                            text: 'Nguồn HĐQT',
                            variant: StatusBadgeVariant.source,
                          ),
                          Spacer(),
                          StatusBadge(
                            text: 'Đang chào bán',
                            variant: StatusBadgeVariant.sale,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      const MediaImagePlaceholder(
                        aspectRatio: 16 / 9,
                        label: 'Preview Video Thực địa Lô Đất XL-028',
                        icon: Icons.play_circle_fill_rounded,
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      Text(
                        'Đất nền KCN Hòa Lạc — Vị trí kim cương',
                        style: AppTypography.cardTitle,
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      const PriceText(
                        priceVnd: '2.400.000.000 đ',
                        unitText: '(20 tr/m²)',
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final textScaler = MediaQuery.textScalerOf(context);
                          final isLargeScale = textScaler.scale(14) > 16.0;
                          final shouldStack =
                              constraints.maxWidth < 280 || isLargeScale;

                          if (shouldStack) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                OutlineButton(
                                  label: 'Xem chi tiết',
                                  onPressed: _openDetailForXL028,
                                ),
                                const SizedBox(height: AppSpacing.s8),
                                PrimaryButton(
                                  label: 'Xem thực địa',
                                  onPressed: _openBookingForXL028,
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(
                                child: OutlineButton(
                                  label: 'Xem chi tiết',
                                  onPressed: _openDetailForXL028,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              Expanded(
                                child: PrimaryButton(
                                  label: 'Xem thực địa',
                                  onPressed: _openBookingForXL028,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openDetailForXL028() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PropertyDetailPage(
          propertyId: '00000000-0000-4000-8000-000000000005',
        ),
      ),
    );
  }

  Future<void> _openBookingForXL028() async {
    await BookingSheet.show(
      context,
      propertyId: '00000000-0000-4000-8000-000000000005',
    );
    if (mounted) _loadInitialBookings(silent: true);
  }

  /// Tab 1: Khám phá Placeholder (for backward compatibility tests)
  Widget _buildExploreTabPlaceholder() {
    return Column(
      children: [
        XLandAppBar(
          variant: XLandAppBarVariant.light,
          showLogo: true,
          title: 'Khám phá',
          actions: [
            IconActionButton(
              icon: Icons.bookmark_border_rounded,
              semanticLabel: 'Đã lưu',
              onPressed: () {},
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageGutter,
            vertical: AppSpacing.s8,
          ),
          child: SearchField(
            hint: 'Tìm theo khu vực, ngân sách...',
            onFilterTap: () {},
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.pageGutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DemoDataNotice(
                  message: 'Tab Khám phá (S01/S09) — UI Foundation Phase 1. Các lô đất hiển thị dạng placeholder chuẩn.',
                ),
                const SizedBox(height: AppSpacing.s16),
                PillTabs(
                  items: const [
                    'Tất cả',
                    'Miền Bắc',
                    'Miền Trung',
                    'Miền Nam',
                    'KCN',
                  ],
                  selectedIndex: 0,
                  onSelected: (_) {},
                ),
                const SizedBox(height: AppSpacing.s16),
                Row(
                  children: [
                    Expanded(
                      child: XLandCard(
                        padding: const EdgeInsets.all(AppSpacing.s8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const MediaImagePlaceholder(
                              aspectRatio: 4 / 3,
                              label: 'Lô đất Hòa Lạc',
                            ),
                            const SizedBox(height: AppSpacing.s8),
                            const StatusBadge(
                              text: 'Nguồn HĐQT',
                              variant: StatusBadgeVariant.source,
                            ),
                            const SizedBox(height: AppSpacing.s4),
                            Text(
                              'Hòa Lạc 120m²',
                              style: AppTypography.cardTitle,
                            ),
                            const SizedBox(height: AppSpacing.s4),
                            const PriceText(
                              priceVnd: '2,4 tỷ',
                              style: AppTypography.cardTitle,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.gapGrid),
                    Expanded(
                      child: XLandCard(
                        padding: const EdgeInsets.all(AppSpacing.s8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const MediaImagePlaceholder(
                              aspectRatio: 4 / 3,
                              label: 'Lô đất Hưng Yên',
                            ),
                            const SizedBox(height: AppSpacing.s8),
                            const StatusBadge(
                              text: 'Tin đã duyệt',
                              variant: StatusBadgeVariant.verified,
                            ),
                            const SizedBox(height: AppSpacing.s4),
                            Text(
                              'Hưng Yên 100m²',
                              style: AppTypography.cardTitle,
                            ),
                            const SizedBox(height: AppSpacing.s4),
                            const PriceText(
                              priceVnd: '1,8 tỷ',
                              style: AppTypography.cardTitle,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Tab 2: Dynamic Transactions Tab reading history from repository
  Widget _buildDynamicTransactionsTab() {
    final deps = DependenciesScope.of(context);
    final authState = context.watch<AuthCubit>().state;

    return _buildTransactionsLayout(
      history: authState is! AuthAuthenticated
          ? _buildBookingHistoryLogin()
          : _buildBookingHistorySection(deps),
    );
  }

  Widget _buildBookingHistoryLogin() {
    return XLandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InfoNotice(
            title: 'Tài khoản khách',
            message: 'Vui lòng đăng nhập để xem danh sách lịch hẹn khảo sát thực địa của bạn.',
            variant: NoticeVariant.info,
          ),
          const SizedBox(height: AppSpacing.s16),
          PrimaryButton(
            label: 'Đăng nhập ngay',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const LoginPage())),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsLayout({required Widget history}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _transactionHeroExtent = constraints.maxHeight;
        final topInset = MediaQuery.viewPaddingOf(context).top;
        return RefreshIndicator(
          color: AppColors.brandPrimary,
          edgeOffset: topInset,
          onRefresh: () => _loadInitialBookings(silent: true),
          child: SingleChildScrollView(
            key: const PageStorageKey('transactions-scroll'),
            controller: _transactionsScrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: _transactionHeroExtent,
                  child: TransactionNftHero(
                    active:
                        _currentIndex == 2 &&
                        _isAppActive &&
                        !_isRouteCovered &&
                        _transactionHeroVisible,
                  ),
                ),
                Padding(
                  key: _bookingHistoryAnchor,
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.pageGutter,
                    topInset + AppSpacing.pageGutter,
                    AppSpacing.pageGutter,
                    AppSpacing.pageGutter,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          (constraints.maxHeight -
                                  topInset -
                                  AppSpacing.pageGutter * 2)
                              .clamp(0, double.infinity),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lịch sử đặt lịch thực địa',
                          style: AppTypography.sectionTitle,
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        history,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBookingHistorySection(XlandDependencies deps) {
    if (_isLoadingBookings && _bookingHistory.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.s32),
          child: CircularProgressIndicator(color: AppColors.brandPrimary),
        ),
      );
    }

    if (_bookingHistoryError != null && _bookingHistory.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.danger),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(
                'Không thể tải lịch sử: $_bookingHistoryError',
                style: AppTypography.compact.copyWith(color: AppColors.danger),
              ),
            ),
            TextButton(
              onPressed: () => _loadInitialBookings(),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (_bookingHistory.isEmpty) {
      return XLandCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 36,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                'Bạn chưa có lịch hẹn thực địa nào.',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        ..._bookingHistory.map<Widget>((Booking b) {
          final statusText = switch (b.status) {
            BookingStatus.awaitingDeposit => 'Chờ thanh toán cọc',
            BookingStatus.pendingConfirmation => 'Chờ xác nhận',
            BookingStatus.confirmed => 'Đã xác nhận',
            BookingStatus.completed => 'Đã hoàn thành',
            BookingStatus.cancelled => 'Đã hủy',
            _ => 'Đang xử lý',
          };
          final statusVariant = switch (b.status) {
            BookingStatus.confirmed => StatusBadgeVariant.verified,
            BookingStatus.cancelled => StatusBadgeVariant.danger,
            _ => StatusBadgeVariant.pending,
          };

          final timeStr = formatBusinessDateTime(
            b.requestedStartsAt,
            b.timeZone,
          );

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s12),
            child: XLandCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: AppSpacing.s8,
                    runSpacing: AppSpacing.s8,
                    children: [
                      Tooltip(
                        message: b.id,
                        child: Text(
                          'Mã: #${formatResourceReference(b.id)}',
                          style: AppTypography.compactStrong,
                        ),
                      ),
                      StatusBadge(text: statusText, variant: statusVariant),
                    ],
                  ),
                  const Divider(height: AppSpacing.s16),
                  Text(b.property.title, style: AppTypography.cardTitle),
                  const SizedBox(height: AppSpacing.s4),
                  Text('Thời gian: $timeStr', style: AppTypography.body),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    'Điểm đón: ${b.proposedMeetingArea.label}',
                    style: AppTypography.compact,
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  Row(
                    children: [
                      StatusBadge(
                        text: b.paymentStatus == PaymentStatus.unpaid
                            ? 'Chờ thanh toán cọc'
                            : b.paymentStatus == PaymentStatus.succeeded
                            ? 'Đã đặt cọc'
                            : 'Chờ xử lý',
                        variant: b.paymentStatus == PaymentStatus.succeeded
                            ? StatusBadgeVariant.verified
                            : StatusBadgeVariant.pending,
                      ),
                      const Spacer(),
                      OutlineButton(
                        label: 'Chi tiết lịch',
                        fullWidth: false,
                        height: 36,
                        onPressed: () {
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      BookingDetailPage(bookingId: b.id),
                                ),
                              )
                              .then((_) {
                                if (mounted) _loadInitialBookings(silent: true);
                              });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        if (_hasMoreBookings)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _isLoadingMoreBookings
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.brandPrimary,
                    ),
                  )
                : OutlineButton(
                    label: 'Tải thêm lịch hẹn',
                    onPressed: _loadMoreBookings,
                  ),
          ),
      ],
    );
  }

  /// Tab 2: Giao dịch Placeholder (for backward compatibility tests)
  Widget _buildTransactionsTabPlaceholder() {
    return _buildTransactionsLayout(history: _buildBookingHistoryLogin());
  }

  /// Tab 3: Dynamic Profile tab wired with AuthCubit
  Widget _buildDynamicProfileTab() {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        final isAuthenticated = authState is AuthAuthenticated;
        final profile = isAuthenticated ? authState.session.profile : null;

        return Column(
          children: [
            const XLandAppBar(
              variant: XLandAppBarVariant.light,
              title: 'Tài khoản của tôi',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.pageGutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (authState is AuthGuest &&
                        authState.warningMessage != null) ...[
                      InfoNotice(
                        title: 'Thông báo phiên làm việc',
                        message: authState.warningMessage!,
                        variant: NoticeVariant.warning,
                      ),
                      const SizedBox(height: AppSpacing.s12),
                    ],
                    XLandCard(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: AppColors.verifiedSurface,
                            child: Icon(
                              isAuthenticated
                                  ? Icons.person_rounded
                                  : Icons.person_outline_rounded,
                              size: 32,
                              color: AppColors.brandPrimary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isAuthenticated
                                      ? profile!.displayName
                                      : 'Khách hàng XLand',
                                  style: AppTypography.cardTitle,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isAuthenticated
                                      ? (profile!.contactVerified
                                            ? 'Đã xác thực SĐT • ${profile.contactPhone ?? "Chưa có SĐT"}'
                                            : 'Chưa xác thực SĐT • ${profile.contactPhone ?? "Chưa có SĐT"}')
                                      : 'Chưa đăng nhập • Trải nghiệm tài khoản khách',
                                  style: AppTypography.compact,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    if (isAuthenticated)
                      OutlineButton(
                        label: 'Đăng xuất',
                        onPressed: () => context.read<AuthCubit>().signOut(),
                      )
                    else
                      PrimaryButton(
                        label: 'Đăng nhập',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const LoginPage(),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: AppSpacing.s24),
                    Text(
                      'Cài đặt & Tiện ích',
                      style: AppTypography.sectionTitle,
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    _buildSettingsList(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Tab 3: Tôi (Profile & Cài đặt Placeholder)
  Widget _buildProfileTabPlaceholder() {
    return Column(
      children: [
        const XLandAppBar(
          variant: XLandAppBarVariant.light,
          title: 'Tài khoản của tôi',
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.pageGutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                XLandCard(
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.verifiedSurface,
                        child: Icon(
                          Icons.person_rounded,
                          size: 32,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Khách hàng XLand',
                              style: AppTypography.cardTitle,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Chưa đăng nhập • Trải nghiệm tài khoản khách',
                              style: AppTypography.compact,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
                PrimaryButton(
                  label: 'Đăng nhập',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LoginPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.s24),
                Text('Cài đặt & Tiện ích', style: AppTypography.sectionTitle),
                const SizedBox(height: AppSpacing.s8),
                _buildSettingsList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsList() {
    return XLandCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(
              Icons.event_note_outlined,
              color: AppColors.brandPrimary,
            ),
            title: Text('Lịch sử đặt lịch thực địa', style: AppTypography.body),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _openBookingHistory,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(
              Icons.bookmark_outline_rounded,
              color: AppColors.brandPrimary,
            ),
            title: Text('Bất động sản đã lưu', style: AppTypography.body),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SavedPropertiesPage(),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(
              Icons.video_library_outlined,
              color: AppColors.brandPrimary,
            ),
            title: Text('Video đã lưu', style: AppTypography.body),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SavedVideosPage(),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(
              Icons.person_outline_rounded,
              color: AppColors.brandPrimary,
            ),
            title: Text('Chỉnh sửa hồ sơ', style: AppTypography.body),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute<void>(
                      builder: (_) => const EditProfilePage(),
                    ),
                  )
                  .then((_) {
                    if (mounted) {
                      _loadSettings();
                      context.read<AuthCubit>().checkSession();
                    }
                  });
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(
              Icons.settings_outlined,
              color: AppColors.brandPrimary,
            ),
            title: Text('Cài đặt ứng dụng', style: AppTypography.body),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsPage(),
                    ),
                  )
                  .then((_) {
                    if (mounted) _loadSettings();
                  });
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(
              Icons.info_outline_rounded,
              color: AppColors.brandPrimary,
            ),
            title: Text('Về XLand & Chính sách', style: AppTypography.body),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _showPolicySheet,
          ),
          if (widget.onOpenGallery != null) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(
                Icons.widgets_outlined,
                color: AppColors.brandPrimary,
              ),
              title: Text('Component Gallery (Dev)', style: AppTypography.body),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: widget.onOpenGallery,
            ),
          ],
        ],
      ),
    );
  }

  void _showPolicySheet() {
    showXLandBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.sheetTop),
            ),
          ),
          padding: const EdgeInsets.all(AppSpacing.pageGutter),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Về XLand & Chính sách',
                    style: AppTypography.sheetTitle,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.s16),
              const InfoNotice(
                title: 'Nền tảng giao dịch BĐS minh bạch',
                message: 'XLand là nền tảng khảo sát và đầu tư bất động sản vùng ven, KCN công nghệ cao với pháp lý 100% được thẩm định độc lập.',
                variant: NoticeVariant.info,
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(
                'Chính sách đặt cọc thực địa:',
                style: AppTypography.bodyStrong,
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                'Tiền cọc xem thực địa dự kiến 350.000 VNĐ. Chính sách áp dụng và thanh toán tạm thời còn thiếu, sẽ bổ sung sau. Ứng dụng hiện chưa thu tiền cọc.',
                style: AppTypography.compact,
              ),
              const SizedBox(height: AppSpacing.s16),
              PrimaryButton(
                label: 'Đã hiểu',
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }
}
