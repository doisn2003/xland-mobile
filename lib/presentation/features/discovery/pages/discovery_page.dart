import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

import '../../../shared/di/dependencies_scope.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../shared/widgets/illustrative_image.dart';
import '../../../theme/theme.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import '../../auth/widgets/login_prompt_sheet.dart';
import '../../clubs/pages/club_list_page.dart';
import '../../events/pages/event_detail_page.dart';
import '../../property_detail/pages/property_detail_page.dart';
import '../cubit/discovery_cubit.dart';
import '../widgets/category_selector.dart';
import '../widgets/hero_carousel.dart';
import '../widgets/property_card.dart';
import '../widgets/property_filter_sheet.dart';

/// S01 Discovery Page component.
/// Displays searchable, filterable 2-column property catalog, category selector,
/// hero carousel with event/club access, and saved properties.
class DiscoveryPage extends StatelessWidget {
  const DiscoveryPage({super.key, this.onOpenDetail, this.initialFilter});

  final ValueChanged<String>? onOpenDetail;
  final PropertyFilter? initialFilter;

  @override
  Widget build(BuildContext context) {
    final deps = DependenciesScope.of(context);

    return BlocProvider(
      create: (_) {
        final cubit = DiscoveryCubit(deps.properties);
        if (initialFilter != null) {
          cubit.applyFilter(initialFilter!);
        } else {
          cubit.loadProperties();
        }
        return cubit;
      },
      child: DiscoveryView(
        onOpenDetail: onOpenDetail,
        showBack: initialFilter != null,
      ),
    );
  }
}

class DiscoveryView extends StatefulWidget {
  const DiscoveryView({super.key, this.onOpenDetail, this.showBack = false});

  final bool showBack;

  final ValueChanged<String>? onOpenDetail;

  @override
  State<DiscoveryView> createState() => _DiscoveryViewState();
}

