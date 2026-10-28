import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

import 'filter_state.dart';

class FilterCubit extends Cubit<FilterState> {
  FilterCubit(this._propertyRepository, {required PropertyFilter initialFilter})
    : super(
        FilterState(
          draftFilter: initialFilter,
          selectedCriteriaCount: FilterState.computeCriteriaCount(
            initialFilter,
          ),
          matchingCount: 0,
          isCounting: true,
        ),
      ) {
    loadCatalog(provinceCode: initialFilter.provinceCode);
    _scheduleCount();
  }

  final PropertyRepository _propertyRepository;
  Timer? _debounceTimer;
  int _latestRequestId = 0;
  int _catalogGeneration = 0;

  Future<void> loadCatalog({String? provinceCode}) async {
    final gen = ++_catalogGeneration;
    final currentCat = state.catalog;
    final clearedCat = currentCat != null
        ? FilterCatalog(
            provinces: currentCat.provinces,
            districts: const [],
            minBudgetVnd: currentCat.minBudgetVnd,
            openUpperBudgetVnd: currentCat.openUpperBudgetVnd,
          )
        : null;

    emit(
      state.copyWith(
        isLoadingCatalog: true,
        catalog: clearedCat,
        clearCatalogError: true,
      ),
    );

    try {
      final cat = await _propertyRepository.getFilterCatalog(
        provinceCode: provinceCode,
      );
      if (isClosed || gen != _catalogGeneration) return;
      if (state.draftFilter.provinceCode != provinceCode) return;
      emit(
        state.copyWith(
          catalog: cat,
          isLoadingCatalog: false,
          clearCatalogError: true,
        ),
      );
    } catch (e) {
      if (isClosed || gen != _catalogGeneration) return;
      final msg = e is XlandFailure ? e.message : '$e';
      emit(
        state.copyWith(
          isLoadingCatalog: false,
          catalogHasError: true,
          catalogErrorMessage: 'Không thể tải danh mục: $msg',
        ),
      );
    }
  }

  void retryCatalog() {
    loadCatalog(provinceCode: state.draftFilter.provinceCode);
  }

  void retryCount() {
    _scheduleCount();
  }

  void _scheduleCount() {
    _debounceTimer?.cancel();
    emit(
      state.copyWith(
        isCounting: true,
        clearCountError: true,
        selectedCriteriaCount: FilterState.computeCriteriaCount(
          state.draftFilter,
        ),
      ),
    );

    final requestId = ++_latestRequestId;
    _debounceTimer = Timer(const Duration(milliseconds: 250), () async {
      try {
        final count = await _propertyRepository.count(state.draftFilter);
        if (!isClosed && requestId == _latestRequestId) {
          emit(
            state.copyWith(
              matchingCount: count,
              isCounting: false,
              clearCountError: true,
            ),
          );
        }
      } catch (e) {
        if (!isClosed && requestId == _latestRequestId) {
          final msg = e is XlandFailure ? e.message : '$e';
          emit(
            state.copyWith(
              isCounting: false,
              countHasError: true,
              countErrorMessage: 'Không thể cập nhật số lượng kết quả: $msg',
            ),
          );
        }
      }
    });
  }

  void toggleRegion(Region region) {
    final currentRegions = List<Region>.from(state.draftFilter.regions);
    if (currentRegions.contains(region)) {
      currentRegions.remove(region);
    } else {
      currentRegions.add(region);
    }

    final newFilter = PropertyFilter(
      query: state.draftFilter.query,
      regions: currentRegions,
      category: state.draftFilter.category,
      provinceCode: state.draftFilter.provinceCode,
      districtCode: state.draftFilter.districtCode,
      communeCode: state.draftFilter.communeCode,
      minPriceVnd: state.draftFilter.minPriceVnd,
      maxPriceVnd: state.draftFilter.maxPriceVnd,
      areaBands: state.draftFilter.areaBands,
      landTypes: state.draftFilter.landTypes,
      minRoadWidthM: state.draftFilter.minRoadWidthM,
      hasDocuments: state.draftFilter.hasDocuments,
      savedOnly: state.draftFilter.savedOnly,
      sort: state.draftFilter.sort,
    );

    emit(state.copyWith(draftFilter: newFilter));
    _scheduleCount();
  }

