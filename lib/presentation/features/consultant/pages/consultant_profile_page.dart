import 'package:flutter/material.dart';

import '../../../shared/widgets/illustrative_image.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/xland_domain.dart';
import '../../../shared/di/dependencies_scope.dart';
import '../../../shared/utils/value_formatters.dart';
import '../../../shared/widgets/widgets.dart';
import '../../feed/widgets/video_player_item.dart';
import '../../discovery/widgets/property_card.dart';
import '../../../theme/theme.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import '../../auth/widgets/login_prompt_sheet.dart';
import '../../property_detail/pages/property_detail_page.dart';

/// S06 Consultant Profile Page.
/// Features:
/// - 3 tabs: Giới thiệu (Overview) / Video thực địa (Videos) / Bất động sản phụ trách (Listings)
/// - Follow / Unfollow consultant action (with Auth Gate)
/// - Support request ticket submission (not instant chat, with Auth Gate, lifecycle & retry key stability)
class ConsultantProfilePage extends StatefulWidget {
  const ConsultantProfilePage({super.key, required this.consultantId});

  final String consultantId;

  @override
  State<ConsultantProfilePage> createState() => _ConsultantProfilePageState();
}

class _ConsultantProfilePageState extends State<ConsultantProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Consultant? _consultant;
  bool _isLoading = true;
  String? _errorMessage;

  bool _isFollowing = false;
  int _followerCount = 0;
  bool _isTogglingFollow = false;

  List<FeedVideo> _videos = [];
  bool _isLoadingVideos = false;
  String? _videosError;

  List<ConsultantReview> _reviews = [];
  bool _isLoadingReviews = false;
  String? _reviewsError;

  List<Property> _listings = [];
  bool _isLoadingListings = false;
  String? _listingsError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConsultant();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 0 && _videos.isEmpty && !_isLoadingVideos) {
      _loadVideos();
    } else if (_tabController.index == 1 &&
        _listings.isEmpty &&
        !_isLoadingListings) {
      _loadListings();
    } else if (_tabController.index == 2 &&
        _reviews.isEmpty &&
        !_isLoadingReviews) {
      _loadReviews();
    }
  }

  Future<void> _loadConsultant() async {
    if (!mounted) return;
    final deps = DependenciesScope.of(context);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final consultant = await deps.consultants.getConsultant(
        widget.consultantId,
      );
      if (!mounted) return;
      setState(() {
        _consultant = consultant;
        _isFollowing = consultant.isFollowing;
        _followerCount = consultant.followerCount;
        _isLoading = false;
      });
      // Pre-load videos & listings
      _loadVideos();
      _loadListings();
    } on XlandFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không thể tải thông tin tư vấn viên: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadVideos() async {
    if (!mounted) return;
    final deps = DependenciesScope.of(context);
    setState(() {
      _isLoadingVideos = true;
      _videosError = null;
    });
    try {
      final page = await deps.consultants.getVideos(
        widget.consultantId,
        const PageQuery(limit: 20),
      );
      if (!mounted) return;
      setState(() {
        _videos = page.items;
        _videosError = null;
        _isLoadingVideos = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _videosError = 'Không thể tải danh sách video: $e';
        _isLoadingVideos = false;
      });
    }
  }

  Future<void> _loadListings() async {
    if (!mounted) return;
    final deps = DependenciesScope.of(context);
    setState(() {
      _isLoadingListings = true;
      _listingsError = null;
    });
    try {
      final page = await deps.consultants.getListings(
        widget.consultantId,
        const PageQuery(limit: 20),
      );
      if (!mounted) return;
      setState(() {
        _listings = page.items;
        _listingsError = null;
        _isLoadingListings = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _listingsError = 'Không thể tải bất động sản phụ trách: $e';
        _isLoadingListings = false;
      });
    }
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isLoadingReviews = true;
      _reviewsError = null;
    });
    try {
      final page = await DependenciesScope.of(context).consultants
          .getReviews(widget.consultantId, const PageQuery(limit: 20));
      if (mounted) {
        setState(() {
          _reviews = page.items;
          _isLoadingReviews = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _reviewsError = 'Không thể tải đánh giá';
          _isLoadingReviews = false;
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (_consultant == null || _isTogglingFollow || !mounted) return;
    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) {
      final didLogin = await LoginPromptSheet.show(
        context,
        title: 'Đăng nhập để theo dõi',
        message: 'Vui lòng đăng nhập để theo dõi chuyên viên tư vấn.',
      );
      if (!didLogin || !mounted) return;
    }

    final deps = DependenciesScope.of(context);
    final nextFollowState = !_isFollowing;

    setState(() {
      _isTogglingFollow = true;
      _isFollowing = nextFollowState;
      _followerCount += nextFollowState ? 1 : -1;
    });

    try {
      await deps.feed.setFollowing(widget.consultantId, nextFollowState);
      if (!mounted) return;
      setState(() => _isTogglingFollow = false);
    } catch (_) {
      if (!mounted) return;
      // Revert on failure
      setState(() {
        _isFollowing = !nextFollowState;
        _followerCount += nextFollowState ? -1 : 1;
        _isTogglingFollow = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể cập nhật theo dõi. Vui lòng thử lại.'),
        ),
      );
    }
  }

  Future<void> _showSupportTicketSheet() async {
    final authState = context.read<AuthCubit>().state;
    String initialName = '';
    String initialPhone = '';

    if (authState is! AuthAuthenticated) {
      final didLogin = await LoginPromptSheet.show(
        context,
        title: 'Đăng nhập để gửi yêu cầu hỗ trợ',
        message: 'Vui lòng đăng nhập để gửi phiếu yêu cầu tư vấn.',
      );
      if (!didLogin || !mounted) return;
      final updatedAuth = context.read<AuthCubit>().state;
      if (updatedAuth is AuthAuthenticated) {
        initialName = updatedAuth.session.profile.displayName;
        initialPhone = updatedAuth.session.profile.contactPhone ?? '';
      }
    } else {
      initialName = authState.session.profile.displayName;
      initialPhone = authState.session.profile.contactPhone ?? '';
    }

    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    await showXLandBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ConsultantSupportSheetBody(
          consultantId: widget.consultantId,
          initialName: initialName,
          initialPhone: initialPhone,
          onSuccess: (notice) {
            Navigator.of(sheetContext).pop();
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(notice),
                backgroundColor: AppColors.brandPrimary,
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const XLandScaffold(
        appBar: XLandAppBar(
          title: 'Tư vấn viên',
          variant: XLandAppBarVariant.light,
        ),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.brandPrimary),
        ),
      );
    }

    if (_errorMessage != null || _consultant == null) {
      return XLandScaffold(
        appBar: const XLandAppBar(
          title: 'Tư vấn viên',
          variant: XLandAppBarVariant.light,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.pageGutter),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: AppColors.danger,
                ),
                const SizedBox(height: AppSpacing.s12),
                Text(
                  _errorMessage ?? 'Không tìm thấy tư vấn viên.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body,
                ),
                const SizedBox(height: AppSpacing.s16),
                PrimaryButton(label: 'Thử lại', onPressed: _loadConsultant),
              ],
            ),
          ),
        ),
      );
    }

    final c = _consultant!;

    return XLandScaffold(
      appBar: XLandAppBar(
        showBack: true,
        showLogo: true,
        actions: [
          IconActionButton(
            icon: Icons.share_outlined,
            semanticLabel: 'Chia sẻ thông tin tư vấn viên',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Chia sẻ liên kết tạm thời còn thiếu, sẽ bổ sung sau.',
                ),
              ),
            ),
          ),
        ],
      ),
      stickyFooter: StickyActionBar(
        child: PrimaryButton(
          label: 'Hẹn tư vấn với ${c.name}',
          icon: const Icon(Icons.calendar_today_outlined, size: 22),
          onPressed: _showSupportTicketSheet,
        ),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Column(
              children: [
                SizedBox(
                  height: 174,
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 132,
                        child: XLandMediaImage(
                          url: c.coverUrl,
                          isIllustrative: c.isIllustrative,
                          showLabel: false,
                        ),
                      ),
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 132,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xAA0F4C3A), Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        top: 22,
                        child: Text(
                          'Giá trị thật\ncho những vùng đất\ntiềm năng',
                          style: AppTypography.cardTitle.copyWith(
                            color: Colors.white,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            width: 96,
                            height: 96,
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: ClipOval(
                              child: XLandMediaImage(
                                url: c.avatarUrl,
                                isIllustrative: c.isIllustrative,
                                illustrativeAsset:
                                    IllustrativeAssets.consultant,
                                showLabel: false,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(c.name, style: AppTypography.pageHero),
                Text(
                  '${c.role} • ${c.location}',
                  style: AppTypography.body,
                  textAlign: TextAlign.center,
                ),
                if (c.isVerified)
                  const Padding(
                    padding: EdgeInsets.only(top: 7),
                    child: StatusBadge(
                      text: 'Danh tính đã xác minh',
                      variant: StatusBadgeVariant.verified,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          label: _isFollowing ? 'Đang theo dõi' : 'Theo dõi',
                          isSubmitting: _isTogglingFollow,
                          icon: const Icon(
                            Icons.person_add_alt_1_outlined,
                            size: 21,
                          ),
                          onPressed: _toggleFollow,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlineButton(
                          label: 'Nhắn tư vấn',
                          icon: const Icon(Icons.chat_bubble_outline, size: 21),
                          onPressed: _showSupportTicketSheet,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildStatCard(label: 'Video', value: '${c.videoCount}'),
                      _buildStatCard(
                        label: 'Theo dõi',
                        value: '$_followerCount',
                      ),
                      _buildStatCard(
                        label: 'Đánh giá',
                        value: c.rating == null
                            ? 'Chưa có'
                            : '${formatDecimalValue(c.rating!)}/5',
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    'Người đăng và tư vấn • Không mặc định là chủ sở hữu tài sản',
                    style: AppTypography.compact,
                    textAlign: TextAlign.center,
                  ),
                ),
                if (c.nextAvailableAt != null)
                  ListTile(
                    leading: const Icon(
                      Icons.event_available_outlined,
                      color: AppColors.goldDecorative,
                    ),
                    title: const Text(
                      'Lịch tư vấn gần nhất',
                      style: AppTypography.bodyStrong,
                    ),
                    subtitle: Text(
                      '${c.nextAvailableAt!.day}/${c.nextAvailableAt!.month}/${c.nextAvailableAt!.year}',
                      style: AppTypography.body,
                    ),
                    onTap: _showSupportTicketSheet,
                  ),
              ],
            ),
          ),
        ],
        body: Column(
          children: [
            TabBar(
              controller: _tabController,
              labelColor: AppColors.brandPrimary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.brandPrimary,
              tabs: const [
                Tab(text: 'Video'),
                Tab(text: 'Lô đang bán'),
                Tab(text: 'Đánh giá'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildVideosTab(),
                  _buildListingsTab(),
                  _buildReviewsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsTab() {
    if (_isLoadingReviews) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_reviewsError != null) {
      return Center(
        child: TextButton(
          onPressed: _loadReviews,
          child: Text('$_reviewsError • Thử lại'),
        ),
      );
    }
    if (_reviews.isEmpty) {
      return const Center(child: Text('Chưa có đánh giá được chia sẻ.'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final review in _reviews)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: XLandCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review.authorDisplayName,
                    style: AppTypography.bodyStrong,
                  ),
                  Text(
                    '★ ${formatDecimalValue(review.rating)}',
                    style: AppTypography.body.copyWith(
                      color: AppColors.goldForeground,
                    ),
                  ),
                  Text(review.text, style: AppTypography.body),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatCard({required String label, required String value}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.s8,
          horizontal: 4,
        ),
        decoration: BoxDecoration(
          color: AppColors.disabledSurface,
          borderRadius: BorderRadius.circular(AppRadius.thumbnail),
        ),
        child: Column(
          children: [
            Text(value, style: AppTypography.cardTitle),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.compact.copyWith(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideosTab() {
    if (_isLoadingVideos) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brandPrimary),
      );
    }
    if (_videosError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pageGutter),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: AppColors.danger,
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                _videosError!,
                textAlign: TextAlign.center,
                style: AppTypography.body,
              ),
              const SizedBox(height: AppSpacing.s12),
              PrimaryButton(label: 'Thử lại', onPressed: _loadVideos),
            ],
          ),
        ),
      );
    }
    if (_videos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pageGutter),
          child: Text(
            'Chưa có video thực địa nào được tải lên.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _videos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 10,
        childAspectRatio: .68,
      ),
      itemBuilder: (context, index) {
        final v = _videos[index];
        return InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                backgroundColor: Colors.black,
                body: Stack(
                  children: [
                    VideoPlayerItem(
                      video: v,
                      isCurrent: true,
                      isAppActive: true,
                      onNavigationTap: () => Navigator.pop(context),
                    ),
                    SafeArea(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: BackButton(color: Colors.white),
                      ),
                    ),
                  ],
                ),
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
                        url: v.media.thumbnailUrl,
                        isIllustrative: v.isIllustrative,
                        showLabel: false,
                      ),
                      Positioned(
                        top: 5,
                        left: 5,
                        child: Text(
                          '▶ ${v.viewCount}',
                          style: AppTypography.compact.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 5,
                        left: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandPrimary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            formatCompactVnd(v.property.priceTotal),
                            style: AppTypography.compact.copyWith(
                              color: Colors.white,
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
                v.caption,
                style: AppTypography.compact,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListingsTab() {
    if (_isLoadingListings) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brandPrimary),
      );
    }
    if (_listingsError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pageGutter),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: AppColors.danger,
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                _listingsError!,
                textAlign: TextAlign.center,
                style: AppTypography.body,
              ),
              const SizedBox(height: AppSpacing.s12),
              PrimaryButton(label: 'Thử lại', onPressed: _loadListings),
            ],
          ),
        ),
      );
    }
    if (_listings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pageGutter),
          child: Text(
            'Chưa có bất động sản nào phụ trách trong danh sách.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: (_listings.length + 1) ~/ 2,
      itemBuilder: (context, row) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var col = 0; col < 2; col++) ...[
              if (col == 1) const SizedBox(width: 8),
              Expanded(
                child: row * 2 + col >= _listings.length
                    ? const SizedBox()
                    : PropertyCard(
                        property: _listings[row * 2 + col],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PropertyDetailPage(
                              propertyId: _listings[row * 2 + col].id,
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConsultantSupportSheetBody extends StatefulWidget {
  const _ConsultantSupportSheetBody({
    required this.consultantId,
    required this.initialName,
    required this.initialPhone,
    required this.onSuccess,
  });

  final String consultantId;
  final String initialName;
  final String initialPhone;
  final void Function(String) onSuccess;

  @override
  State<_ConsultantSupportSheetBody> createState() =>
      _ConsultantSupportSheetBodyState();
}

class _ConsultantSupportSheetBodyState
    extends State<_ConsultantSupportSheetBody> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _messageController;
  bool _consent = false;
  bool _isSubmitting = false;
  String? _errorText;
  String? _activeKey;
  String? _lastPayloadSignature;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhone);
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final msg = _messageController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      setState(() {
        _errorText = 'Vui lòng điền đủ họ tên và số điện thoại.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final payloadSignature = '$name|$phone|$msg|$_consent';
    if (_lastPayloadSignature != payloadSignature || _activeKey == null) {
      _lastPayloadSignature = payloadSignature;
      _activeKey =
          'supp-cons-${widget.consultantId}-${DateTime.now().millisecondsSinceEpoch}';
    }

    final deps = DependenciesScope.of(context);
    try {
      final input = SupportRequestInput(
        kind: SupportKind.consultantAppointment,
        consultantId: widget.consultantId,
        message: msg.isEmpty
            ? 'Yêu cầu tư vấn trực tiếp từ trang cá nhân chuyên viên'
            : msg,
        contactName: name,
        contactPhone: phone,
        consentToShareContact: _consent,
      );

      final res = await deps.support.submit(input, idempotencyKey: _activeKey!);

      if (!mounted) return;
      widget.onSuccess(res.notice);
    } on XlandFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = e.message;
        _isSubmitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Lỗi gửi yêu cầu: $e';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pageGutter,
        AppSpacing.s20,
        AppSpacing.pageGutter,
        AppSpacing.s24 + bottomInset,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.sheetTopRadius,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            Text('Đặt lịch & Yêu cầu hỗ trợ', style: AppTypography.sheetTitle),
            const SizedBox(height: AppSpacing.s8),
            const InfoNotice(
              title: 'Phiếu hỗ trợ chuyên viên',
              message: 'Yêu cầu sẽ được tạo dưới dạng phiếu hỗ trợ (ticket). Chuyên viên sẽ liên hệ lại qua điện thoại, không phải tin nhắn tức thời.',
              variant: NoticeVariant.info,
            ),
            const SizedBox(height: AppSpacing.s16),
            XLandTextField(
              label: 'Họ và tên',
              controller: _nameController,
              hint: 'Nguyễn Văn A',
            ),
            const SizedBox(height: AppSpacing.s12),
            XLandTextField(
              label: 'Số điện thoại',
              controller: _phoneController,
              hint: '0901234567',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppSpacing.s12),
            XLandTextField(
              label: 'Nhu cầu hoặc câu hỏi tư vấn',
              controller: _messageController,
              hint: 'Tôi cần tìm hiểu thêm về quy hoạch và pháp lý khu vực...',
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.s12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _consent,
                  activeColor: AppColors.brandPrimary,
                  onChanged: (val) {
                    setState(() => _consent = val ?? false);
                  },
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _consent = !_consent);
                    },
                    child: const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Tôi đồng ý chia sẻ thông tin liên hệ với tư vấn viên để phục vụ việc hỗ trợ thực địa và pháp lý (Bắt buộc).',
                        style: AppTypography.compact,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_errorText != null) ...[
              const SizedBox(height: AppSpacing.s8),
              Text(
                _errorText!,
                style: AppTypography.compact.copyWith(color: AppColors.danger),
              ),
            ],
            const SizedBox(height: AppSpacing.s16),
            PrimaryButton(
              label: _isSubmitting
                  ? 'Đang gửi yêu cầu...'
                  : 'Gửi phiếu yêu cầu',
              isSubmitting: _isSubmitting,
              onPressed: (!_consent || _isSubmitting) ? null : _handleSubmit,
            ),
          ],
        ),
      ),
    );
  }
}
