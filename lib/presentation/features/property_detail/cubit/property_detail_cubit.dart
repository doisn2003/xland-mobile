import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

import 'property_detail_state.dart';

class PropertyDetailCubit extends Cubit<PropertyDetailState> {
  PropertyDetailCubit(
    this._propertyRepository,
    this._consultantRepository, {
    required this.propertyId,
    Stream<Set<String>>? contentChanges,
  }) : super(PropertyDetailState(propertyId: propertyId)) {
    _contentSubscription = contentChanges?.listen((paths) {
      if (!isClosed &&
          paths.any(
            (p) =>
                p == '/properties/$propertyId' ||
                p.startsWith('/properties/$propertyId/'),
          )) {
        loadPropertyDetail(silent: true);
      }
    });
  }

  final String propertyId;
  final PropertyRepository _propertyRepository;
  final ConsultantRepository _consultantRepository;
  StreamSubscription<Set<String>>? _contentSubscription;
  int _loadGeneration = 0;

  Future<void> loadPropertyDetail({bool silent = false}) async {
    final generation = ++_loadGeneration;
    emit(state.copyWith(isLoading: !silent, clearError: true));
    try {
      final results = await Future.wait<Object>([
        _propertyRepository.getProperty(propertyId),
        _propertyRepository.getLegal(propertyId),
        _propertyRepository.getArea(
          propertyId,
          category: state.selectedAmenityCategory,
        ),
      ]);
      final property = results[0] as Property;
      final legalSummary = results[1] as LegalSummary;
      final areaInfo = results[2] as AreaInfo;

      Consultant? consultant;
      try {
        consultant = await _consultantRepository.getConsultant(
          property.consultantId,
        );
      } catch (_) {
        consultant = null;
      }

      if (isClosed || generation != _loadGeneration) return;
      emit(
        state.copyWith(
          isLoading: false,
          property: property,
          legalSummary: legalSummary,
          areaInfo: areaInfo,
          consultant: consultant,
        ),
      );
    } on XlandFailure catch (e) {
      if (isClosed || generation != _loadGeneration) return;
      emit(state.copyWith(isLoading: false, errorMessage: e.message));
    } catch (e) {
      if (isClosed || generation != _loadGeneration) return;
      emit(
        state.copyWith(isLoading: false, errorMessage: 'Lỗi tải dữ liệu: $e'),
      );
    }
  }

  @override
  Future<void> close() {
    _contentSubscription?.cancel();
    return super.close();
  }

  void selectTab(int index) {
    if (state.activeTab == index) return;
    emit(state.copyWith(activeTab: index));
  }

  int _amenityGeneration = 0;

  void selectMedia(int index) {
    if (state.activeMediaIndex == index) return;
    emit(state.copyWith(activeMediaIndex: index));
  }

  Future<void> filterAmenities(AmenityCategory? category) async {
    final gen = ++_amenityGeneration;
    emit(
      state.copyWith(
        selectedAmenityCategory: category,
        clearAmenityCategory: category == null,
      ),
    );
    try {
      final updatedArea = await _propertyRepository.getArea(
        propertyId,
        category: category,
      );
      if (isClosed || gen != _amenityGeneration) return;
      if (state.selectedAmenityCategory != category) return;
      emit(state.copyWith(areaInfo: updatedArea));
    } on XlandFailure catch (e) {
      if (isClosed || gen != _amenityGeneration) return;
      emit(state.copyWith(errorMessage: e.message));
    } catch (e) {
      if (isClosed || gen != _amenityGeneration) return;
      emit(state.copyWith(errorMessage: 'Lỗi cập nhật tiện ích: $e'));
    }
  }

  Future<void> downloadDocument(String documentId) async {
    emit(state.copyWith(clearDownload: true));
    try {
      final grant = await _propertyRepository.requestDownload(
        propertyId,
        documentId,
      );
      emit(state.copyWith(downloadGrant: grant));
    } on XlandFailure catch (e) {
      emit(state.copyWith(downloadError: e.message));
    } catch (e) {
      emit(state.copyWith(downloadError: 'Lỗi tải tài liệu: $e'));
    }
  }

  Future<ShareLink?> getShareLink() async {
    try {
      return await _propertyRepository.getShareLink(propertyId);
    } on XlandFailure catch (e) {
      emit(state.copyWith(errorMessage: e.message));
      return null;
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Lỗi chia sẻ: $e'));
      return null;
    }
  }

  Future<void> toggleSaved() async {
    if (state.property == null) return;
    final newSaved = !state.property!.isSaved;
    try {
      final res = await _propertyRepository.setSaved(propertyId, newSaved);
      final current = state.property!;
      final updatedProperty = Property(
        id: current.id,
        code: current.code,
        title: current.title,
        provinceCode: current.provinceCode,
        provinceName: current.provinceName,
        districtCode: current.districtCode,
        districtName: current.districtName,
        region: current.region,
        category: current.category,
        priceTotal: current.priceTotal,
        pricePerM2: current.pricePerM2,
        areaM2: current.areaM2,
        frontageM: current.frontageM,
        depthM: current.depthM,
        roadWidthM: current.roadWidthM,
        direction: current.direction,
        landType: current.landType,
        status: current.status,
        approvalStatus: current.approvalStatus,
        sourceBadge: current.sourceBadge,
        consultantId: current.consultantId,
        media: current.media,
        highlights: current.highlights,
        verifiedLegalCount: current.verifiedLegalCount,
        totalLegalCount: current.totalLegalCount,
        isSaved: res.active,
        updatedAt: current.updatedAt,
        isIllustrative: current.isIllustrative,
      );
      emit(state.copyWith(property: updatedProperty, clearError: true));
    } on XlandFailure catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Lỗi lưu bất động sản: $e'));
    }
  }
}
