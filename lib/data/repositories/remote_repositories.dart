import 'dart:convert';

import '../../domain/xland_domain.dart';
import '../auth/auth_operation_coordinator.dart';
import '../datasources/remote/api_transport.dart';
import '../datasources/local/session_store.dart';
import '../mappers/domain_mappers.dart';

final class RemoteGateway {
  const RemoteGateway(this.transport, {this.availableOperations});
  final ApiTransport transport;
  final Set<String>? availableOperations;

  Future<T> request<T>(
    String operation,
    String method,
    String path,
    T Function(Object?) mapper, {
    Map<String, String> query = const {},
    Map<String, Object?>? body,
    String? idempotencyKey,
  }) async {
    if (availableOperations != null &&
        !availableOperations!.contains(operation)) {
      throw const XlandFailure(
        code: FailureCode.featureNotEnabled,
        message: 'Module API này đang được triển khai',
      );
    }
    final response = await transport.send(
      ApiRequest(
        method: method,
        path: path,
        query: query,
        body: body,
        idempotencyKey: idempotencyKey,
      ),
    );
    try {
      return mapper(wireField(response.body, 'data'));
    } on FormatException {
      throw XlandFailure(
        code: FailureCode.internalError,
        message: 'Dữ liệu máy chủ không khớp contract',
        requestId: response.requestId,
      );
    }
  }

  Future<Page<T>> page<T>(
    String operation,
    String path,
    PageQuery page,
    T Function(Object?) mapper, {
    Map<String, String> query = const {},
  }) async {
    return envelope(
      operation,
      path,
      page,
      query: query,
      mapper: (response) {
        final meta = wireObject(wireField(response, 'meta'));
        return Page(
          items: wireList(wireField(response, 'data'), mapper),
          hasMore: wireBool(wireField(meta, 'hasMore')),
          nextCursor: wireNullable(wireField(meta, 'nextCursor'), wireString),
          total: wireNullable(wireField(meta, 'total'), wireInt),
        );
      },
    );
  }

  Future<T> envelope<T>(
    String operation,
    String path,
    PageQuery page, {
    Map<String, String> query = const {},
    required T Function(Map<String, Object?>) mapper,
  }) async {
    if (availableOperations != null &&
        !availableOperations!.contains(operation)) {
      throw const XlandFailure(
        code: FailureCode.featureNotEnabled,
        message: 'Module API này đang được triển khai',
      );
    }
    final response = await transport.send(
      ApiRequest(
        method: 'GET',
        path: path,
        query: {
          ...query,
          'limit': '${page.limit}',
          if (page.cursor != null) 'cursor': page.cursor!,
        },
      ),
    );
    try {
      return mapper(response.body);
    } on FormatException {
      throw XlandFailure(
        code: FailureCode.internalError,
        message: 'Phân trang máy chủ không hợp lệ',
        requestId: response.requestId,
      );
    }
  }
}

Map<String, String> propertyFilters(PropertyFilter filter) => {
  if (filter.query != null) 'query': filter.query!,
  if (filter.regions.isNotEmpty)
    'regions': filter.regions.map(writeRegion).join(','),
  if (filter.category != null)
    'category': writePropertyCategory(filter.category!),
  if (filter.provinceCode != null) 'provinceCode': filter.provinceCode!,
  if (filter.districtCode != null) 'districtCode': filter.districtCode!,
  if (filter.minPriceVnd != null) 'minPriceVnd': filter.minPriceVnd!.wireValue,
  if (filter.maxPriceVnd != null) 'maxPriceVnd': filter.maxPriceVnd!.wireValue,
  if (filter.areaBands.isNotEmpty)
    'areaBands': filter.areaBands.map(writeAreaBand).join(','),
  if (filter.landTypes.isNotEmpty)
    'landTypes': filter.landTypes.map(writeLandType).join(','),
  if (filter.minRoadWidthM != null)
    'minRoadWidthM': filter.minRoadWidthM!.wireValue,
  if (filter.hasDocuments != null) 'hasDocuments': '${filter.hasDocuments}',
  'savedOnly': '${filter.savedOnly}',
  'sort': writePropertySort(filter.sort),
};

