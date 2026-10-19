import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

import 'discovery_state.dart';

class DiscoveryCubit extends Cubit<DiscoveryState> {
  DiscoveryCubit(this._propertyRepository)
    : super(
        DiscoveryState(
          currentFilter: const PropertyFilter(
            regions: [],
            areaBands: [],
            landTypes: [],
            savedOnly: false,
            sort: PropertySort.relevant,
          ),
        ),
      );

  final PropertyRepository _propertyRepository;
  int _searchGeneration = 0;
  Timer? _searchDebounceTimer;

  @override
  Future<void> close() {
    _searchDebounceTimer?.cancel();
    return super.close();
  }

  Future<void> loadProperties() async {
    _searchDebounceTimer?.cancel();
    final gen = ++_searchGeneration;
    emit(
      state.copyWith(
        isLoading: true,
        clearError: true,
        isLoadingMore: false,
        clearLoadMoreError: true,
        hasMore: false,
        clearNextCursor: true,
      ),
    );
    try {
      final result = await _propertyRepository.search(
        state.currentFilter,
        const PageQuery(limit: 20),
      );
      if (isClosed || gen != _searchGeneration) return;
      emit(
        state.copyWith(
          isLoading: false,
          properties: result.page.items,
          total: result.total,
          hasMore: result.page.hasMore,
          nextCursor: result.page.nextCursor,
          clearNextCursor: result.page.nextCursor == null,
        ),
      );
    } on XlandFailure catch (e) {
      if (isClosed || gen != _searchGeneration) return;
      emit(state.copyWith(isLoading: false, errorMessage: e.message));
    } catch (e) {
      if (isClosed || gen != _searchGeneration) return;
      emit(
        state.copyWith(isLoading: false, errorMessage: 'Lỗi tải danh sách: $e'),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.nextCursor == null) {
      return;
    }
    final gen = _searchGeneration;
    emit(state.copyWith(isLoadingMore: true, clearLoadMoreError: true));
    try {
      final result = await _propertyRepository.search(
        state.currentFilter,
        PageQuery(cursor: state.nextCursor, limit: 20),
      );
      if (isClosed || gen != _searchGeneration) return;
      final existingIds = state.properties.map((p) => p.id).toSet();
      final newItems = result.page.items
          .where((p) => !existingIds.contains(p.id))
          .toList();
      emit(
        state.copyWith(
          isLoadingMore: false,
          properties: [...state.properties, ...newItems],
          hasMore: result.page.hasMore,
          nextCursor: result.page.nextCursor,
          clearNextCursor: result.page.nextCursor == null,
          total: result.total,
        ),
      );
    } on XlandFailure catch (e) {
      if (isClosed || gen != _searchGeneration) return;
      emit(state.copyWith(isLoadingMore: false, loadMoreError: e.message));
    } catch (e) {
      if (isClosed || gen != _searchGeneration) return;
      emit(
        state.copyWith(isLoadingMore: false, loadMoreError: 'Lỗi tải thêm: $e'),
      );
    }
  }

  void selectSubTab(int index) {
    if (state.activeSubTab == index) return;
    _searchDebounceTimer?.cancel();

    PropertyFilter newFilter;
    switch (index) {
      case 1:
        // Mới nhất
        newFilter = PropertyFilter(
          query: state.currentFilter.query,
          regions: state.currentFilter.regions,
          category: state.currentFilter.category,
          provinceCode: state.currentFilter.provinceCode,
          districtCode: state.currentFilter.districtCode,
          minPriceVnd: state.currentFilter.minPriceVnd,
          maxPriceVnd: state.currentFilter.maxPriceVnd,
          areaBands: state.currentFilter.areaBands,
          landTypes: state.currentFilter.landTypes,
          minRoadWidthM: state.currentFilter.minRoadWidthM,
          hasDocuments: state.currentFilter.hasDocuments,
          savedOnly: false,
          sort: PropertySort.newest,
        );
        break;
      case 2:
        // Đã lưu
        newFilter = PropertyFilter(
          query: state.currentFilter.query,
          regions: state.currentFilter.regions,
          category: state.currentFilter.category,
          provinceCode: state.currentFilter.provinceCode,
          districtCode: state.currentFilter.districtCode,
          minPriceVnd: state.currentFilter.minPriceVnd,
          maxPriceVnd: state.currentFilter.maxPriceVnd,
          areaBands: state.currentFilter.areaBands,
          landTypes: state.currentFilter.landTypes,
          minRoadWidthM: state.currentFilter.minRoadWidthM,
          hasDocuments: state.currentFilter.hasDocuments,
          savedOnly: true,
          sort: state.currentFilter.sort,
        );
        break;
      case 0:
      default:
        // Phù hợp
        newFilter = PropertyFilter(
          query: state.currentFilter.query,
          regions: state.currentFilter.regions,
          category: state.currentFilter.category,
          provinceCode: state.currentFilter.provinceCode,
          districtCode: state.currentFilter.districtCode,
          minPriceVnd: state.currentFilter.minPriceVnd,
          maxPriceVnd: state.currentFilter.maxPriceVnd,
          areaBands: state.currentFilter.areaBands,
          landTypes: state.currentFilter.landTypes,
          minRoadWidthM: state.currentFilter.minRoadWidthM,
          hasDocuments: state.currentFilter.hasDocuments,
          savedOnly: false,
          sort: PropertySort.relevant,
        );
        break;
    }

    emit(state.copyWith(activeSubTab: index, currentFilter: newFilter));
    loadProperties();
  }

  void selectCategory(String categoryName) {
    _searchDebounceTimer?.cancel();
    PropertyCategory? cat;
    List<Region> regions = [];

    switch (categoryName) {
      case 'KCN':
      case 'Công nghiệp':
        cat = PropertyCategory.industrial;
        regions = [];
        break;
      case 'Miền Bắc':
        cat = null;
        regions = [Region.north];
        break;
      case 'Miền Trung':
        cat = null;
        regions = [Region.central];
        break;
      case 'Miền Nam':
        cat = null;
        regions = [Region.south];
        break;
      case 'Đất nền':
        cat = PropertyCategory.residential;
        regions = [];
        break;
      case 'Tất cả':
      default:
        cat = null;
        regions = [];
        break;
    }

    final newFilter = PropertyFilter(
      query: state.currentFilter.query,
      regions: regions,
      category: cat,
      provinceCode: state.currentFilter.provinceCode,
      districtCode: state.currentFilter.districtCode,
      minPriceVnd: state.currentFilter.minPriceVnd,
      maxPriceVnd: state.currentFilter.maxPriceVnd,
      areaBands: state.currentFilter.areaBands,
      landTypes: state.currentFilter.landTypes,
      minRoadWidthM: state.currentFilter.minRoadWidthM,
      hasDocuments: state.currentFilter.hasDocuments,
      savedOnly: state.currentFilter.savedOnly,
      sort: state.currentFilter.sort,
    );

    emit(
      state.copyWith(activeCategory: categoryName, currentFilter: newFilter),
    );
    loadProperties();
  }

  void setSearchQuery(String query) {
    _searchDebounceTimer?.cancel();
    final cleanQuery = query.trim().isEmpty ? null : query.trim();
    if (cleanQuery == state.currentFilter.query && query == state.searchQuery) {
      return;
    }

    final newFilter = PropertyFilter(
      query: cleanQuery,
      regions: state.currentFilter.regions,
      category: state.currentFilter.category,
      provinceCode: state.currentFilter.provinceCode,
      districtCode: state.currentFilter.districtCode,
      minPriceVnd: state.currentFilter.minPriceVnd,
      maxPriceVnd: state.currentFilter.maxPriceVnd,
      areaBands: state.currentFilter.areaBands,
      landTypes: state.currentFilter.landTypes,
      minRoadWidthM: state.currentFilter.minRoadWidthM,
      hasDocuments: state.currentFilter.hasDocuments,
      savedOnly: state.currentFilter.savedOnly,
      sort: state.currentFilter.sort,
    );

    emit(state.copyWith(searchQuery: query, currentFilter: newFilter));
    loadProperties();
  }

  void onSearchInputChanged(
    String query, {
    Duration debounceDuration = const Duration(milliseconds: 300),
  }) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(debounceDuration, () {
      setSearchQuery(query);
    });
  }

