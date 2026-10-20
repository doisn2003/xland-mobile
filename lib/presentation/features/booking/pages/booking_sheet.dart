import 'package:flutter/material.dart';

import '../../../shared/utils/value_formatters.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/xland_domain.dart';
import '../../../shared/di/dependencies_scope.dart';
import '../../../shared/utils/timezone_utils.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../shared/widgets/design_widgets.dart';
import '../../../theme/theme.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import '../../auth/widgets/login_prompt_sheet.dart';

/// S08 Field Viewing Booking Flow Sheet.
/// Features:
/// - Step 0: Input form (slot, date, contact info, attendees, transport mode, loan/doc options)
/// - Step 1: Review Step with Deposit Policy (indicative 350.000 VNĐ, live payment disabled notice)
/// - Submit Gate: Guest can fill form; login prompted at submit time.
///   If login cancelled/backed out, returns to review step retaining all inputs.
/// - Stable idempotency key per booking session; handles slotUnavailable / conflict.
/// - Does not invent payment/refund rules; uses repository DepositPolicy.
class BookingSheet extends StatefulWidget {
  const BookingSheet({super.key, required this.propertyId, this.property});

  final String propertyId;
  final Property? property;

  static Future<bool?> show(
    BuildContext context, {
    required String propertyId,
    Property? property,
  }) {
    return showXLandBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookingSheet(propertyId: propertyId, property: property),
    );
  }

  @override
  State<BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<BookingSheet> {
  int _currentStep = 0; // 0: Form, 1: Review, 2: Success
  bool _isLoadingInitial = true;
  String? _initialError;

  Property? _property;
  DepositPolicy? _depositPolicy;
  List<AvailabilitySlot> _slots = [];
  AvailabilitySlot? _selectedSlot;

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  final TextEditingController _noteController = TextEditingController();

  int _attendeeCount = 1;
  TransportMode _transportMode = TransportMode.selfArranged;
  bool _requestDocuments = false;
  bool _requestLoanAdvice = false;

  bool _isSubmitting = false;
  String? _submitError;
  String? _idempotencyKey;
  String? _lastPayloadSig;
  Booking? _confirmedBooking;

  @override
  void initState() {
    super.initState();
    _property = widget.property;
    final auth = context.read<AuthCubit>().state;
    String initName = '';
    String initPhone = '';
    if (auth is AuthAuthenticated) {
      initName = auth.session.profile.displayName;
      initPhone = auth.session.profile.contactPhone ?? '';
    }
    _nameController = TextEditingController(text: initName);
    _phoneController = TextEditingController(text: initPhone);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    final deps = DependenciesScope.of(context);
    setState(() {
      _isLoadingInitial = true;
      _initialError = null;
    });

    try {
      final now = DateTime.now();
      final fromStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final to = now.add(const Duration(days: 30));
      final toStr =
          '${to.year}-${to.month.toString().padLeft(2, '0')}-${to.day.toString().padLeft(2, '0')}';

      Property? prop = _property;
      if (prop == null) {
        try {
          prop = await deps.properties.getProperty(widget.propertyId);
        } catch (_) {}
      }

      final results = await Future.wait([
        deps.bookings.getDepositPolicy(),
        deps.bookings.getAvailability(widget.propertyId, fromStr, toStr),
      ]);

      if (!mounted) return;
      final policy = results[0] as DepositPolicy;
      final slots = results[1] as List<AvailabilitySlot>;

      setState(() {
        _property = prop;
        _depositPolicy = policy;
        _slots = slots;
        _selectedSlot = slots.where((s) => s.isAvailable).firstOrNull;
        if (_selectedSlot != null) {
          _attendeeCount = _attendeeCount.clamp(1, _selectedSlot!.maxAttendees);
        }
        _isLoadingInitial = false;
      });
    } on XlandFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _initialError = e.message;
        _isLoadingInitial = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initialError = 'Không thể tải lịch khả dụng: $e';
        _isLoadingInitial = false;
      });
    }
  }

  void _proceedToReview() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn một khung giờ khả dụng.')),
      );
      return;
    }
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng điền đủ họ tên và số điện thoại liên hệ.'),
        ),
      );
      return;
    }
    setState(() {
      _currentStep = 1;
      _submitError = null;
    });
  }

  Future<void> _handleConfirmSubmit() async {
    if (_selectedSlot == null || _isSubmitting || !mounted) return;
    final deps = DependenciesScope.of(context);

    // 1. Submit-time auth gate (P2-010/P2-012): Guest is prompted, if cancel returns to review step!
    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) {
      final didLogin = await LoginPromptSheet.show(
        context,
        title: 'Đăng nhập để xác nhận đặt lịch',
        message: 'Vui lòng đăng nhập để lưu trữ và theo dõi lịch hẹn thực địa trong hồ sơ của bạn.',
      );
      if (!didLogin || !mounted) {
        // User cancelled login -> retain input and stay on review step!
        return;
      }
      // P2-012: Guest login completed. Return to review with 0 POST!
      // User must explicitly click "Xác nhận đặt lịch" again.
      setState(() {
        _currentStep = 1;
      });
      return;
    }

    // 2. Stable idempotency key per logical payload: retries keep key, changed payload creates new key
    final payloadSig =
        '${widget.propertyId}-${_selectedSlot!.id}-$_attendeeCount-$_transportMode-$_requestDocuments-$_requestLoanAdvice-${_nameController.text.trim()}-${_phoneController.text.trim()}-${_noteController.text.trim()}';
    if (_lastPayloadSig != payloadSig || _idempotencyKey == null) {
      _lastPayloadSig = payloadSig;
      _idempotencyKey =
          'bk-${widget.propertyId}-${DateTime.now().millisecondsSinceEpoch}';
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final input = BookingInput(
        propertyId: widget.propertyId,
        slotId: _selectedSlot!.id,
        attendeeCount: _attendeeCount,
        transportMode: _transportMode,
        requestDocuments: _requestDocuments,
        requestLoanAdvice: _requestLoanAdvice,
        contactName: _nameController.text.trim(),
        contactPhone: _phoneController.text.trim(),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      final booking = await deps.bookings.create(
        input,
        idempotencyKey: _idempotencyKey!,
      );
      if (!mounted) return;
      setState(() {
        _confirmedBooking = booking;
        _isSubmitting = false;
        _currentStep = 2; // Success
      });
    } on XlandFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = e.message;
        _isSubmitting = false;
      });
      if (e.code == FailureCode.slotUnavailable) {
        // Refresh slot data while keeping user inputs
        _loadData();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = 'Lỗi tạo lịch hẹn: $e';
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
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: _isLoadingInitial
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.s32),
                child: CircularProgressIndicator(color: AppColors.brandPrimary),
              ),
            )
          : _initialError != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 40,
                    color: AppColors.danger,
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  Text(
                    _initialError!,
                    style: AppTypography.body,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  PrimaryButton(label: 'Thử lại', onPressed: _loadData),
                ],
              ),
            )
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
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

          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0)
                  const Expanded(child: Divider(color: AppColors.border)),
                Column(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: i == _currentStep
                          ? AppColors.brandPrimary
                          : AppColors.disabledSurface,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: i == _currentStep
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      ['Chọn lịch', 'Xác nhận', 'Thực địa'][i],
                      style: AppTypography.compact,
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (_currentStep == 0) _buildFormStep(),
          if (_currentStep == 1) _buildReviewStep(),
          if (_currentStep == 2) _buildSuccessStep(),
        ],
      ),
    );
  }

  /// Step 0: Input Form
  Widget _buildFormStep() {
    final propTitle =
        _property?.title ??
        'Lô đất ${formatResourceReference(widget.propertyId)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Đặt lịch xem thực địa', style: AppTypography.sheetTitle),
        const SizedBox(height: AppSpacing.s4),
        if (_property != null)
          PropertySummaryStrip(property: _property!)
        else
          Text(
            propTitle,
            style: AppTypography.cardTitle.copyWith(
              color: AppColors.brandPrimary,
            ),
          ),
        const SizedBox(height: AppSpacing.s16),

        // Available Slots
        _buildDateSelector(),
        const SizedBox(height: 12),
        const DesignSectionTitle(
          'Khung giờ khảo sát',
          icon: Icons.schedule_outlined,
        ),
        const SizedBox(height: AppSpacing.s8),
        if (_slots.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Hiện chưa có lịch trống cho lô đất này.'),
          )
        else
          ..._slots
              .where(
                (slot) =>
                    _selectedSlot == null ||
                    _dayKey(slot) == _dayKey(_selectedSlot!),
              )
              .map((slot) {
                final isSel = _selectedSlot?.id == slot.id;
                final timeStr = formatSlotWithDate(
                  slot.startsAt,
                  slot.endsAt,
                  slot.timeZone,
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                  child: GestureDetector(
                    onTap: slot.isAvailable
                        ? () => setState(() {
                            _selectedSlot = slot;
                            _attendeeCount = _attendeeCount.clamp(
                              1,
                              slot.maxAttendees,
                            );
                          })
                        : null,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.s12),
                      decoration: BoxDecoration(
                        color: !slot.isAvailable
                            ? AppColors.disabledSurface
                            : isSel
                            ? AppColors.brandPrimary.withValues(alpha: 0.08)
                            : AppColors.surface,
                        border: Border.all(
                          color: isSel
                              ? AppColors.brandPrimary
                              : AppColors.border,
                          width: isSel ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSel
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: !slot.isAvailable
                                ? AppColors.textSecondary
                                : isSel
                                ? AppColors.brandPrimary
                                : AppColors.border,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  timeStr,
                                  style: AppTypography.bodyStrong.copyWith(
                                    color: slot.isAvailable
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  slot.isAvailable
                                      ? 'Điểm hẹn: ${slot.meetingArea.label}'
                                      : 'Không khả dụng: ${slot.unavailableReason ?? "Đã kín"}',
                                  style: AppTypography.compact.copyWith(
                                    color: slot.isAvailable
                                        ? AppColors.textSecondary
                                        : AppColors.danger,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

        const SizedBox(height: AppSpacing.s16),

        // Contact details
        const DesignSectionTitle(
          'Thông tin liên hệ',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: AppSpacing.s8),
        XLandTextField(
          label: 'Họ và tên người đại diện',
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
        const SizedBox(height: AppSpacing.s16),

        // Attendee count
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Số người tham gia:', style: AppTypography.bodyStrong),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  onPressed: _attendeeCount > 1
                      ? () => setState(() => _attendeeCount--)
                      : null,
                ),
                Text('$_attendeeCount', style: AppTypography.cardTitle),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  onPressed: _attendeeCount < (_selectedSlot?.maxAttendees ?? 5)
                      ? () => setState(() => _attendeeCount++)
                      : null,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),

        // Transport Mode
        const DesignSectionTitle(
          'Di chuyển',
          icon: Icons.directions_car_outlined,
        ),
        const SizedBox(height: AppSpacing.s8),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Center(child: Text('Tự túc phương tiện')),
                selected: _transportMode == TransportMode.selfArranged,
                onSelected: (sel) {
                  if (sel) {
                    setState(() => _transportMode = TransportMode.selfArranged);
                  }
                },
                selectedColor: AppColors.brandPrimary,
                labelStyle: TextStyle(
                  color: _transportMode == TransportMode.selfArranged
                      ? AppColors.onPrimary
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: ChoiceChip(
                label: const Center(child: Text('Cần xe đưa đón')),
                selected: _transportMode == TransportMode.needsAssistance,
                onSelected: (sel) {
                  if (sel) {
                    setState(
                      () => _transportMode = TransportMode.needsAssistance,
                    );
                  }
                },
                selectedColor: AppColors.brandPrimary,
                labelStyle: TextStyle(
                  color: _transportMode == TransportMode.needsAssistance
                      ? AppColors.onPrimary
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),

        // Additional options
        const DesignSectionTitle(
          'Nhu cầu trong buổi thực địa',
          icon: Icons.fact_check_outlined,
        ),
        const SizedBox(height: AppSpacing.s8),
        Row(
          children: [
            Checkbox(
              value: _requestDocuments,
              activeColor: AppColors.brandPrimary,
              onChanged: (val) =>
                  setState(() => _requestDocuments = val ?? false),
            ),
            const Expanded(
              child: Text('Mang theo hồ sơ pháp lý & trích lục bản đồ'),
            ),
          ],
        ),
        Row(
          children: [
            Checkbox(
              value: _requestLoanAdvice,
              activeColor: AppColors.brandPrimary,
              onChanged: (val) =>
                  setState(() => _requestLoanAdvice = val ?? false),
            ),
            const Expanded(
              child: Text('Cần chuyên viên tài chính tư vấn gói vay ngân hàng'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),

        XLandTextField(
          label: 'Ghi chú thêm (không bắt buộc)',
          controller: _noteController,
          hint: 'Ví dụ: Đón tại ngã tư Hòa Lạc...',
          maxLines: 2,
        ),
        const SizedBox(height: AppSpacing.s20),

        PrimaryButton(
          label: 'Xem lại thông tin đặt lịch',
          onPressed: _proceedToReview,
        ),
      ],
    );
  }

  String _dayKey(AvailabilitySlot slot) {
    final date = toBusinessTime(slot.startsAt, slot.timeZone);
    return '${date.year}-${date.month}-${date.day}';
  }

  Widget _buildDateSelector() {
    final dates = <String, AvailabilitySlot>{};
    for (final slot in _slots) {
      dates.putIfAbsent(_dayKey(slot), () => slot);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DesignSectionTitle(
          'Chọn ngày',
          icon: Icons.calendar_month_outlined,
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final entry in dates.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 68,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        backgroundColor:
                            _selectedSlot != null &&
                                _dayKey(_selectedSlot!) == entry.key
                            ? AppColors.brandPrimary
                            : AppColors.surface,
                        foregroundColor:
                            _selectedSlot != null &&
                                _dayKey(_selectedSlot!) == entry.key
                            ? Colors.white
                            : AppColors.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => setState(() {
                        _selectedSlot =
                            _slots
                                .where(
                                  (s) =>
                                      _dayKey(s) == entry.key && s.isAvailable,
                                )
                                .firstOrNull ??
                            entry.value;
                        _attendeeCount = _attendeeCount.clamp(
                          1,
                          _selectedSlot!.maxAttendees,
                        );
                      }),
                      child: Column(
                        children: [
                          Text(
                            toBusinessTime(
                                      entry.value.startsAt,
                                      entry.value.timeZone,
                                    ).weekday ==
                                    7
                                ? 'CN'
                                : 'T${toBusinessTime(entry.value.startsAt, entry.value.timeZone).weekday + 1}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            '${toBusinessTime(entry.value.startsAt, entry.value.timeZone).day}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Tháng ${toBusinessTime(entry.value.startsAt, entry.value.timeZone).month}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Step 1: Review Step
  Widget _buildReviewStep() {
    final policy = _depositPolicy;
    final slot = _selectedSlot;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => setState(() => _currentStep = 0),
            ),
            Expanded(
              child: Text(
                'Xác nhận thông tin đặt lịch',
                style: AppTypography.sheetTitle,
                maxLines: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),

        // Summary Card
        XLandCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tóm tắt lịch hẹn', style: AppTypography.sectionTitle),
              const Divider(height: AppSpacing.s16),
              _buildSummaryRow(
                'Bất động sản',
                _property?.title ??
                    widget.property?.title ??
                    'Bất động sản (Mã: ${widget.propertyId})',
              ),
              const SizedBox(height: 8),
              if (slot != null)
                _buildSummaryRow(
                  'Thời gian hẹn',
                  formatBusinessDateTime(slot.startsAt, slot.timeZone),
                ),
              const SizedBox(height: 8),
              if (slot != null)
                _buildSummaryRow('Điểm hẹn đón', slot.meetingArea.label),
              const SizedBox(height: 8),
              _buildSummaryRow('Người đại diện', _nameController.text.trim()),
              const SizedBox(height: 8),
              _buildSummaryRow('Số điện thoại', _phoneController.text.trim()),
              const SizedBox(height: 8),
              _buildSummaryRow('Số người tham gia', '$_attendeeCount người'),
              const SizedBox(height: 8),
              _buildSummaryRow(
                'Phương tiện',
                _transportMode == TransportMode.selfArranged
                    ? 'Tự túc phương tiện'
                    : 'Cần xe đưa đón của chuyên viên',
              ),
              if (_requestDocuments || _requestLoanAdvice) ...[
                const SizedBox(height: 8),
                _buildSummaryRow(
                  'Yêu cầu thêm',
                  [
                    if (_requestDocuments) 'Hồ sơ pháp lý',
                    if (_requestLoanAdvice) 'Tư vấn gói vay',
                  ].join(', '),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),

        // Deposit Policy Notice
        InfoNotice(
          title: 'Khoản cọc cam kết xem thực địa',
          message: policy != null
              ? '${policy.notice}\n• Tiền cọc dự kiến: 350.000 VNĐ. Thanh toán tạm thời còn thiếu, sẽ bổ sung sau.'
                    '${policy.refundPolicyText != null ? "\n• ${policy.refundPolicyText!}" : ""}'
                    '${policy.cancellationPolicyText != null ? "\n• ${policy.cancellationPolicyText!}" : ""}'
                    '${policy.reschedulePolicyText != null ? "\n• ${policy.reschedulePolicyText!}" : ""}'
              : 'Tiền cọc dự kiến 350.000 VNĐ. Chính sách và thanh toán tạm thời còn thiếu, sẽ bổ sung sau.',
          variant: NoticeVariant.info,
        ),

        if (_submitError != null) ...[
          const SizedBox(height: AppSpacing.s12),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.danger,
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    _submitError!,
                    style: AppTypography.compact.copyWith(
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.s20),

        PrimaryButton(
          label: _isSubmitting
              ? 'Đang xác nhận đặt lịch...'
              : 'Xác nhận đặt lịch',
          isSubmitting: _isSubmitting,
          onPressed: _isSubmitting ? null : _handleConfirmSubmit,
        ),
        const SizedBox(height: AppSpacing.s8),
        OutlineButton(
          label: 'Quay lại chỉnh sửa',
          onPressed: _isSubmitting
              ? null
              : () => setState(() => _currentStep = 0),
        ),
      ],
    );
  }

  /// Step 2: Success Step
  Widget _buildSuccessStep() {
    final b = _confirmedBooking;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: AppSpacing.s16),
        const Icon(
          Icons.check_circle_rounded,
          size: 64,
          color: AppColors.brandPrimary,
        ),
        const SizedBox(height: AppSpacing.s16),
        Text('Đặt lịch thực địa thành công!', style: AppTypography.sheetTitle),
        const SizedBox(height: AppSpacing.s8),
        Text(
          b == null
              ? 'Đang cập nhật mã lịch hẹn'
              : 'Mã lịch hẹn: #${formatResourceReference(b.id)}',
          style: AppTypography.cardTitle.copyWith(
            color: AppColors.brandPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        StatusBadge(
          text: b?.status == BookingStatus.awaitingDeposit
              ? 'Chờ đặt cọc'
              : 'Chờ xác nhận chuyên viên',
          variant: b?.status == BookingStatus.awaitingDeposit
              ? StatusBadgeVariant.sale
              : StatusBadgeVariant.pending,
        ),
        const SizedBox(height: AppSpacing.s16),
        Text(
          b?.status == BookingStatus.awaitingDeposit
              ? 'Yêu cầu của bạn đã được tiếp nhận ở trạng thái Chờ đặt cọc. Chuyên viên tư vấn phụ trách khu vực sẽ liên hệ để xác nhận thời gian và lộ trình.'
              : 'Yêu cầu đặt lịch hẹn thực địa đã được ghi nhận. Chuyên viên sẽ liên hệ để xác nhận thời gian và lộ trình khảo sát.',
          textAlign: TextAlign.center,
          style: AppTypography.body,
        ),
        const SizedBox(height: AppSpacing.s24),
        PrimaryButton(
          label: 'Đóng và xem lịch hẹn',
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: AppTypography.compact.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(child: Text(value, style: AppTypography.compactStrong)),
      ],
    );
  }
}
