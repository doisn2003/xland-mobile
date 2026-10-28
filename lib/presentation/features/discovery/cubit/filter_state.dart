import 'package:flutter/foundation.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

@immutable
class FilterState {
  const FilterState({
    required this.draftFilter,
    required this.selectedCriteriaCount,
    required this.matchingCount,
    this.isCounting = false,
    this.countHasError = false,
    this.countErrorMessage,
    this.catalog,
    this.isLoadingCatalog = false,
    this.catalogHasError = false,
    this.catalogErrorMessage,
    this.isPriceValid = true,
    this.resetGeneration = 0,
  });

  final PropertyFilter draftFilter;
  final int selectedCriteriaCount;
  final int matchingCount;
  final bool isCounting;
  final bool countHasError;
  final String? countErrorMessage;
  final FilterCatalog? catalog;
  final bool isLoadingCatalog;
  final bool catalogHasError;
  final String? catalogErrorMessage;
  final bool isPriceValid;
  final int resetGeneration;

  FilterState copyWith({
    PropertyFilter? draftFilter,
    int? selectedCriteriaCount,
    int? matchingCount,
    bool? isCounting,
    bool? countHasError,
    String? countErrorMessage,
    bool clearCountError = false,
    FilterCatalog? catalog,
    bool? isLoadingCatalog,
    bool? catalogHasError,
    String? catalogErrorMessage,
    bool clearCatalogError = false,
    bool? isPriceValid,
    int? resetGeneration,
  }) {
    return FilterState(
      draftFilter: draftFilter ?? this.draftFilter,
      selectedCriteriaCount:
          selectedCriteriaCount ?? this.selectedCriteriaCount,
      matchingCount: matchingCount ?? this.matchingCount,
      isCounting: isCounting ?? this.isCounting,
      countHasError: clearCountError
          ? false
          : (countHasError ?? this.countHasError),
      countErrorMessage: clearCountError
          ? null
          : (countErrorMessage ?? this.countErrorMessage),
      catalog: catalog ?? this.catalog,
      isLoadingCatalog: isLoadingCatalog ?? this.isLoadingCatalog,
      catalogHasError: clearCatalogError
          ? false
          : (catalogHasError ?? this.catalogHasError),
      catalogErrorMessage: clearCatalogError
          ? null
          : (catalogErrorMessage ?? this.catalogErrorMessage),
      isPriceValid: isPriceValid ?? this.isPriceValid,
      resetGeneration: resetGeneration ?? this.resetGeneration,
    );
  }

  static int computeCriteriaCount(PropertyFilter filter) {
    int count = 0;
    // 1. Search Query
    if (filter.query != null && filter.query!.trim().isNotEmpty) count++;
    // 2. Region group
    if (filter.regions.isNotEmpty) count++;
    // 3. Category group
    if (filter.category != null) count++;
    // 4. Province group
    if (filter.provinceCode != null && filter.provinceCode!.trim().isNotEmpty) {
      count++;
    }
    // 5. District group
    if (filter.districtCode != null && filter.districtCode!.trim().isNotEmpty) {
      count++;
    }
    // 6. Budget / Price Range group (counted as 1 per C-3 & Decision A-03)
    if (filter.communeCode?.isNotEmpty ?? false) count++;
    if (filter.minPriceVnd != null || filter.maxPriceVnd != null) count++;
    // 7. Area band group
    if (filter.areaBands.isNotEmpty) count++;
    // 8. Land type group
    if (filter.landTypes.isNotEmpty) count++;
    // 9. Road width group
    if (filter.minRoadWidthM != null) count++;
    // 10. Documents group
    if (filter.hasDocuments != null) count++;
    return count;
  }
}
