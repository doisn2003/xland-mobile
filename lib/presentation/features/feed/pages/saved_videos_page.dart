import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../domain/xland_domain.dart';
import '../../../shared/di/dependencies_scope.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/theme.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import '../../auth/pages/login_page.dart';
import '../../booking/pages/booking_sheet.dart';
import '../../property_detail/pages/property_detail_page.dart';

/// Saved Videos Page (Video đã lưu).
/// Shows list of videos bookmarked by user, fetched from FeedRepository.getSavedVideos.
class SavedVideosPage extends StatefulWidget {
  const SavedVideosPage({super.key});

  @override
  State<SavedVideosPage> createState() => _SavedVideosPageState();
}

class _SavedVideosPageState extends State<SavedVideosPage> {
  List<FeedVideo> _videos = [];
  bool _isLoading = true;
  String? _errorMessage;

  String? _nextCursor;
  bool _hasMore = false;
  bool _isLoadingMore = false;
  String? _loadMoreError;

  int _requestEpoch = 0;
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedVideos();
    });
  }

  Future<void> _loadSavedVideos() async {
    if (!mounted) return;
    final deps = DependenciesScope.of(context);
    final currentEpoch = ++_requestEpoch;
    final targetUserId = _lastUserId;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final page = await deps.feed.getSavedVideos(const PageQuery(limit: 10));
      if (!mounted || currentEpoch != _requestEpoch || targetUserId != _lastUserId) return;
      setState(() {
        _videos = List.of(page.items);
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
        _isLoading = false;
      });
    } on XlandFailure catch (e) {
      if (!mounted || currentEpoch != _requestEpoch || targetUserId != _lastUserId) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || currentEpoch != _requestEpoch || targetUserId != _lastUserId) return;
      setState(() {
        _errorMessage = 'Không thể tải danh sách video đã lưu: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreSavedVideos() async {
    if (_isLoadingMore || !_hasMore) return;
    final deps = DependenciesScope.of(context);
    final currentEpoch = _requestEpoch;
    final targetUserId = _lastUserId;
    if (targetUserId == null) return;

    setState(() {
      _isLoadingMore = true;
      _loadMoreError = null;
    });

    try {
      final page = await deps.feed.getSavedVideos(PageQuery(cursor: _nextCursor, limit: 10));
      if (!mounted || currentEpoch != _requestEpoch || targetUserId != _lastUserId) return;
      final existingIds = _videos.map((v) => v.id).toSet();
      final newItems = page.items.where((v) => !existingIds.contains(v.id)).toList();
      setState(() {
        _videos.addAll(newItems);
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
        _isLoadingMore = false;
      });
    } on XlandFailure catch (e) {
      if (!mounted || currentEpoch != _requestEpoch || targetUserId != _lastUserId) return;
      setState(() {
        _loadMoreError = e.message;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted || currentEpoch != _requestEpoch || targetUserId != _lastUserId) return;
      setState(() {
        _loadMoreError = 'Lỗi tải thêm: $e';
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _handleUnsave(String videoId) async {
    final deps = DependenciesScope.of(context);
    try {
      await deps.feed.setSaved(videoId, false);
      if (!mounted) return;
      setState(() {
        _videos = _videos.where((v) => v.id != videoId).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa video khỏi danh sách đã lưu.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể bỏ lưu video: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    AuthState? authState;
    try {
      authState = context.watch<AuthCubit>().state;
    } catch (_) {}
    final currentUserId = authState is AuthAuthenticated ? authState.session.profile.id : null;
    if (currentUserId != _lastUserId) {
      _lastUserId = currentUserId;
      _requestEpoch++;
      _videos = [];
      _nextCursor = null;
      _hasMore = false;
      _isLoading = false;
      _isLoadingMore = false;
      _errorMessage = null;
      _loadMoreError = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadSavedVideos();
      });
    }

    final isGuest = currentUserId == null;

    return XLandScaffold(
      appBar: const XLandAppBar(
        title: 'Video đã lưu',
        variant: XLandAppBarVariant.light,
      ),
      body: isGuest
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.pageGutter),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 56, color: AppColors.textSecondary),
                    const SizedBox(height: AppSpacing.s12),
                    Text('Tài khoản khách', style: AppTypography.sectionTitle),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      'Vui lòng đăng nhập để xem danh sách video thực địa đã lưu của bạn.',
                      style: AppTypography.compact.copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    PrimaryButton(
                      label: 'Đăng nhập',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const LoginPage()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            )
          : _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brandPrimary))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.pageGutter),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 48),
                        const SizedBox(height: AppSpacing.s12),
                        Text(_errorMessage!, style: AppTypography.body, textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.s16),
                        PrimaryButton(label: 'Thử lại', onPressed: _loadSavedVideos),
                      ],
                    ),
                  ),
                )
              : _videos.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.pageGutter),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.video_library_outlined, size: 56, color: AppColors.textSecondary),
                            const SizedBox(height: AppSpacing.s12),
                            Text('Chưa có video nào được lưu', style: AppTypography.sectionTitle),
                            const SizedBox(height: AppSpacing.s4),
                            Text(
                              'Nhấn biểu tượng lưu trên các video thực địa tại Trang chủ để xem lại sau.',
                              style: AppTypography.compact.copyWith(color: AppColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.pageGutter),
                      itemCount: _videos.length + (_hasMore ? 1 : 0),
                      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.s16),
                      itemBuilder: (context, idx) {
                        if (idx == _videos.length) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: _isLoadingMore
                                  ? const CircularProgressIndicator(color: AppColors.brandPrimary)
                                  : _loadMoreError != null
                                      ? TextButton.icon(
                                          onPressed: _loadMoreSavedVideos,
                                          icon: const Icon(Icons.refresh_rounded, size: 16),
                                          label: Text('Lỗi: $_loadMoreError. Thử lại'),
                                        )
                                      : OutlineButton(
                                          label: 'Tải thêm video',
                                          onPressed: _loadMoreSavedVideos,
                                        ),
                            ),
                          );
                        }
                        final v = _videos[idx];
                        return XLandCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppColors.verifiedSurface,
                                    child: Text(
                                      v.author.displayName.isNotEmpty ? v.author.displayName[0] : 'U',
                                      style: AppTypography.compactStrong.copyWith(color: AppColors.brandPrimary),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.s8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(v.author.displayName, style: AppTypography.compactStrong),
                                        Text(v.approximateArea, style: AppTypography.compact.copyWith(color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.bookmark_remove_outlined, color: AppColors.danger),
                                    tooltip: 'Bỏ lưu video',
                                    onPressed: () => _handleUnsave(v.id),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.s8),
                              Text(v.caption, style: AppTypography.bodyStrong),
                              const SizedBox(height: AppSpacing.s4),
                              Text(v.property.title, style: AppTypography.compact.copyWith(color: AppColors.brandPrimary)),
                              const SizedBox(height: AppSpacing.s12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlineButton(
                                      label: 'Xem chi tiết',
                                      height: 36,
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => PropertyDetailPage(propertyId: v.propertyId),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.s8),
                                  Expanded(
                                    child: PrimaryButton(
                                      label: 'Xem thực địa',
                                      height: 36,
                                      onPressed: () {
                                        BookingSheet.show(context, propertyId: v.propertyId);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
