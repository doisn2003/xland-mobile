import 'package:flutter/foundation.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

@immutable
class PropertyDetailState {
  const PropertyDetailState({
    required this.propertyId,
    this.property,
    this.legalSummary,
    this.areaInfo,
    this.consultant,
    this.selectedAmenityCategory,
    this.activeTab = 0,
    this.activeMediaIndex = 0,
    this.isLoading = true,
    this.errorMessage,
    this.downloadGrant,
    this.downloadError,
  });

  final String propertyId;
  final Property? property;
  final LegalSummary? legalSummary;
  final AreaInfo? areaInfo;
  final Consultant? consultant;
  final AmenityCategory? selectedAmenityCategory;
  final int activeTab; // 0: Tổng quan, 1: Pháp lý, 2: Khu vực, 3: Tài chính
  final int activeMediaIndex;
  final bool isLoading;
  final String? errorMessage;
  final DownloadGrant? downloadGrant;
  final String? downloadError;

  PropertyDetailState copyWith({
    String? propertyId,
    Property? property,
    LegalSummary? legalSummary,
    AreaInfo? areaInfo,
    Consultant? consultant,
    AmenityCategory? selectedAmenityCategory,
    bool clearAmenityCategory = false,
    int? activeTab,
    int? activeMediaIndex,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    DownloadGrant? downloadGrant,
    String? downloadError,
    bool clearDownload = false,
  }) {
    return PropertyDetailState(
      propertyId: propertyId ?? this.propertyId,
      property: property ?? this.property,
      legalSummary: legalSummary ?? this.legalSummary,
      areaInfo: areaInfo ?? this.areaInfo,
      consultant: consultant ?? this.consultant,
      selectedAmenityCategory: clearAmenityCategory
          ? null
          : (selectedAmenityCategory ?? this.selectedAmenityCategory),
      activeTab: activeTab ?? this.activeTab,
      activeMediaIndex: activeMediaIndex ?? this.activeMediaIndex,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      downloadGrant: clearDownload ? null : (downloadGrant ?? this.downloadGrant),
      downloadError: clearDownload ? null : (downloadError ?? this.downloadError),
    );
  }
}
