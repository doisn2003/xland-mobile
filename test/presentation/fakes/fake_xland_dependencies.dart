import 'package:xland_mobile/domain/xland_domain.dart';

/// Test doubles (Fakes) implementing all 10 domain repository interfaces.
/// Backed by canonical fixtures v0.1 with in-memory mutations and full filter logic.

class FakePropertyRepository implements PropertyRepository {
  FakePropertyRepository({List<Property>? initialProperties}) {
    if (initialProperties != null) {
      _canonicalProperties.addAll(initialProperties);
    } else {
      _initCanonicalProperties();
    }
  }

  final List<Property> _canonicalProperties = [];
  final Set<String> _savedIds = <String>{};

  static final Property sampleProperty = Property(
    id: '00000000-0000-4000-8000-000000000005',
    code: 'XL-028',
    title: 'Đất nền Hòa Lạc',
    provinceCode: '01',
    provinceName: 'Hà Nội',
    districtCode: 'demo-hoa-lac',
    districtName: 'Khu vực Hòa Lạc',
    region: Region.north,
    category: PropertyCategory.residential,
    priceTotal: Vnd.fromInt(2400000000),
    pricePerM2: Vnd.fromInt(20000000),
    areaM2: DecimalValue('120'),
    frontageM: DecimalValue('6'),
    depthM: DecimalValue('20'),
    roadWidthM: DecimalValue('5'),
    direction: 'southeast',
    landType: LandType.residential,
    status: PropertyStatus.listed,
    approvalStatus: ApprovalStatus.approved,
    sourceBadge: SourceBadge.boardSource,
    consultantId: '00000000-0000-4000-8000-000000000003',
    media: const [
      MediaAsset(
        id: 'm-028-1',
        kind: MediaKind.image,
        altText: 'Ảnh thực địa lô đất XL-028',
        isIllustrative: true,
      ),
    ],
    highlights: const [
      Highlight(
        title: 'Mặt tiền rộng',
        description: 'Mặt tiền 6m đường nhựa 2 ô tô tránh nhau thoải mái',
      ),
      Highlight(
        title: 'Pháp lý an toàn',
        description: 'Sổ đỏ chính chủ, full thổ cư, không tranh chấp quy hoạch',
      ),
    ],
    verifiedLegalCount: 4,
    totalLegalCount: 6,
    isSaved: false,
    updatedAt: DateTime.utc(2026, 10, 16),
    isIllustrative: true,
  );

  void _initCanonicalProperties() {
    // XL-028
    _canonicalProperties.add(sampleProperty);

    // XL-029
    _canonicalProperties.add(
      Property(
        id: '00000000-0000-4000-8000-000000000035',
        code: 'XL-029',
        title: 'Đất nền Hưng Yên',
        provinceCode: '33',
        provinceName: 'Hưng Yên',
        districtCode: 'demo-33',
        districtName: 'Khu vực Hưng Yên',
        region: Region.north,
        category: PropertyCategory.residential,
        priceTotal: Vnd.fromInt(1800000000),
        pricePerM2: Vnd.fromInt(18000000),
        areaM2: DecimalValue('100'),
        frontageM: DecimalValue('5'),
        depthM: DecimalValue('20'),
        roadWidthM: DecimalValue('4'),
        direction: 'east',
        landType: LandType.residential,
        status: PropertyStatus.listed,
        approvalStatus: ApprovalStatus.approved,
        sourceBadge: SourceBadge.boardSource,
        consultantId: '00000000-0000-4000-8000-000000000003',
        media: const [],
        highlights: const [],
        verifiedLegalCount: 0,
        totalLegalCount: 0,
        isSaved: false,
        updatedAt: DateTime.utc(2026, 10, 15, 2),
        isIllustrative: true,
      ),
    );

    // XL-030
    _canonicalProperties.add(
      Property(
        id: '00000000-0000-4000-8000-000000000036',
        code: 'XL-030',
        title: 'Đất nền Bắc Ninh',
        provinceCode: '27',
        provinceName: 'Bắc Ninh',
        districtCode: 'demo-27',
        districtName: 'Khu vực Bắc Ninh',
        region: Region.north,
        category: PropertyCategory.residential,
        priceTotal: Vnd.fromInt(3000000000),
        pricePerM2: Vnd.fromInt(20000000),
        areaM2: DecimalValue('150'),
        frontageM: DecimalValue('7.5'),
        depthM: DecimalValue('20'),
        roadWidthM: DecimalValue('6'),
        direction: 'south',
        landType: LandType.residential,
        status: PropertyStatus.listed,
        approvalStatus: ApprovalStatus.approved,
        sourceBadge: SourceBadge.boardSource,
        consultantId: '00000000-0000-4000-8000-000000000003',
        media: const [],
        highlights: const [],
        verifiedLegalCount: 0,
        totalLegalCount: 0,
        isSaved: false,
        updatedAt: DateTime.utc(2026, 10, 15, 2),
        isIllustrative: true,
      ),
    );

    // XL-031
    _canonicalProperties.add(
      Property(
        id: '00000000-0000-4000-8000-000000000037',
        code: 'XL-031',
        title: 'Đất nền Đà Nẵng',
        provinceCode: '48',
        provinceName: 'Đà Nẵng',
        districtCode: 'demo-48',
        districtName: 'Khu vực Đà Nẵng',
        region: Region.central,
        category: PropertyCategory.residential,
        priceTotal: Vnd.fromInt(2700000000),
        pricePerM2: Vnd.fromInt(27000000),
        areaM2: DecimalValue('100'),
        frontageM: DecimalValue('5'),
        depthM: DecimalValue('20'),
        roadWidthM: DecimalValue('5.5'),
        direction: 'north',
        landType: LandType.residential,
        status: PropertyStatus.listed,
        approvalStatus: ApprovalStatus.approved,
        sourceBadge: SourceBadge.boardSource,
        consultantId: '00000000-0000-4000-8000-000000000003',
        media: const [],
        highlights: const [],
        verifiedLegalCount: 0,
        totalLegalCount: 0,
        isSaved: false,
        updatedAt: DateTime.utc(2026, 10, 15, 2),
        isIllustrative: true,
      ),
    );

    // Additional properties to reach 25 items for paging tests
    for (int i = 5; i <= 25; i++) {
      final code = 'XL-${i.toString().padLeft(3, '0')}';
      final id = '00000000-0000-4000-8000-0000000000${i.toString().padLeft(2, '0')}';
      _canonicalProperties.add(
        Property(
          id: id,
          code: code,
          title: 'Lô đất mẫu $code',
          provinceCode: '01',
          provinceName: 'Hà Nội',
          districtCode: 'demo-hoa-lac',
          districtName: 'Khu vực Hòa Lạc',
          region: Region.north,
          category: PropertyCategory.residential,
          priceTotal: Vnd.fromInt(2000000000 + i * 50000000),
          pricePerM2: Vnd.fromInt(20000000),
          areaM2: DecimalValue('120'),
          frontageM: DecimalValue('6'),
          depthM: DecimalValue('20'),
          roadWidthM: DecimalValue('5'),
          direction: 'southeast',
          landType: LandType.residential,
          status: PropertyStatus.listed,
          approvalStatus: ApprovalStatus.approved,
          sourceBadge: SourceBadge.boardSource,
          consultantId: '00000000-0000-4000-8000-000000000003',
          media: const [],
          highlights: const [],
          verifiedLegalCount: 4,
          totalLegalCount: 6,
          isSaved: false,
          updatedAt: DateTime.utc(2026, 10, 16),
          isIllustrative: true,
        ),
      );
    }
  }

