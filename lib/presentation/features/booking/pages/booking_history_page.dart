import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/xland_domain.dart';
import '../../../shared/di/dependencies_scope.dart';
import '../../../shared/utils/timezone_utils.dart';
import '../../../shared/utils/value_formatters.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/theme.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import '../../auth/pages/login_page.dart';
import 'booking_detail_page.dart';

/// Màn hình Lịch sử đặt lịch thực địa riêng biệt.
/// Hiển thị danh sách các lịch hẹn khảo sát thực địa của người dùng,
/// trạng thái cọc, chi tiết lịch hẹn và hỗ trợ tải thêm phân trang.
class BookingHistoryPage extends StatefulWidget {
  const BookingHistoryPage({super.key});

  @override
  State<BookingHistoryPage> createState() => _BookingHistoryPageState();
}

class _BookingHistoryPageState extends State<BookingHistoryPage> {
  final ScrollController _scrollController = ScrollController();
  List<Booking> _bookings = [];
  String? _nextCursor;
  bool _hasMore = false;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _epoch = 0;
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadInitial();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadInitial({bool silent = false}) async {
    final deps = DependenciesScope.maybeOf(context);
    if (deps == null) return;

    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _bookings.clear();
          _errorMessage = null;
        });
      }
      return;
    }

    final userId = authState.session.profile.id;
    _lastUserId = userId;
    final currentEpoch = ++_epoch;

    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final page = await deps.bookings.getHistory(const PageQuery(limit: 10));
      if (!mounted || currentEpoch != _epoch || userId != _lastUserId) return;
      setState(() {
        _bookings = List.of(page.items);
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
        _isLoading = false;
        _errorMessage = null;
      });
    } on XlandFailure catch (e) {
      if (!mounted || currentEpoch != _epoch || userId != _lastUserId) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || currentEpoch != _epoch || userId != _lastUserId) return;
      setState(() {
        _errorMessage = 'Không thể tải lịch sử: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    final deps = DependenciesScope.maybeOf(context);
    if (deps == null) return;

    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) return;

    final userId = authState.session.profile.id;
    final currentEpoch = _epoch;

    setState(() => _isLoadingMore = true);
    try {
      final page = await deps.bookings.getHistory(
        PageQuery(cursor: _nextCursor, limit: 10),
      );
      if (!mounted || currentEpoch != _epoch || userId != _lastUserId) return;
      final existingIds = _bookings.map((b) => b.id).toSet();
      final newItems =
          page.items.where((b) => !existingIds.contains(b.id)).toList();
      setState(() {
        _bookings.addAll(newItems);
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted || currentEpoch != _epoch || userId != _lastUserId) return;
      setState(() => _isLoadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể tải thêm lịch hẹn: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, authState) {
        final currentUserId =
            authState is AuthAuthenticated ? authState.session.profile.id : null;
        if (currentUserId != _lastUserId) {
          _loadInitial();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: const XLandAppBar(
          variant: XLandAppBarVariant.light,
          title: 'Lịch sử đặt lịch thực địa',
          showBack: true,
        ),
        body: SafeArea(
          child: BlocBuilder<AuthCubit, AuthState>(
            builder: (context, authState) {
              if (authState is! AuthAuthenticated) {
                return _buildGuestNotice();
              }
              return _buildBookingsContent();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGuestNotice() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.pageGutter),
      child: XLandCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const InfoNotice(
              title: 'Tài khoản khách',
              message:
                  'Vui lòng đăng nhập để xem danh sách lịch hẹn khảo sát thực địa của bạn.',
              variant: NoticeVariant.info,
            ),
            const SizedBox(height: AppSpacing.s16),
            PrimaryButton(
              label: 'Đăng nhập ngay',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const LoginPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingsContent() {
    if (_isLoading && _bookings.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.s32),
          child: CircularProgressIndicator(color: AppColors.brandPrimary),
        ),
      );
    }

    if (_errorMessage != null && _bookings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pageGutter),
          child: Container(
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
                    _errorMessage!,
                    style:
                        AppTypography.compact.copyWith(color: AppColors.danger),
                  ),
                ),
                TextButton(
                  onPressed: () => _loadInitial(),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_bookings.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => RefreshIndicator(
          color: AppColors.brandPrimary,
          onRefresh: () => _loadInitial(silent: true),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.pageGutter),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: AppColors.verifiedSurface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.calendar_today_outlined,
                          size: 36,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      Text(
                        'Bạn chưa có lịch hẹn thực địa nào.',
                        style: AppTypography.cardTitle,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      Text(
                        'Đặt lịch khảo sát trên chi tiết bất động sản để trải nghiệm thực tế.',
                        style: AppTypography.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.brandPrimary,
      onRefresh: () => _loadInitial(silent: true),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.pageGutter),
        itemCount: _bookings.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _bookings.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _isLoadingMore
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.brandPrimary,
                      ),
                    )
                  : OutlineButton(
                      label: 'Tải thêm lịch hẹn',
                      onPressed: _loadMore,
                    ),
            );
          }

          final b = _bookings[index];
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
                            if (mounted) _loadInitial(silent: true);
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
