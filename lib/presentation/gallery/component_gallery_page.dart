import 'package:flutter/material.dart';
import '../shared/widgets/widgets.dart';
import '../theme/theme.dart';

/// Interactive Component Gallery & Design System Harness for Phase 1.
/// Displays all tokens, widgets, states, and responsive layout behavior.
class ComponentGalleryPage extends StatefulWidget {
  const ComponentGalleryPage({
    super.key,
    this.onBack,
  });

  final VoidCallback? onBack;

  @override
  State<ComponentGalleryPage> createState() => _ComponentGalleryPageState();
}

class _ComponentGalleryPageState extends State<ComponentGalleryPage> {
  int _selectedTabIndex = 0;
  int _selectedPillIndex = 0;
  int _counterValue = 2;
  bool _isButtonSubmitting = false;

  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return XLandScaffold(
      appBar: XLandAppBar(
        showBack: true,
        onBack: widget.onBack,
        title: 'Component Gallery',
        subtitle: 'XLand UI Foundation • Phase 1',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Toggle Submit State',
            onPressed: () {
              setState(() {
                _isButtonSubmitting = !_isButtonSubmitting;
              });
            },
          ),
        ],
      ),
      stickyFooter: StickyActionBar(
        child: PrimaryButton(
          label: 'Sticky Footer CTA (Hẹn tư vấn)',
          isSubmitting: _isButtonSubmitting,
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đã bấm Sticky Footer CTA')),
            );
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageGutter,
          vertical: AppSpacing.s16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DemoDataNotice(
              message: 'Gallery trưng bày toàn bộ Theme Tokens và Reusable Foundation Widgets theo DESIGN_SPEC v1.2.',
            ),
            const SizedBox(height: AppSpacing.s24),

            // 1. BRAND COLORS
            _buildSectionHeader('1. Color Tokens (MP & QƯ)'),
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: [
                _buildColorChip('brandPrimary', AppColors.brandPrimary, Colors.white),
                _buildColorChip('background', AppColors.background, AppColors.textPrimary),
                _buildColorChip('surface', AppColors.surface, AppColors.textPrimary),
                _buildColorChip('border', AppColors.border, AppColors.textPrimary),
                _buildColorChip('goldSurface', AppColors.goldSurface, AppColors.goldForeground),
                _buildColorChip('goldForeground', AppColors.goldForeground, Colors.white),
                _buildColorChip('verifiedSurface', AppColors.verifiedSurface, AppColors.verifiedForeground),
                _buildColorChip('danger', AppColors.danger, Colors.white),
                _buildColorChip('textPrimary', AppColors.textPrimary, Colors.white),
                _buildColorChip('textSecondary', AppColors.textSecondary, Colors.white),
                _buildColorChip('textMuted', AppColors.textMuted, Colors.white),
              ],
            ),
            const SizedBox(height: AppSpacing.s24),

            // 2. TYPOGRAPHY SCALE
            _buildSectionHeader('2. Typography Scale (Roboto)'),
            XLandCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('displayMetric: 40/46 Bold', style: AppTypography.displayMetric),
                  const Divider(height: 16),
                  Text('priceHero: 36/42 Bold', style: AppTypography.priceHero),
                  const Divider(height: 16),
                  Text('pageHero: 28/34 Bold', style: AppTypography.pageHero),
                  const Divider(height: 16),
                  Text('sheetTitle: 26/32 Bold', style: AppTypography.sheetTitle),
                  const Divider(height: 16),
                  Text('priceCard: 24/30 Bold', style: AppTypography.priceCard),
                  const Divider(height: 16),
                  Text('appBarTitle / sectionTitle: 18/24 SemiBold', style: AppTypography.sectionTitle),
                  const Divider(height: 16),
                  Text('cardTitle: 16/22 SemiBold', style: AppTypography.cardTitle),
                  const Divider(height: 16),
                  Text('body: 14/20 Regular — Nội dung mô tả pháp lý và thông số lô đất đầy đủ dấu tiếng Việt.', style: AppTypography.body),
                  const Divider(height: 16),
                  Text('bodyStrong: 14/20 SemiBold', style: AppTypography.bodyStrong),
                  const Divider(height: 16),
                  Text('compact: 12/16 Regular / compactStrong', style: AppTypography.compact),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s24),

            // 3. LOGO VARIANTS
            _buildSectionHeader('3. XLand Logo Slot'),
            Wrap(
              spacing: AppSpacing.s16,
              runSpacing: AppSpacing.s12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const XLandLogo(variant: XLandLogoVariant.onLight, showSlogan: true),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s8),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary,
                    borderRadius: AppRadius.cardRadius,
                  ),
                  child: const XLandLogo(variant: XLandLogoVariant.onGreen, showSlogan: true),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s24),

            // 4. BUTTONS & ACTIONS
            _buildSectionHeader('4. Buttons & Interactive States'),
            PrimaryButton(
              label: 'PrimaryButton (Normal)',
              onPressed: () {},
            ),
            const SizedBox(height: AppSpacing.s8),
            PrimaryButton(
              label: 'PrimaryButton (Submitting)',
              isSubmitting: _isButtonSubmitting,
              onPressed: () {},
            ),
            const SizedBox(height: AppSpacing.s8),
            const PrimaryButton(
              label: 'PrimaryButton (Disabled)',
              onPressed: null,
            ),
            const SizedBox(height: AppSpacing.s12),
            OutlineButton(
              label: 'OutlineButton (Normal)',
              onPressed: () {},
            ),
            const SizedBox(height: AppSpacing.s8),
            const OutlineButton(
              label: 'OutlineButton (Disabled)',
              onPressed: null,
            ),
            const SizedBox(height: AppSpacing.s12),
            Row(
              children: [
                IconActionButton(
                  icon: Icons.bookmark_border_rounded,
                  semanticLabel: 'Lưu',
                  onPressed: () {},
                ),
                const SizedBox(width: AppSpacing.s8),
                IconActionButton(
                  icon: Icons.bookmark_rounded,
                  semanticLabel: 'Đã lưu',
                  isActive: true,
                  onPressed: () {},
                ),
                const SizedBox(width: AppSpacing.s8),
                IconActionButton(
                  icon: Icons.share_outlined,
                  semanticLabel: 'Chia sẻ',
                  onPressed: () {},
                ),
                const SizedBox(width: AppSpacing.s8),
                IconActionButton(
                  icon: Icons.notifications_none_rounded,
                  semanticLabel: 'Thông báo',
                  badgeCount: 3,
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s24),

            // 5. STATUS BADGES & NOTICES
            _buildSectionHeader('5. Status Badges & Notices'),
            const Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: [
                StatusBadge(text: 'Nguồn HĐQT', variant: StatusBadgeVariant.source),
                StatusBadge(text: 'Tin đã duyệt', variant: StatusBadgeVariant.verified),
                StatusBadge(text: 'Đã đối chiếu', variant: StatusBadgeVariant.verified),
                StatusBadge(text: 'Chờ xác nhận', variant: StatusBadgeVariant.pending),
                StatusBadge(text: 'Đang chào bán', variant: StatusBadgeVariant.sale),
                StatusBadge(text: 'Hạn chế giao dịch', variant: StatusBadgeVariant.danger),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            const InfoNotice(
              title: 'Hồ sơ pháp lý đã kiểm tra 4/6 mục',
              message: 'Kết quả theo phạm vi hồ sơ cung cấp, chưa thay thế cam kết pháp lý chính thức.',
              variant: NoticeVariant.info,
            ),
            const SizedBox(height: AppSpacing.s8),
            const InfoNotice(
              title: 'Cần bổ sung 2 mục',
              message: 'Thông tin quy hoạch và hạn chế chuyển nhượng đang được rà soát bổ sung.',
              variant: NoticeVariant.warning,
            ),
            const SizedBox(height: AppSpacing.s8),
            const InfoNotice(
              title: 'Cảnh báo giao dịch',
              message: 'Thửa đất có chỉ giới quy hoạch mở rộng đường, cần kiểm tra kỹ trước khi đặt cọc.',
              variant: NoticeVariant.danger,
            ),
            const SizedBox(height: AppSpacing.s24),

            // 6. FORM INPUTS & SEARCH
            _buildSectionHeader('6. Form Inputs & Controls'),
            SearchField(
              hint: 'Tìm theo khu vực, ngân sách...',
              onFilterTap: () {},
            ),
            const SizedBox(height: AppSpacing.s12),
            XLandTextField(
              label: 'Họ và tên người đăng ký thực địa',
              hint: 'Nhập họ và tên đầy đủ',
              controller: _textController,
            ),
            const SizedBox(height: AppSpacing.s12),
            const XLandTextField(
              label: 'Số điện thoại liên hệ (Masked demo)',
              initialValue: '098 ••• •821',
              readOnly: true,
              helperText: 'Chỉ số điện thoại tài khoản chính chủ mới được xem đầy đủ.',
            ),
            const SizedBox(height: AppSpacing.s12),
            const XLandTextField(
              label: 'Trường có lỗi xác thực (Error validation)',
              initialValue: '-5000000',
              errorText: 'Số tiền vốn tự có không được âm.',
            ),
            const SizedBox(height: AppSpacing.s12),
            CounterInput(
              label: 'Số lượng người tham gia thực địa',
              value: _counterValue,
              onChanged: (val) {
                setState(() {
                  _counterValue = val;
                });
              },
            ),
            const SizedBox(height: AppSpacing.s24),

            // 7. TABS
            _buildSectionHeader('7. Underline & Pill Tabs'),
            UnderlineTabBar(
              tabs: const ['Tổng quan', 'Hồ sơ', 'Khu vực', 'Tài chính'],
              selectedIndex: _selectedTabIndex,
              onTabSelected: (index) {
                setState(() {
                  _selectedTabIndex = index;
                });
              },
            ),
            const SizedBox(height: AppSpacing.s12),
            PillTabs(
              items: const ['Phù hợp', 'Mới nhất', 'Đã lưu', 'Giá tốt'],
              selectedIndex: _selectedPillIndex,
              onSelected: (index) {
                setState(() {
                  _selectedPillIndex = index;
                });
              },
            ),
            const SizedBox(height: AppSpacing.s24),

            // 8. MEDIA PLACEHOLDERS
            _buildSectionHeader('8. Media & Gallery Placeholders'),
            const MediaGalleryPlaceholder(
              propertyCode: 'XL-028',
              photoCount: 8,
              currentIndex: 1,
            ),
            const SizedBox(height: AppSpacing.s24),

            // 9. FEEDBACK STATES
            _buildSectionHeader('9. Data Feedback States'),
            const XLandCard(
              child: LoadingState(message: 'Đang tải danh sách bất động sản Hòa Lạc...'),
            ),
            const SizedBox(height: AppSpacing.s12),
            XLandCard(
              child: EmptyState(
                title: 'Không tìm thấy lô đất',
                message: 'Không có bất động sản nào khớp với bộ lọc hiện tại. Vui lòng thử nới rộng tiêu chí tìm kiếm.',
                actionLabel: 'Đặt lại bộ lọc',
                onAction: () {},
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            XLandCard(
              child: ErrorRetryState(
                title: 'Không thể kết nối máy chủ',
                errorMessage: 'Lỗi tải danh mục địa giới (D03). Vui lòng kiểm tra kết nối mạng và thử lại.',
                onRetry: () {},
              ),
            ),
            const SizedBox(height: AppSpacing.s32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: Text(
        title,
        style: AppTypography.sectionTitle.copyWith(color: AppColors.brandPrimary),
      ),
    );
  }

  Widget _buildColorChip(String name, Color color, Color textColor) {
    return Container(
      width: 105,
      padding: const EdgeInsets.all(AppSpacing.s8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.thumbnail),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: AppTypography.compactStrong.copyWith(color: textColor, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase().substring(2)}',
            style: AppTypography.compact.copyWith(color: textColor.withValues(alpha: 0.8), fontSize: 9),
          ),
        ],
      ),
    );
  }
}