  List<Property> _filter(PropertyFilter filter) {
    return _canonicalProperties.where((p) {
      // Query
      if (filter.query != null && filter.query!.trim().isNotEmpty) {
        final q = filter.query!.trim().toLowerCase();
        final matchTitle = p.title.toLowerCase().contains(q);
        final matchCode = p.code.toLowerCase().contains(q);
        final matchProvince = p.provinceName.toLowerCase().contains(q);
        final matchDistrict = p.districtName.toLowerCase().contains(q);
        if (!matchTitle && !matchCode && !matchProvince && !matchDistrict) return false;
      }
      // Saved only
      if (filter.savedOnly && !_savedIds.contains(p.id)) {
        return false;
      }
      // Region
      if (filter.regions.isNotEmpty && !filter.regions.contains(p.region)) {
        return false;
      }
      // Category
      if (filter.category != null && p.category != filter.category) {
        return false;
      }
      // Province
      if (filter.provinceCode != null && filter.provinceCode!.trim().isNotEmpty && p.provinceCode != filter.provinceCode) {
        return false;
      }
      // District
      if (filter.districtCode != null && filter.districtCode!.trim().isNotEmpty && p.districtCode != filter.districtCode) {
        return false;
      }
      // Min price
      if (filter.minPriceVnd != null && p.priceTotal.amount < filter.minPriceVnd!.amount) {
        return false;
      }
      // Max price
      if (filter.maxPriceVnd != null && p.priceTotal.amount > filter.maxPriceVnd!.amount) {
        return false;
      }
      // Area bands
      if (filter.areaBands.isNotEmpty) {
        final areaVal = double.tryParse(p.areaM2.wireValue) ?? 0.0;
        final matchBand = filter.areaBands.any((b) {
          switch (b) {
            case AreaBand.below100:
              return areaVal < 100.0;
            case AreaBand.from100To200:
              return areaVal >= 100.0 && areaVal <= 200.0;
            case AreaBand.above200:
              return areaVal > 200.0;
          }
        });
        if (!matchBand) return false;
      }
      // Land type
      if (filter.landTypes.isNotEmpty && !filter.landTypes.contains(p.landType)) {
        return false;
      }
      // Road width
      if (filter.minRoadWidthM != null) {
        final roadVal = double.tryParse(p.roadWidthM?.wireValue ?? '0') ?? 0.0;
        final minRoad = double.tryParse(filter.minRoadWidthM!.wireValue) ?? 0.0;
        if (roadVal < minRoad) return false;
      }
      // Documents
      if (filter.hasDocuments != null) {
        final hasDocs = p.verifiedLegalCount > 0;
        if (hasDocs != filter.hasDocuments) return false;
      }
      return true;
    }).map((p) {
      // Sync saved state
      final isSaved = _savedIds.contains(p.id);
      if (isSaved == p.isSaved) return p;
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
        isSaved: isSaved,
        updatedAt: p.updatedAt,
        isIllustrative: p.isIllustrative,
      );
    }).toList();
  }

  int _computeCriteriaCount(PropertyFilter filter) {
    int count = 0;
    if (filter.query != null && filter.query!.trim().isNotEmpty) count++;
    if (filter.regions.isNotEmpty) count++;
    if (filter.category != null) count++;
    if (filter.provinceCode != null && filter.provinceCode!.trim().isNotEmpty) count++;
    if (filter.districtCode != null && filter.districtCode!.trim().isNotEmpty) count++;
    if (filter.minPriceVnd != null || filter.maxPriceVnd != null) count++;
    if (filter.areaBands.isNotEmpty) count++;
    if (filter.landTypes.isNotEmpty) count++;
    if (filter.minRoadWidthM != null) count++;
    if (filter.hasDocuments != null) count++;
    return count;
  }

  @override
  Future<PropertySearchResult> search(PropertyFilter filter, PageQuery page) async {
    final filtered = _filter(filter);
    final limit = page.limit;
    final int offset;
    if (page.cursor != null) {
      offset = int.tryParse(page.cursor!) ?? 0;
    } else {
      offset = 0;
    }

    final pagedItems = filtered.skip(offset).take(limit).toList();
    final nextOffset = offset + pagedItems.length;
    final hasMore = nextOffset < filtered.length;
    final nextCursor = hasMore ? nextOffset.toString() : null;

    return PropertySearchResult(
      page: Page<Property>(
        items: pagedItems,
        nextCursor: nextCursor,
        hasMore: hasMore,
        total: filtered.length,
      ),
      total: filtered.length,
      selectedCriteriaCount: _computeCriteriaCount(filter),
    );
  }

  @override
  Future<int> count(PropertyFilter filter) async {
    return _filter(filter).length;
  }

  @override
  Future<FilterCatalog> getFilterCatalog({String? provinceCode}) async {
    const allDistricts = [
      FilterOption(code: 'demo-hoa-lac', label: 'Khu vực Hòa Lạc', parentCode: '01'),
      FilterOption(code: 'demo-33', label: 'Khu vực Hưng Yên', parentCode: '33'),
      FilterOption(code: 'demo-27', label: 'Khu vực Bắc Ninh', parentCode: '27'),
      FilterOption(code: 'demo-48', label: 'Khu vực Đà Nẵng', parentCode: '48'),
    ];
    final districts = provinceCode != null
        ? allDistricts.where((d) => d.parentCode == provinceCode).toList()
        : allDistricts;

    return FilterCatalog(
      provinces: const [
        FilterOption(code: '01', label: 'Hà Nội'),
        FilterOption(code: '33', label: 'Hưng Yên'),
        FilterOption(code: '27', label: 'Bắc Ninh'),
        FilterOption(code: '48', label: 'Đà Nẵng'),
      ],
      districts: districts,
      minBudgetVnd: Vnd.fromInt(500000000),
      openUpperBudgetVnd: Vnd.fromInt(10000000000),
    );
  }

  @override
  Future<Property> getProperty(String propertyId) async {
    final item = _canonicalProperties.firstWhere(
      (p) => p.id == propertyId || p.code == propertyId,
      orElse: () => throw const XlandFailure.notFound(message: 'Property not found in fake'),
    );
    final isSaved = _savedIds.contains(item.id);
    if (isSaved == item.isSaved) return item;
    return Property(
      id: item.id,
      code: item.code,
      title: item.title,
      provinceCode: item.provinceCode,
      provinceName: item.provinceName,
      districtCode: item.districtCode,
      districtName: item.districtName,
      region: item.region,
      category: item.category,
      priceTotal: item.priceTotal,
      pricePerM2: item.pricePerM2,
      areaM2: item.areaM2,
      frontageM: item.frontageM,
      depthM: item.depthM,
      roadWidthM: item.roadWidthM,
      direction: item.direction,
      landType: item.landType,
      status: item.status,
      approvalStatus: item.approvalStatus,
      sourceBadge: item.sourceBadge,
      consultantId: item.consultantId,
      media: item.media,
      highlights: item.highlights,
      verifiedLegalCount: item.verifiedLegalCount,
      totalLegalCount: item.totalLegalCount,
      isSaved: isSaved,
      updatedAt: item.updatedAt,
      isIllustrative: item.isIllustrative,
    );
  }

  @override
  Future<LegalSummary> getLegal(String propertyId) async {
    return const LegalSummary(
      propertyId: '00000000-0000-4000-8000-000000000005',
      verifiedCount: 4,
      totalCount: 6,
      items: [
        LegalItem(
          id: '00000000-0000-4000-8000-000000000038',
          propertyId: '00000000-0000-4000-8000-000000000005',
          title: 'Giấy chứng nhận',
          checkedDate: '2026-09-10',
          status: LegalStatus.verified,
          sortOrder: 1,
        ),
        LegalItem(
          id: '00000000-0000-4000-8000-000000000039',
          propertyId: '00000000-0000-4000-8000-000000000005',
          title: 'Người có quyền bán',
          checkedDate: '2026-09-10',
          status: LegalStatus.verified,
          sortOrder: 2,
        ),
        LegalItem(
          id: '00000000-0000-4000-8000-000000000040',
          propertyId: '00000000-0000-4000-8000-000000000005',
          title: 'Thông tin thửa đất',
          checkedDate: '2026-09-09',
          status: LegalStatus.verified,
          sortOrder: 3,
        ),
        LegalItem(
          id: '00000000-0000-4000-8000-000000000041',
          propertyId: '00000000-0000-4000-8000-000000000005',
          title: 'Hiện trạng tiếp cận',
          checkedDate: '2026-09-09',
          status: LegalStatus.verified,
          sortOrder: 4,
        ),
        LegalItem(
          id: '00000000-0000-4000-8000-000000000042',
          propertyId: '00000000-0000-4000-8000-000000000005',
          title: 'Thông tin quy hoạch',
          status: LegalStatus.pending,
          sortOrder: 5,
        ),
        LegalItem(
          id: '00000000-0000-4000-8000-000000000043',
          propertyId: '00000000-0000-4000-8000-000000000005',
          title: 'Hạn chế giao dịch',
          status: LegalStatus.pending,
          sortOrder: 6,
        ),
      ],
      documents: [
        PropertyDocument(
          id: '00000000-0000-4000-8000-000000000044',
          propertyId: '00000000-0000-4000-8000-000000000005',
          title: 'Bản chụp giấy tờ',
          mimeType: 'application/pdf',
          sizeBytes: 2300000,
          uploadedDate: '2026-09-10',
          access: DocumentAccess.granted,
          canDownload: false,
        ),
        PropertyDocument(
          id: '00000000-0000-4000-8000-000000000045',
          propertyId: '00000000-0000-4000-8000-000000000005',
          title: 'Ảnh hiện trạng',
          mimeType: 'image/jpeg',
          sizeBytes: 4100000,
          uploadedDate: '2026-09-10',
          access: DocumentAccess.publicRedacted,
          canDownload: true,
        ),
      ],
      scopeNotice: 'Phạm vi kiểm tra pháp lý mang tính chất tham khảo minh họa.',
    );
  }

  @override
  Future<DownloadGrant> requestDownload(String propertyId, String documentId) async {
    return DownloadGrant(
      url: Uri.parse('https://xland.vn/downloads/$documentId'),
      fileName: 'tailieu_$documentId.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 2300000,
      expiresAt: DateTime.utc(2026, 10, 16, 23, 59, 59),
    );
  }

  @override
  Future<AreaInfo> getArea(String propertyId, {AmenityCategory? category}) async {
    const allAmenities = [
      Amenity(
        id: '00000000-0000-4000-8000-000000000046',
        propertyId: '00000000-0000-4000-8000-000000000005',
        category: AmenityCategory.utility,
        name: 'Trường học',
        distanceText: '1 - 3 km',
        iconType: 'school',
      ),
      Amenity(
        id: '00000000-0000-4000-8000-000000000047',
        propertyId: '00000000-0000-4000-8000-000000000005',
        category: AmenityCategory.utility,
        name: 'Cơ sở y tế',
        distanceText: '2 - 5 km',
        iconType: 'hospital',
      ),
      Amenity(
        id: '00000000-0000-4000-8000-000000000048',
        propertyId: '00000000-0000-4000-8000-000000000005',
        category: AmenityCategory.living,
        name: 'Chợ và siêu thị',
        distanceText: '1 - 3 km',
        iconType: 'market',
      ),
      Amenity(
        id: '00000000-0000-4000-8000-000000000049',
        propertyId: '00000000-0000-4000-8000-000000000005',
        category: AmenityCategory.traffic,
        name: 'Trục giao thông chính',
        distanceText: '2 - 4 km',
        iconType: 'road',
      ),
    ];

    final filtered = category == null
        ? allAmenities
        : allAmenities.where((a) => a.category == category).toList();

    return AreaInfo(
      propertyId: propertyId,
      location: const ApproximateLocation(
        latitude: 21.0123,
        longitude: 105.5342,
        radiusM: 1000,
        label: 'Vị trí gần đúng (Bán kính 1km)',
      ),
      amenities: filtered,
      photos: const [
        MediaAsset(
          id: 'photo-area-1',
          kind: MediaKind.image,
          altText: 'Không gian khu dân cư xung quanh',
          isIllustrative: true,
        ),
        MediaAsset(
          id: 'photo-area-2',
          kind: MediaKind.image,
          altText: 'Trục đường chính kết nối',
          isIllustrative: true,
        ),
      ],
      providerAttribution: 'Dữ liệu bản đồ minh họa (c) OpenStreetMap contributors',
    );
  }

  @override
  Future<MutationResult> setSaved(String propertyId, bool saved) async {
    if (saved) {
      _savedIds.add(propertyId);
    } else {
      _savedIds.remove(propertyId);
    }
    return MutationResult(active: saved);
  }

  @override
  Future<ShareLink> getShareLink(String propertyId) async {
    return ShareLink(
      url: Uri.parse('https://xland.vn/properties/$propertyId'),
      title: 'Xem lô đất trên XLand',
    );
  }
}

