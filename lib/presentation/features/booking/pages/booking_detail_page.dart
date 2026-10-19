import 'package:flutter/material.dart';
import '../../../../domain/xland_domain.dart';
import '../../../shared/di/dependencies_scope.dart';
import '../../../shared/utils/timezone_utils.dart';
import '../../../shared/utils/value_formatters.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/theme.dart';
import '../../property_detail/pages/property_detail_page.dart';

/// S06 Booking Detail Page.
/// Features:
/// - Real booking detail loaded by bookingId via BookingRepository.getBooking
/// - Display booking ID, actual status, payment status
/// - Property info with navigation to PropertyDetailPage
/// - Timezone-aware requested / confirmed schedule
/// - Meeting area & contact details
/// - Cancellation & Reschedule requests if available in availableActions
class BookingDetailPage extends StatefulWidget {
  const BookingDetailPage({
    super.key,
    required this.bookingId,
  });

  final String bookingId;

  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
  Booking? _booking;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBooking();
    });
  }

  Future<void> _loadBooking() async {
    if (!mounted) return;
    final deps = DependenciesScope.of(context);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final b = await deps.bookings.getBooking(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _booking = b;
        _isLoading = false;
      });
    } on XlandFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không thể tải thông tin đặt lịch: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const XLandScaffold(
        appBar: XLandAppBar(title: 'Chi tiết lịch hẹn', variant: XLandAppBarVariant.light),
        body: Center(child: CircularProgressIndicator(color: AppColors.brandPrimary)),
      );
    }

    if (_errorMessage != null || _booking == null) {
      return XLandScaffold(
        appBar: const XLandAppBar(title: 'Chi tiết lịch hẹn', variant: XLandAppBarVariant.light),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.pageGutter),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
                const SizedBox(height: AppSpacing.s12),
                Text(
                  _errorMessage ?? 'Không tìm thấy thông tin lịch hẹn.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body,
                ),
                const SizedBox(height: AppSpacing.s16),
                PrimaryButton(label: 'Thử lại', onPressed: _loadBooking),
              ],
            ),
          ),
        ),
      );
    }

    final b = _booking!;
    final statusText = switch (b.status) {
      BookingStatus.draft => 'Bản nháp',
      BookingStatus.awaitingDeposit => 'Chờ đặt cọc',
      BookingStatus.pendingConfirmation => 'Chờ xác nhận',
      BookingStatus.confirmed => 'Đã xác nhận',
      BookingStatus.completed => 'Đã hoàn thành',
      BookingStatus.cancelRequested => 'Chờ hủy',
      BookingStatus.cancelled => 'Đã hủy',
      BookingStatus.rescheduleRequested => 'Chờ đổi lịch',
      BookingStatus.expired => 'Đã hết hạn',
      BookingStatus.rejected => 'Từ chối',
      BookingStatus.noShow => 'Vắng mặt',
    };
    final statusVariant = switch (b.status) {
      BookingStatus.confirmed || BookingStatus.completed => StatusBadgeVariant.verified,
      BookingStatus.cancelled ||
      BookingStatus.rejected ||
      BookingStatus.expired ||
      BookingStatus.noShow =>
        StatusBadgeVariant.danger,
      _ => StatusBadgeVariant.pending,
    };

    final paymentText = switch (b.paymentStatus) {
      PaymentStatus.succeeded => 'Đã đặt cọc',
      PaymentStatus.unpaid => 'Chưa thanh toán cọc',
      PaymentStatus.refunded => 'Đã hoàn cọc',
      PaymentStatus.refundPending => 'Đang xử lý hoàn cọc',
      PaymentStatus.pending => 'Đang xử lý cọc',
      PaymentStatus.failed => 'Thanh toán cọc thất bại',
      PaymentStatus.expired => 'Hết hạn cọc',
      PaymentStatus.needsReview => 'Cần rà soát cọc',
    };
    final paymentVariant = switch (b.paymentStatus) {
      PaymentStatus.succeeded => StatusBadgeVariant.verified,
      PaymentStatus.refunded || PaymentStatus.refundPending => StatusBadgeVariant.sale,
      PaymentStatus.failed || PaymentStatus.expired => StatusBadgeVariant.danger,
      _ => StatusBadgeVariant.pending,
    };

    final time = b.confirmedStartsAt ?? b.requestedStartsAt;
    final timeStr = formatBusinessSchedule(time, b.timeZone);

    return XLandScaffold(
      appBar: XLandAppBar(
        title: 'Lịch hẹn #${formatResourceReference(b.id)}',
        variant: XLandAppBarVariant.light,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pageGutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            XLandCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Tooltip(message:b.id,child:Text('Mã lịch hẹn: #${formatResourceReference(b.id)}', style: AppTypography.compactStrong)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      StatusBadge(text: statusText, variant: statusVariant),
                      StatusBadge(text: paymentText, variant: paymentVariant),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s16),

            // Property Info Card
            if(!b.depositPolicy.livePaymentEnabled) ...[
              const InfoNotice(title:'Thanh toán tiền cọc',
                message:'Thanh toán tạm thời còn thiếu, sẽ bổ sung sau. Lịch hẹn chưa được xác nhận chỉ từ thông tin tiền cọc dự kiến.',
                variant:NoticeVariant.info),
              const SizedBox(height:AppSpacing.s16),
            ],
            XLandCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bất động sản khảo sát', style: AppTypography.sectionTitle),
                  const SizedBox(height: AppSpacing.s8),
                  Text(b.property.title, style: AppTypography.cardTitle),
                  const SizedBox(height: 4),
                  Text('Mã lô: ${b.property.code}', style: AppTypography.compact),
                  const SizedBox(height: AppSpacing.s12),
                  OutlineButton(
                    label: 'Xem thông tin bất động sản',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PropertyDetailPage(propertyId: b.propertyId),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s16),

            // Schedule & Location
            XLandCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Thời gian & Địa điểm', style: AppTypography.sectionTitle),
                  const SizedBox(height: AppSpacing.s12),
                  Text('Thời gian',style:AppTypography.compact.copyWith(color:AppColors.textSecondary)),
                  const SizedBox(height:AppSpacing.s4),
                  Text(timeStr.replaceAll(' (${b.timeZone})',''),style:AppTypography.bodyStrong),
                  const SizedBox(height:AppSpacing.s4),
                  Text(b.timeZone=='Asia/Ho_Chi_Minh'?'Giờ Việt Nam (GMT+7)':b.timeZone,style:AppTypography.compact),
                  const Divider(height: AppSpacing.s16),
                  _buildRow(
                    'Điểm đón / hẹn',
                    b.confirmedMeetingLabel ?? b.proposedMeetingArea.label,
                  ),
                  const Divider(height: AppSpacing.s16),
                  _buildRow('Số lượng khách', '${b.attendeeCount} người'),
                  const Divider(height: AppSpacing.s16),
                  _buildRow(
                    'Phương tiện',
                    b.transportMode == TransportMode.selfArranged
                        ? 'Tự túc phương tiện'
                        : 'Xe đưa đón XLand',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s16),

            // Contact & Special Requests
            XLandCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Thông tin liên hệ & Yêu cầu', style: AppTypography.sectionTitle),
                  const SizedBox(height: AppSpacing.s12),
                  _buildRow('Họ và tên', b.contactName),
                  const Divider(height: AppSpacing.s16),
                  _buildRow('Số điện thoại', b.maskedContactPhone),
                  const Divider(height: AppSpacing.s16),
                  _buildRow(
                    'Tài liệu pháp lý',
                    b.requestDocuments ? 'Yêu cầu chuẩn bị hồ sơ' : 'Không yêu cầu',
                  ),
                  const Divider(height: AppSpacing.s16),
                  _buildRow(
                    'Tư vấn tài chính',
                    b.requestLoanAdvice ? 'Cần chuyên viên tài chính hỗ trợ' : 'Không yêu cầu',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s24),

            // Actions
            if (b.availableActions.contains('cancel')) ...[
              OutlineButton(
                label: 'Hủy lịch hẹn khảo sát',
                onPressed: () => _handleCancel(context, b),
              ),
              const SizedBox(height: AppSpacing.s8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: AppTypography.compact.copyWith(color: AppColors.textSecondary)),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          flex: 3,
          child: Text(value, style: AppTypography.bodyStrong, textAlign: TextAlign.right),
        ),
      ],
    );
  }

  Future<void> _handleCancel(BuildContext context, Booking booking) async {
    final deps = DependenciesScope.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận hủy lịch'),
        content: const Text('Bạn có chắc chắn muốn hủy lịch hẹn khảo sát thực địa này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
          PrimaryButton(
            label: 'Đồng ý hủy',
            fullWidth: false,
            height: 36,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await deps.bookings.requestCancellation(
        booking.id,
        const BookingChangeInput(reason: 'Người dùng hủy qua ứng dụng'),
        idempotencyKey: 'cancel-${booking.id}-${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Đã gửi yêu cầu hủy lịch hẹn.')),
      );
      _loadBooking();
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Không thể hủy lịch: $e')),
      );
    }
  }
}