final class RemotePropertyRepository implements PropertyRepository {
  const RemotePropertyRepository(this.gateway);
  final RemoteGateway gateway;
  @override
  Future<PropertySearchResult> search(PropertyFilter filter, PageQuery page) =>
      gateway.envelope(
        'D01',
        '/properties',
        page,
        query: propertyFilters(filter),
        mapper: (response) {
          final meta = wireObject(wireField(response, 'meta'));
          final total = wireInt(wireField(meta, 'total'));
          return PropertySearchResult(
            page: Page(
              items: wireList(wireField(response, 'data'), mapProperty),
              hasMore: wireBool(wireField(meta, 'hasMore')),
              nextCursor: wireNullable(
                wireField(meta, 'nextCursor'),
                wireString,
              ),
              total: total,
            ),
            total: total,
            selectedCriteriaCount: wireInt(
              wireField(meta, 'selectedCriteriaCount'),
            ),
          );
        },
      );
  @override
  Future<int> count(PropertyFilter filter) => gateway.request(
    'D02',
    'GET',
    '/properties/count',
    (value) => wireInt(wireField(wireObject(value), 'total')),
    query: propertyFilters(filter),
  );
  @override
  Future<FilterCatalog> getFilterCatalog({String? provinceCode}) =>
      gateway.request(
        'D03',
        'GET',
        '/catalog/locations',
        mapFilterCatalog,
        query: {'provinceCode': ?provinceCode},
      );
  @override
  Future<Property> getProperty(String propertyId) =>
      gateway.request('D04', 'GET', '/properties/$propertyId', mapProperty);
  @override
  Future<LegalSummary> getLegal(String propertyId) => gateway.request(
    'L01',
    'GET',
    '/properties/$propertyId/legal',
    mapLegalSummary,
  );
  @override
  Future<DownloadGrant> requestDownload(String propertyId, String documentId) =>
      gateway.request(
        'L02',
        'POST',
        '/properties/$propertyId/documents/$documentId/download',
        mapDownloadGrant,
      );
  @override
  Future<AreaInfo> getArea(String propertyId, {AmenityCategory? category}) =>
      gateway.request(
        'A01',
        'GET',
        '/properties/$propertyId/area',
        mapAreaInfo,
        query: {
          if (category != null) 'category': writeAmenityCategory(category),
        },
      );
  @override
  Future<MutationResult> setSaved(String propertyId, bool saved) =>
      gateway.request(
        saved ? 'D05' : 'D06',
        saved ? 'PUT' : 'DELETE',
        '/properties/$propertyId/saved',
        mapMutationResult,
      );
  @override
  Future<ShareLink> getShareLink(String propertyId) => gateway.request(
    'D07',
    'GET',
    '/properties/$propertyId/share',
    mapShareLink,
  );
}

final class RemoteAccountRepository implements AccountRepository,AccountSessionEvents {
  RemoteAccountRepository(this.gateway, this.sessions, {AuthOperationCoordinator? authCoordinator})
    : authCoordinator = authCoordinator ?? AuthOperationCoordinator();
  final AuthOperationCoordinator authCoordinator;
  final RemoteGateway gateway;
  final SessionStore sessions;
  @override Stream<void> get sessionInvalidations=>switch(sessions) {
    SessionInvalidationSource source=>source.sessionInvalidations,
    _=>const Stream<void>.empty(),
  };
  Future<T> _authOperation<T>(Future<T> Function(AuthAttempt) action, {bool cancellable = true}) => authCoordinator.run(action, cancellable: cancellable);
  @override
  Future<Session?> getSession() async {
    if (await sessions.readAccessToken() == null) return null;
    try {
      return await gateway.request('U04', 'GET', '/auth/session', mapSession);
    } on XlandFailure catch (error) {
      if (error.code == FailureCode.unauthenticated) return null;
      rethrow;
    }
  }