class FakeFeedRepository implements FeedRepository {
  FakeFeedRepository() {
    _videos = [
      FeedVideo(
        id: 'feed-001',
        propertyId: '00000000-0000-4000-8000-000000000005',
        author: const PublicAuthor(
          id: 'auth-01',
          displayName: 'Chuyên viên XLand',
          isVerified: true,
          isFollowing: false,
        ),
        media: MediaAsset(
          id: 'm-v-01',
          kind: MediaKind.video,
          url: Uri.parse('http://127.0.0.1:5560/demo-video.mp4'),
          durationSeconds: 4,
          altText: 'Video thực địa Hòa Lạc XL-005',
          isIllustrative: true,
        ),
        caption: 'Đất nền KCN Hòa Lạc — Vị trí kim cương, sổ đỏ sẵn sàng',
        approximateArea: 'Hòa Lạc, Thạch Thất, Hà Nội',
        property: FakePropertyRepository.sampleProperty,
        likeCount: 42,
        commentCount: 5,
        viewCount: 1250,
        isLiked: false,
        isSaved: false,
        publishedAt: DateTime.utc(2026, 10, 16),
        isIllustrative: true,
      ),
      FeedVideo(
        id: 'feed-002',
        propertyId: '00000000-0000-4000-8000-000000000006',
        author: const PublicAuthor(
          id: 'auth-02',
          displayName: 'Minh Tuấn BĐS',
          isVerified: true,
          isFollowing: true,
        ),
        media: MediaAsset(
          id: 'm-v-02',
          kind: MediaKind.video,
          url: Uri.parse('http://127.0.0.1:5560/demo-video.mp4'),
          durationSeconds: 4,
          altText: 'Video thực địa Lô XL-006',
          isIllustrative: true,
        ),
        caption: 'Lô đất mẫu XL-006 — Cơ hội đầu tư sinh lời cao ven KCN',
        approximateArea: 'Hòa Lạc, Thạch Thất, Hà Nội',
        property: Property(
          id: '00000000-0000-4000-8000-000000000006',
          code: 'XL-006',
          title: 'Lô đất mẫu XL-006',
          provinceCode: '01',
          provinceName: 'Hà Nội',
          districtCode: 'demo-hoa-lac',
          districtName: 'Khu vực Hòa Lạc',
          region: Region.north,
          category: PropertyCategory.residential,
          priceTotal: Vnd('2300000000'),
          pricePerM2: Vnd('20000000'),
          areaM2: DecimalValue('115'),
          frontageM: DecimalValue('5'),
          depthM: DecimalValue('23'),
          roadWidthM: DecimalValue('5'),
          direction: 'east',
          landType: LandType.residential,
          status: PropertyStatus.listed,
          approvalStatus: ApprovalStatus.approved,
          sourceBadge: SourceBadge.boardSource,
          consultantId: '00000000-0000-4000-8000-000000000003',
          media: const [],
          highlights: const [],
          verifiedLegalCount: 4,
          totalLegalCount: 6,
          isSaved: true,
          updatedAt: DateTime.utc(2026, 10, 16),
          isIllustrative: true,
        ),
        likeCount: 88,
        commentCount: 12,
        viewCount: 3400,
        isLiked: true,
        isSaved: true,
        publishedAt: DateTime.utc(2026, 10, 15),
        isIllustrative: true,
      ),
    ];
  }

