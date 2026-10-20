import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/xland_domain.dart';
import '../../../shared/di/dependencies_scope.dart';
import '../../../shared/utils/timezone_utils.dart';
import '../../../shared/utils/value_formatters.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../shared/widgets/design_widgets.dart';
import '../../../theme/theme.dart';
import '../../../shared/widgets/illustrative_image.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import '../../auth/widgets/login_prompt_sheet.dart';

/// S07 Event Detail & Registration Page.
/// Features:
/// - Event overview: banner, title, tags, venue, duration, remaining capacity
/// - Agenda timeline, speakers, attendee benefits
/// - Bookmark / Save event (with auth gate)
/// - Capacity check & Registration sheet (with auth gate, stable retry key, lifecycle guards)
/// - PaymentMode notice (no fake paid/confirmed tickets when payment is disabled)
class EventDetailPage extends StatefulWidget {
  const EventDetailPage({super.key, required this.eventId});

  final String eventId;

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  XlandEvent? _event;
  bool _isLoading = true;
  String? _errorMessage;

  bool _isSaved = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEvent();
    });
  }

  Future<void> _loadEvent() async {
    if (!mounted) return;
    final deps = DependenciesScope.of(context);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ev = await deps.events.getEvent(widget.eventId);
      if (!mounted) return;
      setState(() {
        _event = ev;
        _isSaved = ev.isSaved;
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
        _errorMessage = 'Không thể tải thông tin sự kiện: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleSave() async {
    if (_event == null || _isSaving || !mounted) return;
    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) {
      final didLogin = await LoginPromptSheet.show(
        context,
        title: 'Đăng nhập để lưu sự kiện',
        message: 'Vui lòng đăng nhập để lưu sự kiện này vào danh sách quan tâm của bạn.',
      );
      if (!didLogin || !mounted) return;
    }

    final deps = DependenciesScope.of(context);
    final nextState = !_isSaved;

    setState(() {
      _isSaving = true;
      _isSaved = nextState;
    });

    try {
      await deps.events.setSaved(widget.eventId, nextState);
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextState ? 'Đã lưu sự kiện vào danh sách.' : 'Đã bỏ lưu sự kiện.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaved = !nextState;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể cập nhật trạng thái lưu. Vui lòng thử lại.'),
        ),
      );
    }
  }

  Future<void> _handleShare() async {
    final messenger = ScaffoldMessenger.of(context);
    final deps = DependenciesScope.of(context);
    try {
      final link = await deps.events.getShareLink(widget.eventId);
      await Clipboard.setData(ClipboardData(text: link.url.toString()));
      messenger.showSnackBar(
        SnackBar(
          content: Text('Đã sao chép liên kết chia sẻ: ${link.url}'),
          backgroundColor: AppColors.brandPrimary,
        ),
      );
    } on XlandFailure catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Không thể chia sẻ: ${e.message}'),
          backgroundColor: AppColors.danger,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Không thể tạo liên kết chia sẻ lúc này: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _showRegistrationSheet() async {
    if (_event == null || !mounted) return;
    final authState = context.read<AuthCubit>().state;
    String initialName = '';
    String initialPhone = '';

    if (authState is! AuthAuthenticated) {
      final didLogin = await LoginPromptSheet.show(
        context,
        title: 'Đăng nhập để đăng ký sự kiện',
        message:
            'Vui lòng đăng nhập để đăng ký tham gia sự kiện và nhận vé mời.',
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
        return _EventRegistrationSheetBody(
          event: _event!,
          initialName: initialName,
          initialPhone: initialPhone,
          onSuccess: (reg) {
            Navigator.of(sheetContext).pop();
            _showRegistrationSuccessDialog(reg, scaffoldMessenger);
            _loadEvent();
          },
        );
      },
    );
  }

  void _showRegistrationSuccessDialog(
    EventRegistration reg,
    ScaffoldMessengerState scaffoldMessenger,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.cardLarge),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(width: AppSpacing.s8),
              const Expanded(child: Text('Đăng ký thành công')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mã đăng ký: #${reg.id}',
                style: AppTypography.compactStrong,
              ),
              const SizedBox(height: AppSpacing.s8),
              StatusBadge(
                text: reg.status == RegistrationStatus.registered
                    ? 'Đã ghi nhận'
                    : 'Chờ xác nhận',
                variant: StatusBadgeVariant.verified,
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(reg.notice, style: AppTypography.body),
              const SizedBox(height: AppSpacing.s12),
              if (reg.paymentMode == PaymentMode.disabled)
                const InfoNotice(
                  title: 'Chính sách thanh toán',
                  message: 'Cổng thanh toán vé sự kiện hiện chưa kích hoạt. Đăng ký của bạn được ghi nhận vào danh sách tham dự miễn thu phí trước.',
                  variant: NoticeVariant.info,
                ),
            ],
          ),
          actions: [
            PrimaryButton(
              label: 'Đóng',
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const XLandScaffold(
        appBar: XLandAppBar(
          title: 'Sự kiện',
          variant: XLandAppBarVariant.light,
        ),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.brandPrimary),
        ),
      );
    }

    if (_errorMessage != null || _event == null) {
      return XLandScaffold(
        appBar: const XLandAppBar(
          title: 'Sự kiện',
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
                  _errorMessage ?? 'Không tìm thấy sự kiện.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body,
                ),
                const SizedBox(height: AppSpacing.s16),
                PrimaryButton(label: 'Thử lại', onPressed: _loadEvent),
              ],
            ),
          ),
        ),
      );
    }

    final ev = _event!;
    final isSoldOut =
        ev.remainingSlots <= 0 || ev.status == EventStatus.soldOut;
    final isClosed =
        ev.status == EventStatus.closed || ev.status == EventStatus.cancelled;
    final canRegister =
        !isSoldOut && !isClosed && ev.status == EventStatus.open;

    return XLandScaffold(
      appBar: XLandAppBar(
        title: ev.venueName.toLowerCase().contains('coffee')
            ? 'Sự kiện X Coffee'
            : 'Sự kiện XLand',
        showBack: true,
        variant: XLandAppBarVariant.light,
        actions: [
          const XLandLogo(height: 23),
          IconActionButton(
            icon: Icons.share_outlined,
            semanticLabel: 'Chia sẻ sự kiện',
            onPressed: _handleShare,
          ),
        ],
      ),
      stickyFooter: StickyActionBar(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Vé tham dự', style: AppTypography.compact),
                  Text(
                    ev.ticketPriceVnd.amount == BigInt.zero
                        ? 'Miễn phí'
                        : formatVndAmount(ev.ticketPriceVnd),
                    style: AppTypography.priceCard.copyWith(fontSize: 20),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: PrimaryButton(
                label: canRegister
                    ? 'Đăng ký tham dự'
                    : isSoldOut
                    ? 'Đã hết chỗ'
                    : 'Đã kết thúc',
                icon: const Icon(Icons.arrow_forward_ios, size: 17),
                onPressed: canRegister ? _showRegistrationSheet : null,
              ),
            ),
            IconButton(
              tooltip: _isSaved ? 'Đã lưu sự kiện' : 'Lưu sự kiện',
              onPressed: _toggleSave,
              icon: Icon(
                _isSaved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_outline_rounded,
                color: AppColors.brandPrimary,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2.1,
              child: XLandMediaImage(
                url: ev.media.isEmpty
                    ? null
                    : ev.media.first.thumbnailUrl ??
                          (ev.media.first.kind == MediaKind.image
                              ? ev.media.first.url
                              : null),
                isIllustrative: ev.isIllustrative,
                illustrativeAsset: IllustrativeAssets.coffee,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in ev.tags)
                        StatusBadge(
                          text: tag,
                          variant: StatusBadgeVariant.source,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    ev.title,
                    style: AppTypography.pageHero.copyWith(
                      color: AppColors.brandPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.calendar_today_outlined,
                    'Thời gian',
                    formatBusinessDateTime(ev.startsAt, ev.timeZone),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    Icons.location_on_outlined,
                    ev.venueName,
                    ev.address,
                  ),
                  const SizedBox(height: 16),
                  XLandCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _eventMetric(
                          Icons.people_outline,
                          '${ev.remainingSlots}/${ev.maxSlots} chỗ',
                          'Chỗ còn lại',
                        ),
                        _eventMetric(
                          Icons.schedule_outlined,
                          '${ev.durationMinutes} phút',
                          'Thời lượng',
                        ),
                        _eventMetric(
                          Icons.chat_bubble_outline,
                          'Hỏi đáp',
                          'Cùng chuyên gia',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (ev.agenda.isNotEmpty) ...[
                    const DesignSectionTitle(
                      'Nội dung chương trình',
                      icon: Icons.format_list_bulleted,
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < ev.agenda.length; i++)
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 20,
                              child: Column(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(top: 6),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.goldDecorative,
                                    ),
                                  ),
                                  if (i < ev.agenda.length - 1)
                                    const Expanded(
                                      child: VerticalDivider(
                                        width: 1,
                                        color: AppColors.border,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 52,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  '${toBusinessTime(ev.agenda[i].startsAt, ev.timeZone).hour.toString().padLeft(2, '0')}:${toBusinessTime(ev.agenda[i].startsAt, ev.timeZone).minute.toString().padLeft(2, '0')}',
                                  style: AppTypography.body,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ev.agenda[i].title,
                                      style: AppTypography.bodyStrong,
                                    ),
                                    if (ev.agenda[i].description != null)
                                      Text(
                                        ev.agenda[i].description!,
                                        style: AppTypography.compact,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  if (ev.speakers.isNotEmpty) ...[
                    const DesignSectionTitle(
                      'Diễn giả',
                      icon: Icons.record_voice_over_outlined,
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final speaker in ev.speakers)
                            SizedBox(
                              width: (constraints.maxWidth - 8) / 2,
                              child: XLandCard(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: 56,
                                      width: 56,
                                      child: ClipOval(
                                        child: speaker.avatarUrl == null
                                            ? const ColoredBox(
                                                color:
                                                    AppColors.verifiedSurface,
                                                child: Icon(
                                                  Icons.person_outline,
                                                  color: AppColors.brandPrimary,
                                                  size: 30,
                                                ),
                                              )
                                            : XLandMediaImage(
                                                url: speaker.avatarUrl,
                                                showLabel: false,
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      speaker.name,
                                      style: AppTypography.bodyStrong,
                                    ),
                                    Text(
                                      speaker.role,
                                      style: AppTypography.compact,
                                    ),
                                    if (speaker.description != null)
                                      Text(
                                        speaker.description!,
                                        style: AppTypography.compact,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (ev.benefits.isNotEmpty) ...[
                    const DesignSectionTitle(
                      'Bạn sẽ nhận được',
                      icon: Icons.card_giftcard_outlined,
                    ),
                    const SizedBox(height: 10),
                    for (final benefit in ev.benefits)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: XLandCard(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                color: AppColors.goldDecorative,
                                size: 23,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      benefit.title,
                                      style: AppTypography.bodyStrong,
                                    ),
                                    Text(
                                      benefit.description,
                                      style: AppTypography.compact,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventMetric(IconData icon, String value, String label) => Expanded(
    child: Column(
      children: [
        Icon(icon, size: 24, color: AppColors.goldDecorative),
        const SizedBox(height: 5),
        Text(
          value,
          style: AppTypography.bodyStrong,
          textAlign: TextAlign.center,
        ),
        Text(label, style: AppTypography.compact, textAlign: TextAlign.center),
      ],
    ),
  );

  Widget _buildDetailRow(IconData icon, String title, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 22, color: AppColors.brandPrimary),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.bodyStrong),
            Text(value, style: AppTypography.body),
          ],
        ),
      ),
    ],
  );
}

class _EventRegistrationSheetBody extends StatefulWidget {
  const _EventRegistrationSheetBody({
    required this.event,
    required this.initialName,
    required this.initialPhone,
    required this.onSuccess,
  });

  final XlandEvent event;
  final String initialName;
  final String initialPhone;
  final void Function(EventRegistration) onSuccess;

  @override
  State<_EventRegistrationSheetBody> createState() =>
      _EventRegistrationSheetBodyState();
}

class _EventRegistrationSheetBodyState
    extends State<_EventRegistrationSheetBody> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  int _attendees = 1;
  bool _isSubmitting = false;
  String? _submitError;
  String? _activeKey;
  String? _lastPayloadSignature;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      setState(() {
        _submitError = 'Vui lòng điền đủ họ tên và số điện thoại.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    final payloadSignature = '$name|$phone|$_attendees';
    if (_lastPayloadSignature != payloadSignature || _activeKey == null) {
      _lastPayloadSignature = payloadSignature;
      _activeKey =
          'reg-ev-${widget.event.id}-${DateTime.now().millisecondsSinceEpoch}';
    }

    final deps = DependenciesScope.of(context);
    try {
      final input = EventRegistrationInput(
        eventId: widget.event.id,
        contactName: name,
        contactPhone: phone,
        attendeeCount: _attendees,
      );

      final registration = await deps.events.register(
        input,
        idempotencyKey: _activeKey!,
      );

      if (!mounted) return;
      widget.onSuccess(registration);
    } on XlandFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = e.message;
        _isSubmitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = 'Lỗi đăng ký: $e';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxCanRegister = widget.event.remainingSlots < 5
        ? widget.event.remainingSlots
        : 5;

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
            Text('Đăng ký tham gia sự kiện', style: AppTypography.sheetTitle),
            const SizedBox(height: AppSpacing.s4),
            Text(
              widget.event.title,
              style: AppTypography.cardTitle.copyWith(
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            InfoNotice(
              title: 'Thông tin chỗ',
              message:
                  'Còn ${widget.event.remainingSlots} / ${widget.event.maxSlots} suất tham dự.',
              variant: NoticeVariant.info,
            ),
            const SizedBox(height: AppSpacing.s16),
            XLandTextField(
              label: 'Họ và tên người đăng ký',
              controller: _nameController,
              hint: 'Nguyễn Văn A',
            ),
            const SizedBox(height: AppSpacing.s12),
            XLandTextField(
              label: 'Số điện thoại liên hệ',
              controller: _phoneController,
              hint: '0901234567',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppSpacing.s16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Số lượng người tham gia:',
                  style: AppTypography.bodyStrong,
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                      onPressed: _attendees > 1
                          ? () => setState(() => _attendees--)
                          : null,
                    ),
                    Text('$_attendees', style: AppTypography.cardTitle),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      onPressed: _attendees < maxCanRegister
                          ? () => setState(() => _attendees++)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
            if (_submitError != null) ...[
              const SizedBox(height: AppSpacing.s8),
              Text(
                _submitError!,
                style: AppTypography.compact.copyWith(color: AppColors.danger),
              ),
            ],
            const SizedBox(height: AppSpacing.s20),
            PrimaryButton(
              label: _isSubmitting
                  ? 'Đang xử lý đăng ký...'
                  : 'Xác nhận đăng ký',
              isSubmitting: _isSubmitting,
              onPressed: _isSubmitting ? null : _handleSubmit,
            ),
          ],
        ),
      ),
    );
  }
}