  @override
  Future<Session> signIn(SignInInput input) => _authOperation((attempt) async {
    final result = await gateway.request('U01', 'POST', '/auth/sessions', (
      value,
    ) {
      final data = wireObject(value);
      final token = wireString(wireField(data, 'accessToken'));
      if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(token)) {
        throw const FormatException('Invalid opaque session');
      }
      return (token: token, session: mapSession(wireField(data, 'session')));
    }, body: {'username': input.username, 'password': input.password});
    attempt.check();
    await sessions.saveAccessToken(accessToken: result.token);
    try { attempt.check(); } on XlandFailure {
      await sessions.clearIfMatches(accessToken: result.token);
      rethrow;
    }
    return result.session;
  });

  @override
  Future<Session> signUp(SignUpInput input) => _authOperation((attempt) async {
    final result = await gateway.request('U01', 'POST', '/auth/register', (
      value,
    ) {
      final data = wireObject(value);
      final token = wireString(wireField(data, 'accessToken'));
      if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(token)) {
        throw const FormatException('Invalid opaque session');
      }
      return (token: token, session: mapSession(wireField(data, 'session')));
    }, body: {'username': input.username, 'password': input.password});
    attempt.check();
    await sessions.saveAccessToken(accessToken: result.token);
    try { attempt.check(); } on XlandFailure {
      await sessions.clearIfMatches(accessToken: result.token);
      rethrow;
    }
    return result.session;
  });

  @override
  Future<void> signOut() => _authOperation((_) async {
    final token=await sessions.readAccessToken();
    try {
      await gateway.request(
        'U03',
        'DELETE',
        '/auth/sessions/current',
        (_) => null,
      );
    } finally {
      if(token!=null) await sessions.clearIfMatches(accessToken:token);
    }
  }, cancellable: false);

  @override
  Future<UserProfile> getProfile() =>
      gateway.request('U05', 'GET', '/me/profile', mapUserProfile);
  @override
  Future<UserProfile> updateProfile(ProfileUpdate input) async {
    if ((input.clearAvatar &&
            (input.avatarUrl != null || input.avatar != null)) ||
        (input.avatar != null && input.avatarUrl != null) ||
        (input.clearAddress && input.address != null) ||
        (input.clearContactPhone && input.contactPhone != null)) {
      throw const XlandFailure(
        code: FailureCode.invalidInput,
        message: 'Không thể vừa xóa vừa đặt cùng một thông tin',
      );
    }
    return gateway.request(
      'U06',
      'PATCH',
      '/me/profile',
      mapUserProfile,
      body: {
        if (input.displayName != null) 'displayName': input.displayName,
        if (input.clearAddress)
          'address': null
        else if (input.address != null)
          'address': input.address,
        if (input.avatar != null)
          'avatar': {
            'mimeType': input.avatar!.mimeType,
            'bytesBase64': base64Encode(input.avatar!.bytes),
          },
        if (input.clearAvatar)
          'avatarUrl': null
        else if (input.avatarUrl != null)
          'avatarUrl': input.avatarUrl.toString(),
        if (input.clearContactPhone)
          'contactPhone': null
        else if (input.contactPhone != null)
          'contactPhone': input.contactPhone,
      },
    );
  }

  @override
  Future<UserSettings> getSettings() =>
      gateway.request('U07', 'GET', '/me/settings', mapUserSettings);
  @override
  Future<UserSettings> updateSettings(SettingsUpdate input) => gateway.request(
    'U08',
    'PATCH',
    '/me/settings',
    mapUserSettings,
    body: {
      if (input.notificationConsent != null)
        'notificationConsent': input.notificationConsent,
      if (input.feedAutoplay != null) 'feedAutoplay': input.feedAutoplay,
      if (input.feedMutedByDefault != null)
        'feedMutedByDefault': input.feedMutedByDefault,
    },
  );
}