  late List<FeedVideo> _videos;
  final Set<String> _likedIds = {'feed-002'};
  final Set<String> _savedIds = {'feed-002'};
  final Set<String> _followingAuthors = {'auth-02'};

  @override
  Future<Page<FeedVideo>> getFeed(
    PageQuery page, {
    FeedScope feedScope = FeedScope.recommended,
    Region? region,
    PropertyCategory? category,
  }) async {
    final list = _videos.map((v) {
      final isLiked = _likedIds.contains(v.id);
      final isSaved = _savedIds.contains(v.id);
      final isFollowing = _followingAuthors.contains(v.author.id);
      return FeedVideo(
        id: v.id,
        propertyId: v.propertyId,
        author: PublicAuthor(
          id: v.author.id,
          displayName: v.author.displayName,
          avatarUrl: v.author.avatarUrl,
          role: v.author.role,
          isVerified: v.author.isVerified,
          isFollowing: isFollowing,
        ),
        media: v.media,
        caption: v.caption,
        approximateArea: v.approximateArea,
        property: v.property,
        likeCount: isLiked ? (v.isLiked ? v.likeCount : v.likeCount + 1) : (v.isLiked ? v.likeCount - 1 : v.likeCount),
        commentCount: v.commentCount,
        viewCount: v.viewCount,
        isLiked: isLiked,
        isSaved: isSaved,
        publishedAt: v.publishedAt,
        isIllustrative: v.isIllustrative,
      );
    }).toList();
    return Page<FeedVideo>(items: list, nextCursor: null, hasMore: false, total: list.length);
  }

  @override
  Future<FeedVideo> getVideo(String videoId) async {
    final v = _videos.where((v) => v.id == videoId).firstOrNull;
    if (v == null) {
      throw const XlandFailure.notFound(message: 'Video not found in fake');
    }
    return v;
  }

  @override
  Future<Page<FeedVideo>> getSavedVideos(PageQuery page) async {
    final saved = _videos.where((v) => _savedIds.contains(v.id)).toList();
    return Page<FeedVideo>(items: saved, nextCursor: null, hasMore: false, total: saved.length);
  }

  @override
  Future<AuthorProfile> getAuthorProfile(String authorId) async {
    final videos = _videos.where((v) => v.author.id == authorId).toList();
    if (videos.isEmpty) {
      throw const XlandFailure.notFound(message: 'Không tìm thấy người đăng');
    }
    final author = videos.first.author;
    return AuthorProfile(
      author: PublicAuthor(
        id: author.id, displayName: author.displayName, role: author.role,
        avatarUrl: author.avatarUrl, isVerified: author.isVerified,
        isFollowing: _followingAuthors.contains(authorId),
      ),
      videoCount: videos.length,
      followerCount: _followingAuthors.contains(authorId) ? 1 : 0,
      isIllustrative: videos.first.isIllustrative,
    );
  }

  @override
  Future<Page<FeedVideo>> getAuthorVideos(String authorId, PageQuery page) async {
    final videos = _videos.where((v) => v.author.id == authorId).toList();
    return Page(items: videos, hasMore: false, total: videos.length);
  }

  @override
  Future<MutationResult> setLiked(String videoId, bool liked) async {
    if (liked) {
      _likedIds.add(videoId);
    } else {
      _likedIds.remove(videoId);
    }
    return MutationResult(active: liked);
  }

  @override
  Future<MutationResult> setSaved(String videoId, bool saved) async {
    if (saved) {
      _savedIds.add(videoId);
    } else {
      _savedIds.remove(videoId);
    }
    return MutationResult(active: saved);
  }

  @override
  Future<Page<VideoComment>> getComments(String videoId, PageQuery page) async {
    final comments = [
      VideoComment(
        id: 'c-1',
        videoId: 'feed-001',
        author: const PublicAuthor(id: 'u-1', displayName: 'Tuấn Anh', isVerified: false, isFollowing: false),
        text: 'Lô này quy hoạch có vướng hành lang không chuyên viên?',
        createdAt: DateTime.utc(2026, 10, 16),
        canDelete: false,
      ),
      VideoComment(
        id: 'c-2',
        videoId: 'feed-001',
        author: const PublicAuthor(id: 'u-2', displayName: 'Hương Mai', isVerified: true, isFollowing: true),
        text: 'Vị trí này gần đại học FPT không ạ?',
        createdAt: DateTime.utc(2026, 10, 16),
        canDelete: false,
      ),
    ];
    return Page<VideoComment>(items: comments, nextCursor: null, hasMore: false, total: 2);
  }

  @override
  Future<VideoComment> addComment(String videoId, String text, {required String idempotencyKey}) async {
    return VideoComment(
      id: 'c-${DateTime.now().millisecondsSinceEpoch}',
      videoId: videoId,
      author: const PublicAuthor(id: 'me', displayName: 'Tôi', isVerified: false, isFollowing: false),
      text: text,
      createdAt: DateTime.now().toUtc(),
      canDelete: true,
    );
  }

  @override
  Future<void> deleteComment(String videoId, String commentId) async {}

  @override
  Future<MutationResult> setFollowing(String authorId, bool following) async {
    if (following) {
      _followingAuthors.add(authorId);
    } else {
      _followingAuthors.remove(authorId);
    }
    return MutationResult(active: following);
  }

  @override
  Future<Page<PublicAuthor>> getFollowing(PageQuery page) async {
    return const Page<PublicAuthor>(items: [], nextCursor: null, hasMore: false, total: 0);
  }

  @override
  Future<ShareLink> getShareLink(String videoId) async {
    return ShareLink(
      url: Uri.parse('https://xland.vn/videos/$videoId'),
      title: 'Xem video trên XLand',
    );
  }
}

class FakeConsultantRepository implements ConsultantRepository {
  final Consultant _consultant = Consultant(
    id: '00000000-0000-4000-8000-000000000030',
    name: 'Minh Anh',
    role: 'Chuyên viên tư vấn đất nền KCN & Tái định cư',
    location: 'Hà Nội & Vùng ven',
    isVerified: true,
    videoCount: 14,
    followerCount: 1250,
    rating: DecimalValue('4.9'),
    isFollowing: false,
    nextAvailableAt: DateTime.utc(2026, 10, 20, 9, 0),
    supportRecipientLabel: 'Đội ngũ hỗ trợ thực địa XLand',
    isIllustrative: true,
  );

  @override
  Future<Consultant> getConsultant(String consultantId) async {
    return _consultant;
  }

  @override
  Future<Page<FeedVideo>> getVideos(String consultantId, PageQuery page) async {
    final v = FeedVideo(
      id: 'vid-01',
      propertyId: '00000000-0000-4000-8000-000000000005',
      author: PublicAuthor(
        id: consultantId,
        displayName: 'Minh Anh',
        role: 'Tư vấn đất nền',
        isVerified: true,
        isFollowing: false,
      ),
      media: const MediaAsset(
        id: 'media-vid-01',
        kind: MediaKind.video,
        altText: 'Video khảo sát Hòa Lạc',
        isIllustrative: true,
      ),
      caption: 'Khảo sát thực địa đất nền phân lô Hòa Lạc, pháp lý minh bạch 100%',
      approximateArea: 'Thạch Thất, Hà Nội',
      property: FakePropertyRepository.sampleProperty,
      likeCount: 128,
      commentCount: 24,
      viewCount: 1540,
      isLiked: false,
      isSaved: false,
      publishedAt: DateTime.utc(2026, 10, 10),
      isIllustrative: true,
    );
    return Page<FeedVideo>(items: [v], nextCursor: null, hasMore: false, total: 1);
  }

  @override
  Future<Page<Property>> getListings(String consultantId, PageQuery page) async {
    return Page<Property>(
      items: [FakePropertyRepository.sampleProperty],
      nextCursor: null,
      hasMore: false,
      total: 1,
    );
  }

  @override
  Future<Page<ConsultantReview>> getReviews(String consultantId, PageQuery page) async {
    return const Page<ConsultantReview>(items: [], nextCursor: null, hasMore: false, total: 0);
  }

