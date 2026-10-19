import 'package:flutter/foundation.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

@immutable
class DiscoveryState {
  const DiscoveryState({
    this.isLoading = false,
    this.properties = const [],
    this.total = 0,
    this.activeCategory = 'Đất nền',
    this.activeSubTab = 0, // 0: Phù hợp, 1: Mới nhất, 2: Đã lưu
    required this.currentFilter,
    this.searchQuery = '',
    this.errorMessage,
    this.hasMore = false,
    this.nextCursor,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final bool isLoading;
  final List<Property> properties;
  final int total;
  final String activeCategory;
  final int activeSubTab;
  final PropertyFilter currentFilter;
  final String searchQuery;
  final String? errorMessage;
  final bool hasMore;
  final String? nextCursor;
  final bool isLoadingMore;
  final String? loadMoreError;

  bool get hasActiveFilters =>
      currentFilter.regions.isNotEmpty ||
      currentFilter.category != null ||
      currentFilter.provinceCode != null ||
      currentFilter.districtCode != null ||
      currentFilter.minPriceVnd != null ||
      currentFilter.maxPriceVnd != null ||
      currentFilter.areaBands.isNotEmpty ||
      currentFilter.landTypes.isNotEmpty ||
      currentFilter.minRoadWidthM != null ||
      currentFilter.hasDocuments != null ||
      searchQuery.trim().isNotEmpty;

  DiscoveryState copyWith({
    bool? isLoading,
    List<Property>? properties,
    int? total,
    String? activeCategory,
    int? activeSubTab,
    PropertyFilter? currentFilter,
    String? searchQuery,
    String? errorMessage,
    bool clearError = false,
    bool? hasMore,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? isLoadingMore,
    String? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return DiscoveryState(
      isLoading: isLoading ?? this.isLoading,
      properties: properties ?? this.properties,
      total: total ?? this.total,
      activeCategory: activeCategory ?? this.activeCategory,
      activeSubTab: activeSubTab ?? this.activeSubTab,
      currentFilter: currentFilter ?? this.currentFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      hasMore: hasMore ?? this.hasMore,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError: clearLoadMoreError
          ? null
          : (loadMoreError ?? this.loadMoreError),
    );
  }
}
