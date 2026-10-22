import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/xland_domain.dart';
import '../../../shared/di/dependencies_scope.dart';
import '../../../shared/sharing/share_sheet.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../shared/widgets/design_widgets.dart';
import '../../../shared/widgets/illustrative_image.dart';
import '../widgets/media_gallery_view.dart';
import '../../../theme/theme.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import '../../auth/widgets/login_prompt_sheet.dart';
import '../cubit/property_detail_cubit.dart';
import '../../booking/pages/booking_sheet.dart';
import '../../consultant/pages/consultant_profile_page.dart';
import '../widgets/area_info_tab.dart';
import '../widgets/finance_plan_tab.dart';
import '../widgets/legal_summary_tab.dart';
import '../widgets/property_overview_tab.dart';

/// S02 Property Detail Page.
/// Preserves propertyId across tabs and provides sticky actions for booking and consultation.
class PropertyDetailPage extends StatelessWidget {
  const PropertyDetailPage({
    super.key,
    required this.propertyId,
    this.onBookingTap,
    this.initialTab = 0,
  });

  final String propertyId;
  final int initialTab;
  final VoidCallback? onBookingTap;

  @override
  Widget build(BuildContext context) {
    final deps = DependenciesScope.of(context);

    return BlocProvider(
      create: (_) =>
          PropertyDetailCubit(
              deps.properties,
              deps.consultants,
              propertyId: propertyId,
              contentChanges: deps.contentChanges,
            )
            ..selectTab(initialTab.clamp(0, 3))
            ..loadPropertyDetail(),
      child: PropertyDetailView(onBookingTap: onBookingTap),
    );
  }
}

class PropertyDetailView extends StatefulWidget {
  const PropertyDetailView({super.key, this.onBookingTap});

  final VoidCallback? onBookingTap;
  @override
  State<PropertyDetailView> createState() => _PropertyDetailViewState();
}