  @override
  Future<List<AvailabilitySlot>> getAvailability(String consultantId, String fromDate, String toDate) async {
    return [
      AvailabilitySlot(
        id: 'slot-c1',
        propertyId: '00000000-0000-4000-8000-000000000005',
        consultantId: consultantId,
        startsAt: DateTime.utc(2026, 10, 20, 9, 0),
        endsAt: DateTime.utc(2026, 10, 20, 11, 0),
        timeZone: 'Asia/Ho_Chi_Minh',
        isAvailable: true,
        meetingArea: const ApproximateLocation(
          latitude: 21.01,
          longitude: 105.53,
          radiusM: 500,
          label: 'UBND Xã Tân Xã',
        ),
        maxAttendees: 5,
      ),
    ];
  }
}

class FakeEventRepository implements EventRepository {
  static final XlandEvent _canonicalEvent = XlandEvent(
    id: '00000000-0000-4000-8000-000000000015',
    title: 'Tọa đàm đầu tư đất nền vùng ven & KCN công nghệ cao Hòa Lạc 2026',
    tags: const ['Tọa đàm', 'Đất nền', 'Pháp lý'],
    media: const [
      MediaAsset(id: 'm-ev-1', kind: MediaKind.image, altText: 'Banner sự kiện', isIllustrative: true),
    ],
    startsAt: DateTime.utc(2026, 10, 25, 8, 30),
    endsAt: DateTime.utc(2026, 10, 25, 11, 30),
    timeZone: 'Asia/Ho_Chi_Minh',
    venueName: 'Trung tâm Đổi mới Sáng tạo Quốc gia NIC Hòa Lạc',
    address: 'Khu CNC Hòa Lạc, Thạch Thất, Hà Nội',
    maxSlots: 50,
    remainingSlots: 15,
    durationMinutes: 180,
    ticketPriceVnd: Vnd('0'),
    status: EventStatus.open,
    agenda: [
      AgendaItem(startsAt: DateTime.utc(2026, 10, 25, 8, 30), title: 'Đón tiếp đại biểu & Check-in'),
      AgendaItem(startsAt: DateTime.utc(2026, 10, 25, 9, 0), title: 'Xu hướng quy hoạch & Pháp lý đất nền ven đô'),
      AgendaItem(startsAt: DateTime.utc(2026, 10, 25, 10, 30), title: 'Hỏi đáp trực tiếp cùng chuyên viên và luật sư'),
    ],
    speakers: const [
      Speaker(name: 'TS. Nguyễn Hữu Dũng', role: 'Viện trưởng Viện Nghiên cứu Đô thị'),
      Speaker(name: 'Minh Anh', role: 'Chuyên viên tư vấn thực địa XLand'),
    ],
    benefits: const [
      EventBenefit(title: 'Tài liệu quy hoạch độc quyền', description: 'Bản đồ quy hoạch 1/2000 khu vực Hòa Lạc cập nhật mới nhất'),
      EventBenefit(title: 'Tư vấn 1-1 miễn phí', description: 'Được trao đổi trực tiếp với luật sư chuyên trách pháp lý đất đai'),
    ],
    isSaved: false,
    isIllustrative: true,
  );

  static final XlandEvent _soldOutEvent = XlandEvent(
    id: '00000000-0000-4000-8000-000000000016',
    title: 'Hội thảo chuyên sâu: Thẩm định pháp lý sổ đỏ thực chiến',
    tags: const ['Hội thảo', 'Pháp lý'],
    media: const [
      MediaAsset(id: 'm-ev-2', kind: MediaKind.image, altText: 'Banner hội thảo', isIllustrative: true),
    ],
    startsAt: DateTime.utc(2026, 10, 28, 14, 0),
    endsAt: DateTime.utc(2026, 10, 28, 17, 0),
    timeZone: 'Asia/Ho_Chi_Minh',
    venueName: 'Khách sạn Daewoo Hà Nội',
    address: '360 Kim Mã, Ba Đình, Hà Nội',
    maxSlots: 30,
    remainingSlots: 0,
    durationMinutes: 180,
    ticketPriceVnd: Vnd('0'),
    status: EventStatus.soldOut,
    agenda: const [],
    speakers: const [],
    benefits: const [],
    isSaved: false,
    isIllustrative: true,
  );

  static String _canonicalizeId(String id) => switch (id) {
    'ev-001' => '00000000-0000-4000-8000-000000000015',
    'ev-sold-out' => '00000000-0000-4000-8000-000000000016',
    _ => id,
  };

  final Map<String, XlandEvent> _events = {
    '00000000-0000-4000-8000-000000000015': _canonicalEvent,
    '00000000-0000-4000-8000-000000000016': _soldOutEvent,
  };

  final Set<String> _savedEventIds = {};

  @override
  Future<Page<XlandEvent>> getEvents(PageQuery page, {EventStatus? status}) async {
    final list = _events.values
        .toSet()
        .where((e) => status == null || e.status == status)
        .toList();
    return Page<XlandEvent>(items: list, nextCursor: null, hasMore: false, total: list.length);
  }

  @override
  Future<XlandEvent> getEvent(String eventId) async {
    final ev = _events[_canonicalizeId(eventId)];
    if (ev == null) {
      throw const XlandFailure.notFound(message: 'Không tìm thấy sự kiện.');
    }
    return ev;
  }

  @override
  Future<MutationResult> setSaved(String eventId, bool saved) async {
    final id = _canonicalizeId(eventId);
    if (saved) {
      _savedEventIds.add(id);
    } else {
      _savedEventIds.remove(id);
    }
    return MutationResult(active: saved);
  }

  @override
  Future<Page<XlandEvent>> getSavedEvents(PageQuery page) async {
    final saved = _events.values.where((e) => _savedEventIds.contains(e.id)).toList();
    return Page<XlandEvent>(items: saved, nextCursor: null, hasMore: false, total: saved.length);
  }