  void applyFilter(PropertyFilter filter) {
    _searchDebounceTimer?.cancel();
    emit(
      state.copyWith(currentFilter: filter, searchQuery: filter.query ?? ''),
    );
    loadProperties();
  }

  void clearFilter() {
    _searchDebounceTimer?.cancel();
    const defaultFilter = PropertyFilter(
      regions: [],
      areaBands: [],
      landTypes: [],
      savedOnly: false,
      sort: PropertySort.relevant,
    );
    emit(
      state.copyWith(
        currentFilter: defaultFilter,
        searchQuery: '',
        activeCategory: 'Tất cả',
      ),
    );
    loadProperties();
  }

  Future<void> toggleSaved(Property property) async {
    await toggleSavedById(property.id, property.isSaved);
  }

  Future<void> toggleSavedById(String propertyId, bool currentSaved) async {
    try {
      final res = await _propertyRepository.setSaved(propertyId, !currentSaved);
      final updatedList = state.properties.map((p) {
        if (p.id == propertyId) {
          return Property(
            id: p.id,
            code: p.code,
            title: p.title,
            provinceCode: p.provinceCode,
            provinceName: p.provinceName,
            districtCode: p.districtCode,
            districtName: p.districtName,
            region: p.region,
            category: p.category,
            priceTotal: p.priceTotal,
            pricePerM2: p.pricePerM2,
            areaM2: p.areaM2,
            frontageM: p.frontageM,
            depthM: p.depthM,
            roadWidthM: p.roadWidthM,
            direction: p.direction,
            landType: p.landType,
            status: p.status,
            approvalStatus: p.approvalStatus,
            sourceBadge: p.sourceBadge,
            consultantId: p.consultantId,
            media: p.media,
            highlights: p.highlights,
            verifiedLegalCount: p.verifiedLegalCount,
            totalLegalCount: p.totalLegalCount,
            isSaved: res.active,
            updatedAt: p.updatedAt,
            isIllustrative: p.isIllustrative,
          );
        }
        return p;
      }).toList();

      emit(state.copyWith(properties: updatedList, clearError: true));
    } on XlandFailure catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Lỗi lưu bất động sản: $e'));
    }
  }
}