class _PropertyDetailViewState extends State<PropertyDetailView> {
  final _financeKey = GlobalKey<FinancePlanTabState>();
  bool _canSaveFinance = false;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _selectTab(BuildContext context, int index) {
    context.read<PropertyDetailCubit>().selectTab(index);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  Future<void> _handleBookmark(BuildContext context) async {
    final cubit = context.read<PropertyDetailCubit>();
    final authState = context.read<AuthCubit>().state;

    if (authState is AuthAuthenticated) {
      await cubit.toggleSaved();
    } else {
      await LoginPromptSheet.show(
        context,
        title: 'Lưu bất động sản',
        message:
            'Vui lòng đăng nhập để lưu lô đất vào danh sách theo dõi cá nhân.',
        onAuthenticated: () async {
          await cubit.toggleSaved();
        },
      );
    }
  }

  Future<void> _handleBooking(BuildContext context) async {
    _openBookingFlow(context);
  }

  void _openBookingFlow(BuildContext context) {
    if (widget.onBookingTap != null) {
      widget.onBookingTap!();
      return;
    }

    final cubit = context.read<PropertyDetailCubit>();
    BookingSheet.show(
      context,
      propertyId: cubit.propertyId,
      property: cubit.state.property,
    );
  }

  Future<void> _handleShare(BuildContext context, Property property) async {
    final repository = DependenciesScope.of(context).properties;
    await ShareSheet.show(
      context,
      title: property.title,
      loadLink: () => repository.getShareLink(property.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<PropertyDetailCubit>();
    final state = cubit.state;
    final property = state.property;

    return XLandScaffold(
      body: Column(
        children: [
          // App Bar with Share & Bookmark
          XLandAppBar(
            variant: XLandAppBarVariant.light,
            title: property == null ? 'Chi tiết bất động sản' : null,
            showBack: true,
            onBack: () => Navigator.of(context).pop(),
            actions: [
              if (property != null) ...[
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: XLandLogo(height: 24),
                ),
                IconActionButton(
                  icon: property.isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  semanticLabel: property.isSaved ? 'Bỏ lưu' : 'Lưu',
                  onPressed: () => _handleBookmark(context),
                ),
                IconActionButton(
                  icon: Icons.share_outlined,
                  semanticLabel: 'Chia sẻ',
                  onPressed: () => _handleShare(context, property),
                ),
              ],
            ],
          ),

          // Main Content or State Placeholders
          if (state.isLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.brandPrimary),
              ),
            )
          else if (state.errorMessage != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.pageGutter),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: AppColors.danger,
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      Text(
                        state.errorMessage!,
                        style: AppTypography.body,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      PrimaryButton(
                        label: 'Thử lại',
                        fullWidth: false,
                        onPressed: () => cubit.loadPropertyDetail(),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (property != null) ...[
            Expanded(
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: state.activeTab == 0
                        ? MediaGalleryView(
                            media: property.media,
                            currentIndex: state.activeMediaIndex,
                            onIndexChanged: cubit.selectMedia,
                            fallbackCode: property.code,
                            isIllustrative: property.isIllustrative,
                            illustrativeAsset: property.region == Region.central
                                ? IllustrativeAssets.coastal
                                : IllustrativeAssets.countryside,
                          )
                        : PropertySummaryStrip(
                            property: property,
                            onTap: () => _selectTab(context, 0),
                          ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _PropertyTabs(
                      selected: state.activeTab,
                      onSelected: (index) => _selectTab(context, index),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        Offstage(
                          offstage: state.activeTab != 0,
                          child:
                              // Tab 0: Tổng quan (S02)
                              PropertyOverviewTab(
                                property: property,
                                showGallery: false,
                                embedded: true,
                                consultant: state.consultant,
                                activeMediaIndex: state.activeMediaIndex,
                                onMediaIndexChanged: cubit.selectMedia,
                                onNavigateToLegalTab: () =>
                                    _selectTab(context, 1),
                                onConsultantTap: () {
                                  if (state.consultant != null) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => ConsultantProfilePage(
                                          consultantId: state.consultant!.id,
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                        ),

                        // Tab 1: Pháp lý (S03)
                        Offstage(
                          offstage: state.activeTab != 1,
                          child: state.legalSummary != null
                              ? LegalSummaryTab(
                                  embedded: true,
                                  legalSummary: state.legalSummary!,
                                  onDownloadDocument: cubit.downloadDocument,
                                  downloadGrant: state.downloadGrant,
                                  downloadError: state.downloadError,
                                )
                              : const Center(
                                  child: Text('Đang tải hồ sơ pháp lý...'),
                                ),
                        ),

                        // Tab 2: Khu vực & POI (S04)
                        Offstage(
                          offstage: state.activeTab != 2,
                          child: state.areaInfo != null
                              ? AreaInfoTab(
                                  key: ValueKey('property-area-${property.id}'),
                                  mapVisible: state.activeTab == 2,
                                  embedded: true,
                                  areaInfo: state.areaInfo!,
                                  selectedCategory:
                                      state.selectedAmenityCategory,
                                  onCategorySelected: cubit.filterAmenities,
                                )
                              : const Center(
                                  child: Text('Đang tải thông tin khu vực...'),
                                ),
                        ),

                        // Tab 3: Tài chính (S05)
                        Offstage(
                          offstage: state.activeTab != 3,
                          child: FinancePlanTab(
                            key: _financeKey,
                            property: state.property,
                            embedded: true,
                            onSaveAvailabilityChanged: (available) {
                              if (mounted && _canSaveFinance != available) {
                                setState(() => _canSaveFinance = available);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Sticky Bottom CTA Bar
            Container(
              padding: EdgeInsets.only(
                left: AppSpacing.pageGutter,
                right: AppSpacing.pageGutter,
                top: AppSpacing.s12,
                bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.s12,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: state.activeTab == 3
                  ? Row(
                      children: [
                        Expanded(
                          child: OutlineButton(
                            label: 'Lưu phương án',
                            icon: const Icon(Icons.bookmark_outline, size: 20),
                            onPressed: _canSaveFinance
                                ? () => _financeKey.currentState?.savePlan()
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: PrimaryButton(
                            label: 'Tư vấn khoản vay',
                            icon: const Icon(
                              Icons.chat_bubble_outline,
                              size: 20,
                            ),
                            onPressed: () =>
                                _financeKey.currentState?.requestLoanAdvice(),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              if (state.consultant != null) {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ConsultantProfilePage(
                                      consultantId: state.consultant!.id,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Row(
                              children: [
                                if (state.consultant != null) ...[
                                  SizedBox(
                                    width: 38,
                                    height: 38,
                                    child: ClipOval(
                                      child: XLandMediaImage(
                                        url: state.consultant!.avatarUrl,
                                        isIllustrative:
                                            state.consultant!.isIllustrative,
                                        illustrativeAsset:
                                            IllustrativeAssets.consultant,
                                        showLabel: false,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        state.consultant?.name ??
                                            'Tư vấn XLand',
                                        style: AppTypography.compactStrong,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'Chuyên viên tư vấn',
                                        style: AppTypography.compact.copyWith(
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s12),
                        Expanded(
                          flex: 2,
                          child: PrimaryButton(
                            label: state.activeTab == 2
                                ? 'Khảo sát khu vực'
                                : state.activeTab == 1
                                ? 'Tư vấn hồ sơ'
                                : 'Đặt lịch thực địa',
                            icon: const Icon(
                              Icons.calendar_today_outlined,
                              size: 20,
                            ),
                            onPressed: () {
                              if (state.activeTab == 1 &&
                                  state.consultant != null) {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ConsultantProfilePage(
                                      consultantId: state.consultant!.id,
                                    ),
                                  ),
                                );
                              } else {
                                _handleBooking(context);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PropertyTabs extends SliverPersistentHeaderDelegate {
  _PropertyTabs({required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;
  @override
  double get minExtent => AppSpacing.tabBarMinHeight;
  @override
  double get maxExtent => AppSpacing.tabBarMinHeight;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => UnderlineTabBar(
    tabs: const ['Tổng quan', 'Hồ sơ', 'Khu vực', 'Tài chính'],
    selectedIndex: selected,
    onTabSelected: onSelected,
    isScrollable: MediaQuery.textScalerOf(context).scale(1) > 1.1,
  );
  @override
  bool shouldRebuild(_PropertyTabs oldDelegate) =>
      oldDelegate.selected != selected;
}