  @override
  Future<EventRegistration> register(EventRegistrationInput input, {required String idempotencyKey}) async {
    final canonicalId = _canonicalizeId(input.eventId);
    final ev = _events[canonicalId];
    if (ev == null) {
      throw const XlandFailure.notFound(message: 'Sự kiện không tồn tại.');
    }
    if (ev.status == EventStatus.soldOut || ev.remainingSlots < input.attendeeCount) {
      throw const XlandFailure(
        code: FailureCode.soldOut,
        message: 'Sự kiện đã hết chỗ đăng ký hoặc không đủ số lượng vé yêu cầu.',
      );
    }
    _events[canonicalId] = XlandEvent(
      id: ev.id,
      title: ev.title,
      tags: ev.tags,
      media: ev.media,
      startsAt: ev.startsAt,
      endsAt: ev.endsAt,
      timeZone: ev.timeZone,
      venueName: ev.venueName,
      address: ev.address,
      maxSlots: ev.maxSlots,
      remainingSlots: ev.remainingSlots - input.attendeeCount,
      durationMinutes: ev.durationMinutes,
      ticketPriceVnd: ev.ticketPriceVnd,
      status: ev.remainingSlots - input.attendeeCount <= 0 ? EventStatus.soldOut : ev.status,
      agenda: ev.agenda,
      speakers: ev.speakers,
      benefits: ev.benefits,
      isSaved: ev.isSaved,
      isIllustrative: ev.isIllustrative,
    );

    return EventRegistration(
      id: 'reg-${DateTime.now().millisecondsSinceEpoch}',
      eventId: input.eventId,
      status: RegistrationStatus.registered,
      attendeeCount: input.attendeeCount,
      ticketPriceVnd: ev.ticketPriceVnd,
      paymentMode: PaymentMode.disabled,
      notice: 'Đăng ký thành công! Vé tham dự miễn phí đã được ghi nhận trong danh sách khách mời.',
      createdAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<Page<EventRegistration>> getRegistrations(PageQuery page) async {
    return const Page<EventRegistration>(items: [], nextCursor: null, hasMore: false, total: 0);
  }

  @override
  Future<ShareLink> getShareLink(String eventId) async {
    return ShareLink(
      url: Uri.parse('https://xland.vn/events/$eventId'),
      title: 'Tham gia sự kiện XLand',
    );
  }
}

class FakeBookingRepository implements BookingRepository {
  final List<Booking> _bookings = [];
  bool throwConflict = false;

  @override
  Future<List<AvailabilitySlot>> getAvailability(String propertyId, String fromDate, String toDate) async {
    return [
      AvailabilitySlot(
        id: 'slot-01',
        propertyId: propertyId,
        consultantId: '00000000-0000-4000-8000-000000000030',
        startsAt: DateTime.utc(2026, 10, 20, 9, 0),
        endsAt: DateTime.utc(2026, 10, 20, 11, 0),
        timeZone: 'Asia/Ho_Chi_Minh',
        isAvailable: true,
        meetingArea: const ApproximateLocation(
          latitude: 21.0123,
          longitude: 105.5342,
          radiusM: 500,
          label: 'UBND Xã Tân Xã (Cách lô đất 1km)',
        ),
        maxAttendees: 5,
      ),
      AvailabilitySlot(
        id: 'slot-02',
        propertyId: propertyId,
        consultantId: '00000000-0000-4000-8000-000000000030',
        startsAt: DateTime.utc(2026, 10, 20, 14, 0),
        endsAt: DateTime.utc(2026, 10, 20, 16, 0),
        timeZone: 'Asia/Ho_Chi_Minh',
        isAvailable: true,
        meetingArea: const ApproximateLocation(
          latitude: 21.0123,
          longitude: 105.5342,
          radiusM: 500,
          label: 'UBND Xã Tân Xã (Cách lô đất 1km)',
        ),
        maxAttendees: 5,
      ),
      AvailabilitySlot(
        id: 'slot-03-full',
        propertyId: propertyId,
        consultantId: '00000000-0000-4000-8000-000000000030',
        startsAt: DateTime.utc(2026, 10, 21, 2, 0),
        endsAt: DateTime.utc(2026, 10, 21, 4, 0),
        timeZone: 'Asia/Ho_Chi_Minh',
        isAvailable: false,
        unavailableReason: 'Đã kín lịch chuyên viên',
        meetingArea: const ApproximateLocation(
          latitude: 21.0123,
          longitude: 105.5342,
          radiusM: 500,
          label: 'UBND Xã Tân Xã',
        ),
        maxAttendees: 5,
      ),
    ];
  }

  @override
  Future<DepositPolicy> getDepositPolicy() async {
    return DepositPolicy(
      indicativeAmountVnd: Vnd('350000'),
      policyVersion: 'v1.0-pilot',
      chargeBasis: 'Mức cọc cam kết giữ chỗ chuyên viên hướng dẫn thực địa',
      refundPolicyText: null,
      cancellationPolicyText: null,
      reschedulePolicyText: null,
      livePaymentEnabled: false,
      notice: 'Mức cọc cam kết thực địa 350.000 VNĐ; cổng thanh toán đang tích hợp, chưa thu phí trực tiếp.',
    );
  }

  @override
  Future<Booking> create(BookingInput input, {required String idempotencyKey}) async {
    if (throwConflict || input.slotId == 'slot-03-full') {
      throw const XlandFailure(
        code: FailureCode.slotUnavailable,
        message: 'Khung giờ này vừa có khách đặt trước hoặc không khả dụng. Vui lòng chọn giờ khác.',
      );
    }

    final prop = FakePropertyRepository.sampleProperty;

    final booking = Booking(
      id: 'BK-${DateTime.now().millisecondsSinceEpoch}',
      propertyId: input.propertyId,
      slotId: input.slotId,
      property: prop,
      requestedStartsAt: DateTime.utc(2026, 10, 20, 9, 0),
      timeZone: 'Asia/Ho_Chi_Minh',
      proposedMeetingArea: const ApproximateLocation(
        latitude: 21.0123,
        longitude: 105.5342,
        radiusM: 500,
        label: 'UBND Xã Tân Xã',
      ),
      attendeeCount: input.attendeeCount,
      transportMode: input.transportMode,
      requestDocuments: input.requestDocuments,
      requestLoanAdvice: input.requestLoanAdvice,
      contactName: input.contactName,
      maskedContactPhone: input.contactPhone.length >= 4
          ? '${input.contactPhone.substring(0, 3)}****${input.contactPhone.substring(input.contactPhone.length - 3)}'
          : input.contactPhone,
      status: BookingStatus.awaitingDeposit,
      paymentStatus: PaymentStatus.unpaid,
      depositPolicy: await getDepositPolicy(),
      history: [
        BookingHistoryItem(
          id: 'hist-1',
          fromStatus: BookingStatus.draft,
          toStatus: BookingStatus.awaitingDeposit,
          occurredAt: DateTime.now().toUtc(),
          actorLabel: 'Khách hàng',
          publicNote: 'Tạo yêu cầu đặt lịch xem thực địa',
        ),
      ],
      availableActions: const [],
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
      isIllustrative: true,
    );

    _bookings.add(booking);
    return booking;
  }

  @override
  Future<Page<Booking>> getHistory(PageQuery page, {BookingStatus? status}) async {
    final list = _bookings.where((b) => status == null || b.status == status).toList();
    return Page<Booking>(
      items: List.unmodifiable(list),
      nextCursor: null,
      hasMore: false,
      total: list.length,
    );
  }

  @override
  Future<Booking> getBooking(String bookingId) async {
    final b = _bookings.where((b) => b.id == bookingId).firstOrNull;
    if (b != null) return b;
    if (bookingId.toUpperCase().startsWith('BK-') || bookingId.toLowerCase().startsWith('bk-')) {
      return Booking(
        id: bookingId,
        propertyId: FakePropertyRepository.sampleProperty.id,
        slotId: 'slot-01',
        property: FakePropertyRepository.sampleProperty,
        requestedStartsAt: DateTime.utc(2026, 10, 20, 9, 0),
        timeZone: 'Asia/Ho_Chi_Minh',
        proposedMeetingArea: const ApproximateLocation(
          latitude: 21.0123,
          longitude: 105.5342,
          radiusM: 500,
          label: 'UBND Xã Tân Xã',
        ),
        attendeeCount: 2,
        transportMode: TransportMode.selfArranged,
        requestDocuments: true,
        requestLoanAdvice: false,
        contactName: 'Nguyễn Văn A',
        maskedContactPhone: '090****567',
        status: BookingStatus.awaitingDeposit,
        paymentStatus: PaymentStatus.unpaid,
        depositPolicy: await getDepositPolicy(),
        history: [],
        availableActions: const ['cancel'],
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
        isIllustrative: true,
      );
    }
    throw const XlandFailure.notFound(message: 'Không tìm thấy lịch hẹn.');
  }

  @override
  Future<Booking> requestCancellation(String bookingId, BookingChangeInput input, {required String idempotencyKey}) async {
    throw const XlandFailure(
      code: FailureCode.policyNotConfigured,
      message: 'Policy not configured',
    );
  }

  @override
  Future<Booking> requestReschedule(String bookingId, BookingChangeInput input, {required String idempotencyKey}) async {
    throw const XlandFailure(
      code: FailureCode.policyNotConfigured,
      message: 'Policy not configured',
    );
  }
}

class FakePaymentRepository implements PaymentRepository {
  @override
  Future<Page<PaymentRecord>> getBookingPayments(String bookingId, PageQuery page) async {
    return const Page<PaymentRecord>(items: [], nextCursor: null, hasMore: false, total: 0);
  }

  @override
  Future<PaymentRecord> getPayment(String paymentId) async {
    throw const XlandFailure.notFound(message: 'Payment not found in fake');
  }

  @override
  Future<PaymentRecord> createIntent(String bookingId, {required String idempotencyKey}) async {
    throw const XlandFailure(
      code: FailureCode.policyNotConfigured,
      message: 'Policy not configured',
    );
  }

  @override
  Future<PaymentRecord> refresh(String paymentId) async {
    throw const XlandFailure.notFound(message: 'Payment not found in fake');
  }
}

class FakeAccountRepository implements AccountRepository {
  Session? _currentSession;

  @override
  Future<Session?> getSession() async => _currentSession;

  @override
  Future<Session> signIn(SignInInput input) async {
    // Validate credentials for test
    if (input.password == 'wrong_pass' || input.password == 'wrong_password') {
      throw const XlandFailure.unauthenticated(
        message: 'Tài khoản hoặc mật khẩu không chính xác',
      );
    }

    final session = Session(
      profile: UserProfile(
        id: 'usr-${input.username}',
        displayName: input.username == 'user' ? 'Nguyễn Văn A' : input.username,
        avatarUrl: null,
        contactPhone: '0901234567',
        contactVerified: true,
        updatedAt: DateTime.utc(2026, 10, 15),
      ),
      expiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
    );
    _currentSession = session;
    return session;
  }

  @override
  Future<void> signOut() async {
    _currentSession = null;
  }

  @override
  Future<UserProfile> getProfile() async {
    if (_currentSession == null) {
      throw const XlandFailure.unauthenticated();
    }
    return _currentSession!.profile;
  }

  @override
  Future<UserProfile> updateProfile(ProfileUpdate input) async {
    if (_currentSession == null) {
      throw const XlandFailure.unauthenticated();
    }
    // Conflict checks: clear flag true + value present => invalidInput
    if (input.clearAvatar && input.avatarUrl != null) {
      throw const XlandFailure(
        code: FailureCode.invalidInput,
        message: 'clearAvatar cannot be combined with avatarUrl',
      );
    }
    if (input.clearContactPhone && input.contactPhone != null) {
      throw const XlandFailure(
        code: FailureCode.invalidInput,
        message: 'clearContactPhone cannot be combined with contactPhone',
      );
    }

    final current = _currentSession!.profile;
    final Uri? newAvatar = input.clearAvatar ? null : (input.avatarUrl ?? current.avatarUrl);
    final String? newPhone;
    final bool newVerified;
    if (input.clearContactPhone) {
      newPhone = null;
      newVerified = false;
    } else if (input.contactPhone != null) {
      newPhone = input.contactPhone;
      newVerified = false; // per contract: set contact sets contactVerified = false
    } else {
      newPhone = current.contactPhone;
      newVerified = current.contactVerified;
    }

    final updated = UserProfile(
      id: current.id,
      displayName: input.displayName ?? current.displayName,
      avatarUrl: newAvatar,
      contactPhone: newPhone,
      contactVerified: newVerified,
      updatedAt: DateTime.utc(2026, 10, 16),
    );
    _currentSession = Session(
      profile: updated,
      expiresAt: _currentSession!.expiresAt,
    );
    return updated;
  }

  @override
  Future<UserSettings> getSettings() async {
    return UserSettings(
      notificationConsent: true,
      locale: 'vi_VN',
      timeZone: 'Asia/Ho_Chi_Minh',
      feedAutoplay: true,
      feedMutedByDefault: true,
      updatedAt: DateTime.utc(2026, 10, 15),
    );
  }

  @override
  Future<UserSettings> updateSettings(SettingsUpdate input) async {
    return UserSettings(
      notificationConsent: input.notificationConsent ?? true,
      locale: 'vi_VN',
      timeZone: 'Asia/Ho_Chi_Minh',
      feedAutoplay: input.feedAutoplay ?? true,
      feedMutedByDefault: input.feedMutedByDefault ?? true,
      updatedAt: DateTime.utc(2026, 10, 15),
    );
  }
}

class FakeClubRepository implements ClubRepository {
  static const sampleClub = Club(
    id: '00000000-0000-4000-8000-000000000102',
    title: 'Câu lạc bộ tìm hiểu đất nền',
    summary: 'Giới thiệu minh họa',
    description: 'Cùng tìm hiểu hồ sơ và khu vực',
    regionLabel: 'Hà Nội',
    activities: [
      'Chia sẻ kiến thức',
      'Tham quan khu vực',
    ],
    media: [],
    supportRecipientLabel: 'Đội hỗ trợ XLand (demo)',
    isIllustrative: true,
  );

  @override
  Future<Page<Club>> getClubs(PageQuery page) async {
    return const Page<Club>(items: [sampleClub], nextCursor: null, hasMore: false, total: 1);
  }

  @override
  Future<Club> getClub(String clubId) async {
    if (clubId == sampleClub.id || clubId == 'K01' || clubId == 'K02') {
      return sampleClub;
    }
    throw const XlandFailure.notFound(message: 'Club not found in fake');
  }
}

class FakeFinanceRepository implements FinanceRepository {
  final List<SavedFinancePlan> _savedPlans = [];

  @override
  Future<FinanceResult> calculate(FinanceInput input) async {
    // 1. Zero loan scenario
    if (input.loanVnd.amount == BigInt.zero) {
      return FinanceResult(
        input: input,
        monthlyPaymentVnd: Vnd.fromInt(0),
        firstMonthPrincipalVnd: Vnd.fromInt(0),
        firstMonthInterestVnd: Vnd.fromInt(0),
        totalInterestVnd: Vnd.fromInt(0),
        totalRepaymentVnd: Vnd.fromInt(0),
        formulaVersion: 'xland-loan-v1',
        roundingRule: 'VND_HALF_UP_MONTHLY_LAST_ADJUST',
        estimateNotice: 'Ước tính minh họa; không phải đề nghị cấp tín dụng; chưa gồm phí, thuế, bảo hiểm.',
      );
    }

    // 2. Exact oracle vector for XL-028 (2.4B total, 1.2B loan, 240 months, 9% annual rate)
    final rateDbl = double.tryParse(input.annualRatePercent.wireValue) ?? -1.0;
    if (input.loanVnd.amount == BigInt.from(1200000000) &&
        input.termMonths == 240 &&
        (rateDbl == 9.0 || input.annualRatePercent.wireValue == '9')) {
      if (input.method == RepaymentMethod.equalInstallment) {
        return FinanceResult(
          input: input,
          monthlyPaymentVnd: Vnd.fromInt(10796711),
          firstMonthPrincipalVnd: Vnd.fromInt(1796711),
          firstMonthInterestVnd: Vnd.fromInt(9000000),
          totalInterestVnd: Vnd.fromInt(1391210961),
          totalRepaymentVnd: Vnd.fromInt(2591210961),
          formulaVersion: 'xland-loan-v1',
          roundingRule: 'VND_HALF_UP_MONTHLY_LAST_ADJUST',
          estimateNotice: 'Ước tính minh họa; không phải đề nghị cấp tín dụng; chưa gồm phí, thuế, bảo hiểm.',
        );
      } else {
        // Declining
        return FinanceResult(
          input: input,
          monthlyPaymentVnd: Vnd.fromInt(14000000),
          firstMonthPrincipalVnd: Vnd.fromInt(5000000),
          firstMonthInterestVnd: Vnd.fromInt(9000000),
          totalInterestVnd: Vnd.fromInt(1084500000),
          totalRepaymentVnd: Vnd.fromInt(2284500000),
          formulaVersion: 'xland-loan-v1',
          roundingRule: 'VND_HALF_UP_MONTHLY_LAST_ADJUST',
          estimateNotice: 'Ước tính minh họa; không phải đề nghị cấp tín dụng; chưa gồm phí, thuế, bảo hiểm.',
        );
      }
    }

    if (input.loanVnd.amount == BigInt.from(1200000000) &&
        input.termMonths == 240 &&
        rateDbl == 0.0) {
      return FinanceResult(
        input: input,
        monthlyPaymentVnd: Vnd.fromInt(5000000),
        firstMonthPrincipalVnd: Vnd.fromInt(5000000),
        firstMonthInterestVnd: Vnd.fromInt(0),
        totalInterestVnd: Vnd.fromInt(0),
        totalRepaymentVnd: Vnd.fromInt(1200000000),
        formulaVersion: 'xland-loan-v1',
        roundingRule: 'VND_HALF_UP_MONTHLY_LAST_ADJUST',
        estimateNotice: 'Ước tính minh họa; không phải đề nghị cấp tín dụng; chưa gồm phí, thuế, bảo hiểm.',
      );
    }

    // 3. Schedule-based calculation for arbitrary inputs (no pmt * n shortcut)
    final loan = input.loanVnd.amount.toDouble();
    final n = input.termMonths;
    final r = rateDbl <= 0 ? 0.0 : rateDbl / 100.0 / 12.0;

    if (r == 0) {
      final monthly = (loan / n).round();
      return FinanceResult(
        input: input,
        monthlyPaymentVnd: Vnd.fromInt(monthly),
        firstMonthPrincipalVnd: Vnd.fromInt(monthly),
        firstMonthInterestVnd: Vnd.fromInt(0),
        totalInterestVnd: Vnd.fromInt(0),
        totalRepaymentVnd: input.loanVnd,
        formulaVersion: 'xland-loan-v1',
        roundingRule: 'VND_HALF_UP_MONTHLY_LAST_ADJUST',
        estimateNotice: 'Ước tính minh họa; không phải đề nghị cấp tín dụng; chưa gồm phí, thuế, bảo hiểm.',
      );
    }

    if (input.method == RepaymentMethod.equalInstallment) {
      final pmt = (loan * (r * _pow(1 + r, n)) / (_pow(1 + r, n) - 1)).round();
      int balance = loan.round();
      int firstPrincipal = 0;
      int firstInterest = 0;
      int totalPrincipal = 0;
      int totalInterest = 0;

      for (int m = 1; m <= n; m++) {
        final interest = (balance * r).round();
        int principal;
        if (m == n) {
          principal = balance;
        } else {
          principal = (pmt - interest).clamp(0, balance);
        }
        balance -= principal;
        if (m == 1) {
          firstPrincipal = principal;
          firstInterest = interest;
        }
        totalPrincipal += principal;
        totalInterest += interest;
      }

      return FinanceResult(
        input: input,
        monthlyPaymentVnd: Vnd.fromInt(pmt),
        firstMonthPrincipalVnd: Vnd.fromInt(firstPrincipal),
        firstMonthInterestVnd: Vnd.fromInt(firstInterest),
        totalInterestVnd: Vnd.fromInt(totalInterest),
        totalRepaymentVnd: Vnd.fromInt(totalPrincipal + totalInterest),
        formulaVersion: 'xland-loan-v1',
        roundingRule: 'VND_HALF_UP_MONTHLY_LAST_ADJUST',
        estimateNotice: 'Ước tính minh họa; không phải đề nghị cấp tín dụng; chưa gồm phí, thuế, bảo hiểm.',
      );
    } else {
      final fixedPrincipal = (loan / n).round();
      int balance = loan.round();
      int firstPayment = 0;
      int firstPrincipal = 0;
      int firstInterest = 0;
      int totalPrincipal = 0;
      int totalInterest = 0;

      for (int m = 1; m <= n; m++) {
        final interest = (balance * r).round();
        int principal;
        if (m == n) {
          principal = balance;
        } else {
          principal = fixedPrincipal.clamp(0, balance);
        }
        final payment = principal + interest;
        balance -= principal;
        if (m == 1) {
          firstPayment = payment;
          firstPrincipal = principal;
          firstInterest = interest;
        }
        totalPrincipal += principal;
        totalInterest += interest;
      }

      return FinanceResult(
        input: input,
        monthlyPaymentVnd: Vnd.fromInt(firstPayment),
        firstMonthPrincipalVnd: Vnd.fromInt(firstPrincipal),
        firstMonthInterestVnd: Vnd.fromInt(firstInterest),
        totalInterestVnd: Vnd.fromInt(totalInterest),
        totalRepaymentVnd: Vnd.fromInt(totalPrincipal + totalInterest),
        formulaVersion: 'xland-loan-v1',
        roundingRule: 'VND_HALF_UP_MONTHLY_LAST_ADJUST',
        estimateNotice: 'Ước tính minh họa; không phải đề nghị cấp tín dụng; chưa gồm phí, thuế, bảo hiểm.',
      );
    }
  }

  static double _pow(double x, int exp) {
    double res = 1.0;
    for (int i = 0; i < exp; i++) {
      res *= x;
    }
    return res;
  }

  @override
  Future<SavedFinancePlan> savePlan(String label, FinanceInput input, {required String idempotencyKey}) async {
    final result = await calculate(input);
    final plan = SavedFinancePlan(
      id: 'plan-${DateTime.now().millisecondsSinceEpoch}',
      propertyId: input.propertyId,
      label: label,
      input: input,
      result: result,
      createdAt: DateTime.now().toUtc(),
    );
    _savedPlans.add(plan);
    return plan;
  }

  @override
  Future<Page<SavedFinancePlan>> getPlans(PageQuery page) async {
    return Page<SavedFinancePlan>(
      items: List.unmodifiable(_savedPlans),
      nextCursor: null,
      hasMore: false,
      total: _savedPlans.length,
    );
  }

  @override
  Future<void> deletePlan(String planId) async {
    _savedPlans.removeWhere((p) => p.id == planId);
  }
}

class FakeSupportRepository implements SupportRepository {
  final List<SupportRequest> _requests = [];
  bool shouldFail = false;

  @override
  Future<SupportRequest> submit(SupportRequestInput input, {required String idempotencyKey}) async {
    if (shouldFail) {
      throw const XlandFailure(
        code: FailureCode.internalError,
        message: 'Lỗi gửi yêu cầu hỗ trợ',
      );
    }
    if (!input.consentToShareContact) {
      throw const XlandFailure(
        code: FailureCode.invalidInput,
        message: 'Cần có sự đồng thuận chia sẻ thông tin liên hệ.',
      );
    }
    final req = SupportRequest(
      id: 'req-${DateTime.now().millisecondsSinceEpoch}',
      kind: input.kind,
      status: SupportStatus.received,
      recipientLabel: 'Đội ngũ tư vấn XLand',
      notice: 'Yêu cầu tư vấn đã được tiếp nhận. Chuyên viên sẽ liên hệ trong giờ làm việc.',
      createdAt: DateTime.now().toUtc(),
    );
    _requests.add(req);
    return req;
  }

  @override
  Future<Page<SupportRequest>> getRequests(PageQuery page) async {
    return Page<SupportRequest>(
      items: List.unmodifiable(_requests),
      nextCursor: null,
      hasMore: false,
      total: _requests.length,
    );
  }
}

class FakeGuestPreferencesRepository implements GuestPreferencesRepository {
  GuestPlaybackPreferences value = const GuestPlaybackPreferences();
  @override
  Future<GuestPlaybackPreferences> read() async => value;
  @override
  Future<GuestPlaybackPreferences> update(GuestPreferenceUpdate input) async => value = GuestPlaybackPreferences(
    feedAutoplay: input.feedAutoplay ?? value.feedAutoplay,
    feedMutedByDefault: input.feedMutedByDefault ?? value.feedMutedByDefault,
  );
  @override
  Future<void> clear() async { value = const GuestPlaybackPreferences(); }
}

/// Helper function to create fake dependencies bundle.
XlandDependencies createFakeDependencies({
  FakePropertyRepository? propertyRepo,
  FakeAccountRepository? accountRepo,
}) {
  return XlandDependencies(
    properties: propertyRepo ?? FakePropertyRepository(),
    feed: FakeFeedRepository(),
    consultants: FakeConsultantRepository(),
    events: FakeEventRepository(),
    bookings: FakeBookingRepository(),
    payments: FakePaymentRepository(),
    account: accountRepo ?? FakeAccountRepository(),
    clubs: FakeClubRepository(),
    finance: FakeFinanceRepository(),
    support: FakeSupportRepository(),
    guestPreferences: FakeGuestPreferencesRepository(),
  );
}