  void setCategory(PropertyCategory? category) {
    final newFilter = PropertyFilter(
      query: state.draftFilter.query,
      regions: state.draftFilter.regions,
      category: state.draftFilter.category == category ? null : category,
      provinceCode: state.draftFilter.provinceCode,
      districtCode: state.draftFilter.districtCode,
      communeCode: state.draftFilter.communeCode,
      minPriceVnd: state.draftFilter.minPriceVnd,
      maxPriceVnd: state.draftFilter.maxPriceVnd,
      areaBands: state.draftFilter.areaBands,
      landTypes: const [],
      minRoadWidthM: state.draftFilter.minRoadWidthM,
      hasDocuments: state.draftFilter.hasDocuments,
      savedOnly: state.draftFilter.savedOnly,
      sort: state.draftFilter.sort,
    );

    emit(state.copyWith(draftFilter: newFilter));
    _scheduleCount();
  }

  void setProvinceCode(String? provinceCode) {
    final cleanProvince = provinceCode?.trim().isEmpty ?? true
        ? null
        : provinceCode?.trim();
    if (cleanProvince == state.draftFilter.provinceCode) return;

    final newFilter = PropertyFilter(
      query: state.draftFilter.query,
      regions: state.draftFilter.regions,
      category: state.draftFilter.category,
      provinceCode: cleanProvince,
      districtCode: null, // Reset district when province changes
      minPriceVnd: state.draftFilter.minPriceVnd,
      maxPriceVnd: state.draftFilter.maxPriceVnd,
      areaBands: state.draftFilter.areaBands,
      landTypes: state.draftFilter.landTypes,
      minRoadWidthM: state.draftFilter.minRoadWidthM,
      hasDocuments: state.draftFilter.hasDocuments,
      savedOnly: state.draftFilter.savedOnly,
      sort: state.draftFilter.sort,
    );

    emit(state.copyWith(draftFilter: newFilter));
    loadCatalog(provinceCode: cleanProvince);
    _scheduleCount();
  }

  void setDistrictCode(String? districtCode) {
    final cleanDistrict = districtCode?.trim().isEmpty ?? true
        ? null
        : districtCode?.trim();
    if (cleanDistrict == state.draftFilter.districtCode) return;

    final newFilter = PropertyFilter(
      query: state.draftFilter.query,
      regions: state.draftFilter.regions,
      category: state.draftFilter.category,
      provinceCode: state.draftFilter.provinceCode,
      districtCode: cleanDistrict,
      minPriceVnd: state.draftFilter.minPriceVnd,
      maxPriceVnd: state.draftFilter.maxPriceVnd,
      areaBands: state.draftFilter.areaBands,
      landTypes: state.draftFilter.landTypes,
      minRoadWidthM: state.draftFilter.minRoadWidthM,
      hasDocuments: state.draftFilter.hasDocuments,
      savedOnly: state.draftFilter.savedOnly,
      sort: state.draftFilter.sort,
    );

    emit(state.copyWith(draftFilter: newFilter));
    _scheduleCount();
  }

  void setCommuneCode(String? communeCode) {
    final cleanCommune = communeCode?.trim().isEmpty ?? true
        ? null
        : communeCode?.trim();
    if (cleanCommune == state.draftFilter.communeCode) return;

    final newFilter = PropertyFilter(
      query: state.draftFilter.query,
      regions: state.draftFilter.regions,
      category: state.draftFilter.category,
      provinceCode: state.draftFilter.provinceCode,
      communeCode: cleanCommune,
      minPriceVnd: state.draftFilter.minPriceVnd,
      maxPriceVnd: state.draftFilter.maxPriceVnd,
      areaBands: state.draftFilter.areaBands,
      landTypes: state.draftFilter.landTypes,
      minRoadWidthM: state.draftFilter.minRoadWidthM,
      hasDocuments: state.draftFilter.hasDocuments,
      savedOnly: state.draftFilter.savedOnly,
      sort: state.draftFilter.sort,
    );

    emit(state.copyWith(draftFilter: newFilter));
    _scheduleCount();
  }

  void setPriceRange(Vnd? min, Vnd? max) {
    final newFilter = PropertyFilter(
      query: state.draftFilter.query,
      regions: state.draftFilter.regions,
      category: state.draftFilter.category,
      provinceCode: state.draftFilter.provinceCode,
      districtCode: state.draftFilter.districtCode,
      communeCode: state.draftFilter.communeCode,
      minPriceVnd: min,
      maxPriceVnd: max,
      areaBands: state.draftFilter.areaBands,
      landTypes: state.draftFilter.landTypes,
      minRoadWidthM: state.draftFilter.minRoadWidthM,
      hasDocuments: state.draftFilter.hasDocuments,
      savedOnly: state.draftFilter.savedOnly,
      sort: state.draftFilter.sort,
    );

    emit(state.copyWith(draftFilter: newFilter));
    _scheduleCount();
  }

