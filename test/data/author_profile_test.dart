import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/data/datasources/remote/api_transport.dart';
import 'package:xland_mobile/data/repositories/remote_repositories.dart';
import 'package:xland_mobile/data/repositories/remaining_repositories.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

class ProfileTransport implements ApiTransport {
  final requests = <ApiRequest>[];
  XlandFailure? failure;
  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    if (failure != null) throw failure!;
    return ApiResponse(
      statusCode: 200,
      body: request.path.endsWith('/videos')
          ? {
              'data': <Object?>[],
              'meta': {'total': null, 'hasMore': false, 'nextCursor': null},
            }
          : {
              'data': {
                'id': 'ngoc-anh',
                'displayName': 'Ngọc Anh',
                'role': null,
                'avatarUrl': null,
                'isVerified': false,
                'isFollowing': false,
                'videoCount': 2,
                'followerCount': 3,
                'consultantId': null,
                'isIllustrative': false,
              },
            },
      requestId: 'author-profile-test',
    );
  }
}

void main() {
  test(
    'author endpoints map non-consultant profiles and preserve pagination',
    () async {
      final transport = ProfileTransport();
      final feed = RemoteFeedRepository(
        RemoteGateway(transport, availableOperations: const {'F15', 'F16'}),
      );
      final profile = await feed.getAuthorProfile('ngoc-anh');
      expect(profile.author.displayName, 'Ngọc Anh');
      expect(profile.consultantId, isNull);
      expect(profile.videoCount, 2);
      expect(profile.followerCount, 3);
      await feed.getAuthorVideos(
        'ngoc-anh',
        const PageQuery(limit: 10, cursor: 'next'),
      );
      expect(transport.requests.map((r) => r.path), [
        '/authors/ngoc-anh',
        '/authors/ngoc-anh/videos',
      ]);
      expect(transport.requests.last.query, {'limit': '10', 'cursor': 'next'});
    },
  );
  test('a missing author endpoint remains an error without consulting feed or video endpoints', () async {
    final transport = ProfileTransport()
      ..failure = const XlandFailure.notFound(message: 'Resource not found');
    final feed = RemoteFeedRepository(RemoteGateway(transport));
    await expectLater(
      feed.getAuthorProfile('ngoc-anh'),
      throwsA(
        isA<XlandFailure>().having((e) => e.code, 'code', FailureCode.notFound),
      ),
    );
    expect(transport.requests.map((r) => r.path), ['/authors/ngoc-anh']);
  });
  test(
    'author-video API failures never scan the public feed as a fallback',
    () async {
      final transport = ProfileTransport()
        ..failure = const XlandFailure(
          code: FailureCode.invalidInput,
          message: 'Invalid query',
        );
      final feed = RemoteFeedRepository(RemoteGateway(transport));
      await expectLater(
        feed.getAuthorVideos('ngoc-anh', const PageQuery()),
        throwsA(
          isA<XlandFailure>().having(
            (e) => e.code,
            'code',
            FailureCode.invalidInput,
          ),
        ),
      );
      expect(transport.requests.map((r) => r.path), [
        '/authors/ngoc-anh/videos',
      ]);
    },
  );
}
