import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/xland_domain.dart';
import '../../../shared/di/dependencies_scope.dart';
import '../../../shared/widgets/illustrative_image.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/theme.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import '../../auth/widgets/login_prompt_sheet.dart';
import '../../consultant/pages/consultant_profile_page.dart';
import '../../feed/pages/shared_video_page.dart';

/// Public profile resolved from the video author, independently of the property.
class AuthorProfilePage extends StatefulWidget {
  const AuthorProfilePage({super.key, required this.authorId});
  final String authorId;

  @override
  State<AuthorProfilePage> createState() => _AuthorProfilePageState();
}

class _AuthorProfilePageState extends State<AuthorProfilePage> {
  AuthorProfile? _profile;
  String? _error;
  bool _loading = true;
  bool _following = false;
  int _followers = 0;
  bool _savingFollow = false;
  final List<FeedVideo> _videos = [];
  bool _loadingVideos = false;
  String? _videosError;
  String? _nextCursor;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await DependenciesScope.of(context).feed
          .getAuthorProfile(widget.authorId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _following = profile.author.isFollowing;
        _followers = profile.followerCount;
        _loading = false;
      });
      if (profile.consultantId == null) await _loadVideos(reset: true);
    } on XlandFailure catch (e) {
      if (mounted) {
        setState(() {
          _error = e.code == FailureCode.notFound
              ? 'Không tìm thấy hồ sơ người đăng.'
              : 'Không thể tải hồ sơ người đăng. Vui lòng thử lại.';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Không thể tải hồ sơ người đăng. Vui lòng thử lại.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadVideos({bool reset = false}) async {
    if (!mounted || _loadingVideos) return;
    setState(() {
      _loadingVideos = true;
      _videosError = null;
      if (reset) {
        _videos.clear();
        _nextCursor = null;
        _hasMore = false;
      }
    });
    try {
      final page = await DependenciesScope.of(context).feed.getAuthorVideos(
        widget.authorId,
        PageQuery(limit: 20, cursor: reset ? null : _nextCursor),
      );
      if (!mounted) return;
      setState(() {
        _videos.addAll(page.items);
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } on XlandFailure catch (e) {
      if (mounted) setState(() => _videosError = e.message);
    } catch (_) {
      if (mounted) setState(() => _videosError = 'Không thể tải video.');
    } finally {
      if (mounted) setState(() => _loadingVideos = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_savingFollow || _profile == null) return;
    if (context.read<AuthCubit>().state is! AuthAuthenticated) {
      final loggedIn = await LoginPromptSheet.show(
        context,
        title: 'Đăng nhập để theo dõi',
        message: 'Vui lòng đăng nhập để theo dõi người đăng video.',
      );
      if (!loggedIn || !mounted) return;
    }
    setState(() => _savingFollow = true);
    try {
      final result = await DependenciesScope.of(context).feed
          .setFollowing(widget.authorId, !_following);
      if (!mounted) return;
      setState(() {
        _followers = result.count ?? (_followers + (result.active ? 1 : -1));
        if (_followers < 0) _followers = 0;
        _following = result.active;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể cập nhật theo dõi. Vui lòng thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingFollow = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (!_loading && _error == null && profile?.consultantId != null) {
      return ConsultantProfilePage(consultantId: profile!.consultantId!);
    }
    return XLandScaffold(
      appBar: const XLandAppBar(title: 'Hồ sơ người đăng', showBack: true),
      body: _loading
          ? const LoadingState()
          : _error != null || profile == null
          ? ErrorRetryState(
              errorMessage: _error ?? 'Không tìm thấy hồ sơ.',
              onRetry: _loadProfile,
            )
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _header(profile)),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
                      child: Text('Video', style: AppTypography.sectionTitle),
                    ),
                  ),
                  if (_videos.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      sliver: SliverGrid.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 6,
                              mainAxisSpacing: 12,
                              childAspectRatio: .62,
                            ),
                        itemCount: _videos.length,
                        itemBuilder: (context, index) =>
                            _videoTile(_videos[index]),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _loadingVideos
                          ? const Center(child: CircularProgressIndicator())
                          : _videosError != null
                          ? Column(
                              children: [
                                Text(
                                  _videosError!,
                                  textAlign: TextAlign.center,
                                ),
                                TextButton(
                                  onPressed: () => _loadVideos(),
                                  child: const Text('Thử lại'),
                                ),
                              ],
                            )
                          : _videos.isEmpty
                          ? const Text(
                              'Người đăng chưa có video công khai.',
                              textAlign: TextAlign.center,
                            )
                          : _hasMore
                          ? OutlineButton(
                              label: 'Xem thêm video',
                              onPressed: () => _loadVideos(),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _header(AuthorProfile profile) {
    final author = profile.author;
    final auth = context.watch<AuthCubit>().state;
    final isSelf =
        auth is AuthAuthenticated && auth.session.profile.id == author.id;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: ClipOval(
              child: author.avatarUrl == null && !profile.isIllustrative
                  ? const ColoredBox(
                      color: AppColors.disabledSurface,
                      child: Icon(
                        Icons.person_outline,
                        size: 48,
                        color: AppColors.brandPrimary,
                      ),
                    )
                  : XLandMediaImage(
                      url: author.avatarUrl,
                      isIllustrative: profile.isIllustrative,
                      illustrativeAsset: IllustrativeAssets.consultant,
                      showLabel: false,
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            author.displayName,
            textAlign: TextAlign.center,
            style: AppTypography.pageHero,
          ),
          Text(
            author.role ?? 'Người đăng video',
            textAlign: TextAlign.center,
            style: AppTypography.body,
          ),
          if (author.isVerified)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: StatusBadge(
                text: 'Danh tính đã xác minh',
                variant: StatusBadgeVariant.verified,
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _stat('${profile.videoCount}', 'Video'),
              _stat('$_followers', 'Người theo dõi'),
            ],
          ),
          if (!isSelf)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: PrimaryButton(
                label: _following ? 'Đang theo dõi' : 'Theo dõi',
                isSubmitting: _savingFollow,
                onPressed: _toggleFollow,
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) => Column(
    children: [
      Text(value, style: AppTypography.bodyStrong),
      Text(label, style: AppTypography.compact),
    ],
  );

  Widget _videoTile(FeedVideo video) => InkWell(
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SharedVideoPage(
          videoId: video.id,
          title: 'Video của ${_profile!.author.displayName}',
        ),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                XLandMediaImage(
                  url: video.media.thumbnailUrl,
                  isIllustrative: video.isIllustrative,
                  showLabel: false,
                ),
                Positioned(
                  left: 5,
                  bottom: 5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Text(
                        '▶ ${video.viewCount}',
                        style: AppTypography.compact.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          video.caption,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.compact,
        ),
      ],
    ),
  );
}