  void setPriceValid(bool isValid) {
    emit(state.copyWith(isPriceValid: isValid));
  }

  void toggleAreaBand(AreaBand band) {
    final currentBands = List<AreaBand>.from(state.draftFilter.areaBands);
    if (currentBands.contains(band)) {
      currentBands.remove(band);
    } else {
      currentBands.add(band);
    }

    final newFilter = PropertyFilter(
      query: state.draftFilter.query,
      regions: state.draftFilter.regions,
      category: state.draftFilter.category,
      provinceCode: state.draftFilter.provinceCode,
      districtCode: state.draftFilter.districtCode,
      communeCode: state.draftFilter.communeCode,
      minPriceVnd: state.draftFilter.minPriceVnd,
      maxPriceVnd: state.draftFilter.maxPriceVnd,
      areaBands: currentBands,
      landTypes: state.draftFilter.landTypes,
      minRoadWidthM: state.draftFilter.minRoadWidthM,
      hasDocuments: state.draftFilter.hasDocuments,
      savedOnly: state.draftFilter.savedOnly,
      sort: state.draftFilter.sort,
    );

    emit(state.copyWith(draftFilter: newFilter));
    _scheduleCount();
  }

  void toggleLandType(LandType landType) {
    final currentTypes = List<LandType>.from(state.draftFilter.landTypes);
    if (currentTypes.contains(landType)) {
      currentTypes.remove(landType);
    } else {
      currentTypes.add(landType);
    }

    final newFilter = PropertyFilter(
      query: state.draftFilter.query,
      regions: state.draftFilter.regions,
      category: state.draftFilter.category,
      provinceCode: state.draftFilter.provinceCode,
      districtCode: state.draftFilter.districtCode,
      communeCode: state.draftFilter.communeCode,
      minPriceVnd: state.draftFilter.minPriceVnd,
      maxPriceVnd: state.draftFilter.maxPriceVnd,
      areaBands: state.draftFilter.areaBands,
      landTypes: currentTypes,
      minRoadWidthM: state.draftFilter.minRoadWidthM,
      hasDocuments: state.draftFilter.hasDocuments,
      savedOnly: state.draftFilter.savedOnly,
      sort: state.draftFilter.sort,
    );

    emit(state.copyWith(draftFilter: newFilter));
    _scheduleCount();
  }

  void setRoadWidth(DecimalValue? minRoadWidthM) {
    final newFilter = PropertyFilter(
      query: state.draftFilter.query,
      regions: state.draftFilter.regions,
      category: state.draftFilter.category,
      provinceCode: state.draftFilter.provinceCode,
      districtCode: state.draftFilter.districtCode,
      communeCode: state.draftFilter.communeCode,
      minPriceVnd: state.draftFilter.minPriceVnd,
      maxPriceVnd: state.draftFilter.maxPriceVnd,
      areaBands: state.draftFilter.areaBands,
      landTypes: state.draftFilter.landTypes,
      minRoadWidthM: minRoadWidthM,
      hasDocuments: state.draftFilter.hasDocuments,
      savedOnly: state.draftFilter.savedOnly,
      sort: state.draftFilter.sort,
    );

    emit(state.copyWith(draftFilter: newFilter));
    _scheduleCount();
  }

  void setHasDocuments(bool? hasDocuments) {
    final newFilter = PropertyFilter(
      query: state.draftFilter.query,
      regions: state.draftFilter.regions,
      category: state.draftFilter.category,
      provinceCode: state.draftFilter.provinceCode,
      districtCode: state.draftFilter.districtCode,
      communeCode: state.draftFilter.communeCode,
      minPriceVnd: state.draftFilter.minPriceVnd,
      maxPriceVnd: state.draftFilter.maxPriceVnd,
      areaBands: state.draftFilter.areaBands,
      landTypes: state.draftFilter.landTypes,
      minRoadWidthM: state.draftFilter.minRoadWidthM,
      hasDocuments: hasDocuments,
      savedOnly: state.draftFilter.savedOnly,
      sort: state.draftFilter.sort,
    );

    emit(state.copyWith(draftFilter: newFilter));
    _scheduleCount();
  }

  void reset() {
    const defaultFilter = PropertyFilter(
      regions: [],
      areaBands: [],
      landTypes: [],
      savedOnly: false,
      sort: PropertySort.relevant,
    );

    emit(
      state.copyWith(
        draftFilter: defaultFilter,
        selectedCriteriaCount: 0,
        isPriceValid: true,
        resetGeneration: state.resetGeneration + 1,
      ),
    );
    loadCatalog();
    _scheduleCount();
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }
}