class _DiscoveryViewState extends State<DiscoveryView> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  XlandEvent? _featuredEvent;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFeaturedEvent();
    });
  }

  Future<void> _loadFeaturedEvent() async {
    if (!mounted) return;
    try {
      final deps = DependenciesScope.of(context);
      final eventsPage = await deps.events.getEvents(
        const PageQuery(limit: 1),
        status: EventStatus.open,
      );
      if (mounted && eventsPage.items.isNotEmpty) {
        setState(() {
          _featuredEvent = eventsPage.items.first;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      context.read<DiscoveryCubit>().loadMore();
    }
  }

  void _onSearchSubmitted(String query) {
    context.read<DiscoveryCubit>().setSearchQuery(query);
  }

  Future<void> _openFilterSheet() async {
    final cubit = context.read<DiscoveryCubit>();
    final deps = DependenciesScope.of(context);

    final updatedFilter = await PropertyFilterSheet.show(
      context,
      propertyRepository: deps.properties,
      currentFilter: cubit.state.currentFilter,
    );

    if (updatedFilter != null && mounted) {
      cubit.applyFilter(updatedFilter);
    }
  }

  void _navigateToDetail(Property property) {
    if (widget.onOpenDetail != null) {
      widget.onOpenDetail!(property.id);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PropertyDetailPage(propertyId: property.id),
      ),
    );
  }

  Future<void> _handleBookmark(Property property) async {
    final cubit = context.read<DiscoveryCubit>();
    final authState = context.read<AuthCubit>().state;

    if (authState is AuthAuthenticated) {
      await cubit.toggleSaved(property);
    } else {
      // Guest mode write-action intercept
      await LoginPromptSheet.show(
        context,
        title: 'Lưu bất động sản',
        message: 'Vui lòng đăng nhập để lưu lô đất vào danh sách yêu thích và theo dõi cập nhật.',
        onAuthenticated: () async {
          await cubit.toggleSaved(property);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<DiscoveryCubit>();
    final state = cubit.state;

    return XLandScaffold(
      body: Column(
        children: [
          // App Bar
          XLandAppBar(
            variant: XLandAppBarVariant.green,
            showBack: widget.showBack,
            showLogo: true,

            actions: [
              IconActionButton(
                icon: Icons.refresh_rounded,
                semanticLabel: 'Làm mới',
                foregroundColor: AppColors.onPrimary,
                onPressed: () => cubit.loadProperties(),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Khám phá',
                    style: AppTypography.pageHero.copyWith(fontSize: 30),
                  ),
                ),
                TextButton.icon(
                  onPressed: _openFilterSheet,
                  icon: const Icon(Icons.location_on, size: 19),
                  label: const Text('Toàn quốc'),
                ),
              ],
            ),
          ),

          // Search Field & Filter Trigger
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageGutter,
              vertical: AppSpacing.s8,
            ),
            child: SearchField(
              controller: _searchController,
              hint: 'Tìm theo khu vực, tên hoặc mã lô...',
              onSubmitted: _onSearchSubmitted,
              onChanged: (val) {
                cubit.onSearchInputChanged(val);
              },
              onFilterTap: _openFilterSheet,
              hasActiveFilters: state.hasActiveFilters,
            ),
          ),

          // Main Scrollable Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => cubit.loadProperties(),
              color: AppColors.brandPrimary,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // Category Selector (Tabs)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                      child: CategorySelector(
                        selectedIndex: _getCategoryIndex(state.activeCategory),
                        onSelected: (idx) {
                          if (idx < 2) {
                            cubit.selectCategory(
                              CategorySelector.categories[idx],
                            );
                          } else if (idx == 4) {
                            if (_featuredEvent != null) {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => EventDetailPage(
                                    eventId: _featuredEvent!.id,
                                  ),
                                ),
                              );
                            }
                          } else {
                            _choosePropertyTool(idx == 2 ? 1 : 3);
                          }
                        },
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: InkWell(
                        onTap: _openFilterSheet,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            height: 105,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.asset(
                                  IllustrativeAssets.countryside,
                                  fit: BoxFit.cover,
                                ),
                                const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Color(0xCC0F4C3A),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 12,
                                  bottom: 12,
                                  right: 12,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Tìm đất theo mục tiêu của bạn',
                                        style: AppTypography.sectionTitle
                                            .copyWith(color: Colors.white),
                                      ),
                                      Text(
                                        'Ở thực • Kinh doanh • Tích lũy',
                                        style: AppTypography.body.copyWith(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Sub-tabs (Phù hợp, Mới nhất, Đã lưu)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.pageGutter,
                        vertical: AppSpacing.s4,
                      ),
                      child: PillTabs(
                        items: const ['Phù hợp', 'Mới nhất', 'Đã lưu'],
                        selectedIndex: state.activeSubTab,
                        onSelected: cubit.selectSubTab,
                      ),
                    ),
                  ),

                  // Results header (Responsive Wrap prevents overflow at 360/1.3 and 390/1.3)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageGutter,
                        AppSpacing.s12,
                        AppSpacing.pageGutter,
                        AppSpacing.s8,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: AppSpacing.s8,
                            runSpacing: AppSpacing.s4,
                            children: [
                              Text(
                                'Nguồn hàng đang chào bán (${state.total})',
                                style: AppTypography.sectionTitle,
                              ),
                              if (state.hasActiveFilters)
                                TextButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    cubit.clearFilter();
                                  },
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                  ),
                                  child: Text(
                                    'Xóa lọc',
                                    style: AppTypography.compactStrong.copyWith(
                                      color: AppColors.brandPrimary,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                  // Property Grid or State Placeholders
                  if (state.isLoading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    )
                  else if (state.errorMessage != null)
                    SliverFillRemaining(
                      hasScrollBody: false,
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
                                onPressed: () => cubit.loadProperties(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (state.properties.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.pageGutter),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.search_off_rounded,
                                size: 48,
                                color: AppColors.disabledForeground,
                              ),
                              const SizedBox(height: AppSpacing.s12),
                              Text(
                                'Không tìm thấy lô đất phù hợp',
                                style: AppTypography.cardTitle,
                              ),
                              const SizedBox(height: AppSpacing.s4),
                              Text(
                                'Vui lòng thay đổi từ khóa hoặc điều chỉnh tiêu chí lọc.',
                                style: AppTypography.body.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppSpacing.s16),
                              OutlineButton(
                                label: 'Đặt lại bộ lọc',
                                fullWidth: false,
                                onPressed: cubit.clearFilter,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Builder(
                      builder: (context) {
                        return SliverPadding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.pageGutter,
                            vertical: AppSpacing.s8,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final first = state.properties[index * 2];
                              final second =
                                  index * 2 + 1 < state.properties.length
                                  ? state.properties[index * 2 + 1]
                                  : null;
                              Widget card(Property p) => PropertyCard(
                                property: p,
                                onTap: () => _navigateToDetail(p),
                                onBookmarkTap: () => _handleBookmark(p),
                              );
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.gapGrid,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: card(first)),
                                    const SizedBox(width: AppSpacing.gapGrid),
                                    Expanded(
                                      child: second == null
                                          ? const SizedBox()
                                          : card(second),
                                    ),
                                  ],
                                ),
                              );
                            }, childCount: (state.properties.length + 1) ~/ 2),
                          ),
                        );
                      },
                    ),

                  if (state.properties.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.pageGutter,
                          vertical: AppSpacing.s16,
                        ),
                        child: Column(
                          children: [
                            if (state.isLoadingMore)
                              const Padding(
                                padding: EdgeInsets.all(AppSpacing.s12),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.brandPrimary,
                                  ),
                                ),
                              )
                            else if (state.loadMoreError != null)
                              Padding(
                                padding: const EdgeInsets.all(AppSpacing.s8),
                                child: Column(
                                  children: [
                                    Text(
                                      state.loadMoreError!,
                                      style: AppTypography.compact.copyWith(
                                        color: AppColors.danger,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: AppSpacing.s8),
                                    OutlineButton(
                                      label: 'Thử lại tải thêm',
                                      fullWidth: false,
                                      onPressed: () => cubit.loadMore(),
                                    ),
                                  ],
                                ),
                              )
                            else if (state.hasMore)
                              OutlineButton(
                                label: 'Xem thêm bất động sản',
                                fullWidth: true,
                                onPressed: () => cubit.loadMore(),
                              )
                            else if (state.properties.length >= 20)
                              Text(
                                'Đã hiển thị tất cả bất động sản phù hợp',
                                style: AppTypography.compact.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            const SizedBox(height: AppSpacing.s16),
                          ],
                        ),
                      ),
                    )
                  else
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.s24),
                    ),
                  // Events and clubs follow the land catalog, per BUSINESS.
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageGutter,
                        AppSpacing.s16,
                        AppSpacing.pageGutter,
                        AppSpacing.s8,
                      ),
                      child: Text(
                        'Sự kiện & cộng đồng',
                        style: AppTypography.sectionTitle,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.s24),
                      child: HeroCarousel(
                        eventTitle:
                            _featuredEvent?.title ??
                            'Sự kiện đang được cập nhật',
                        eventSubtitle:
                            _featuredEvent?.venueName ??
                            'Kết nối cùng cộng đồng XLand',
                        onEventTap: _featuredEvent == null
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => EventDetailPage(
                                    eventId: _featuredEvent!.id,
                                  ),
                                ),
                              ),
                        onClubTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ClubListPage(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _choosePropertyTool(int tab) async {
    final properties = context.read<DiscoveryCubit>().state.properties;
    if (properties.isEmpty) {
      await _openFilterSheet();
      return;
    }
    final property = await showModalBottomSheet<Property>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                tab == 1
                    ? 'Chọn lô đất để xem hồ sơ'
                    : 'Chọn lô đất để lập phương án vay',
                style: AppTypography.sectionTitle,
              ),
            ),
            for (final p in properties)
              ListTile(
                title: Text(p.title),
                subtitle: Text(p.code),
                leading: Icon(
                  tab == 1
                      ? Icons.description_outlined
                      : Icons.savings_outlined,
                  color: AppColors.goldDecorative,
                ),
                onTap: () => Navigator.pop(context, p),
              ),
          ],
        ),
      ),
    );
    if (property != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              PropertyDetailPage(propertyId: property.id, initialTab: tab),
        ),
      );
    }
  }

  int _getCategoryIndex(String category) {
    final idx = CategorySelector.categories.indexOf(category);
    return idx >= 0 ? idx : 0;
  }
}
