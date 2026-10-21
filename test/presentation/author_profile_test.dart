import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/domain/xland_domain.dart';
import 'package:xland_mobile/presentation/features/author/pages/author_profile_page.dart';
import 'package:xland_mobile/presentation/features/auth/cubit/auth_cubit.dart';
import 'package:xland_mobile/presentation/features/consultant/pages/consultant_profile_page.dart';
import 'package:xland_mobile/presentation/features/feed/widgets/video_player_item.dart';
import 'package:xland_mobile/presentation/shared/di/dependencies_scope.dart';
import 'package:xland_mobile/presentation/theme/theme.dart';

import 'fakes/fake_xland_dependencies.dart';

const posterId = 'author-ngoc-anh';

class ProfileFeed extends FakeFeedRepository {
  late FeedVideo video;
  bool consultantAuthor = false;
  bool unavailable = false;
  bool following = false;
  bool paginate = false;
  final profileIds = <String>[];
  final videoIds = <String>[];
  final follows = <String>[];

  @override
  Future<AuthorProfile> getAuthorProfile(String authorId) async {
    profileIds.add(authorId);
    if (unavailable) {
      throw const XlandFailure.notFound(message: 'Không tìm thấy người đăng');
    }
    return AuthorProfile(
      author: PublicAuthor(
        id: authorId,
        displayName: 'Ngọc Anh',
        isVerified: false,
        isFollowing: following,
      ),
      videoCount: paginate ? 2 : 1,
      followerCount: following ? 1 : 0,
      consultantId: consultantAuthor ? authorId : null,
      isIllustrative: false,
    );
  }

  @override
  Future<Page<FeedVideo>> getAuthorVideos(
    String authorId,
    PageQuery page,
  ) async {
    videoIds.add(authorId);
    return Page(
      items: [video],
      hasMore: paginate && page.cursor == null,
      nextCursor: paginate && page.cursor == null ? 'next' : null,
    );
  }

  @override
  Future<MutationResult> setFollowing(String authorId, bool next) async {
    follows.add(authorId);
    following = next;
    return MutationResult(active: next, count: next ? 1 : 0);
  }
}

class ProfileConsultants extends FakeConsultantRepository {
  final requested = <String>[];
  @override
  Future<Consultant> getConsultant(String consultantId) async {
    requested.add(consultantId);
    return Consultant(
      id: consultantId,
      name: consultantId == posterId ? 'Ngọc Anh' : 'Quang Quân',
      role: 'Tư vấn viên',
      location: 'Hưng Yên',
      isVerified: true,
      videoCount: 1,
      followerCount: 0,
      isFollowing: false,
      isIllustrative: false,
    );
  }
}

Future<void> mount(
  WidgetTester tester,
  ProfileFeed feed,
  ProfileConsultants consultants, {
  bool signedIn = false,
}) async {
  tester.view.physicalSize = const Size(390, 850);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final base = (await feed.getFeed(const PageQuery())).items.first;
  feed.video = FeedVideo(
    id: 'ngoc-video',
    propertyId: base.propertyId,
    author: const PublicAuthor(
      id: posterId,
      displayName: 'Ngọc Anh',
      isVerified: false,
      isFollowing: false,
    ),
    media: const MediaAsset(
      id: 'poster',
      kind: MediaKind.video,
      altText: 'Video của Ngọc Anh',
      isIllustrative: false,
    ),
    caption: 'Video của Ngọc Anh',
    approximateArea: base.approximateArea,
    property: base.property,
    likeCount: 0,
    commentCount: 0,
    viewCount: 1,
    isLiked: false,
    isSaved: false,
    publishedAt: base.publishedAt,
    isIllustrative: false,
  );
  final d = createFakeDependencies();
  if (signedIn) {
    await d.account.signIn(
      const SignInInput(username: 'owner_a', password: 'review_password'),
    );
  }
  final auth = AuthCubit(d.account);
  await auth.checkSession();
  addTearDown(auth.close);
  final deps = XlandDependencies(
    properties: d.properties,
    feed: feed,
    consultants: consultants,
    events: d.events,
    bookings: d.bookings,
    payments: d.payments,
    account: d.account,
    clubs: d.clubs,
    finance: d.finance,
    support: d.support,
  );
  await tester.pumpWidget(
    DependenciesScope(
      dependencies: deps,
      child: BlocProvider.value(
        value: auth,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: VideoPlayerItem(
              video: feed.video,
              isCurrent: false,
              isAppActive: true,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final key in [
    'feed-author-avatar',
    'feed-author-inline-avatar',
    'feed-author-name',
  ]) {
    testWidgets(
      '$key opens the non-consultant author rather than the property consultant',
      (tester) async {
        final feed = ProfileFeed();
        final consultants = ProfileConsultants();
        await mount(tester, feed, consultants);
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AuthorProfilePage>(find.byType(AuthorProfilePage))
              .authorId,
          posterId,
        );
        expect(find.text('Hồ sơ người đăng'), findsOneWidget);
        expect(find.text('Ngọc Anh'), findsOneWidget);
        expect(find.text('Video của Ngọc Anh'), findsOneWidget);
        expect(find.byType(ConsultantProfilePage), findsNothing);
        expect(find.text('Nhắn tư vấn'), findsNothing);
        expect(feed.profileIds, [posterId]);
        expect(feed.videoIds, [posterId]);
        expect(consultants.requested, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a consultant author opens their own consultant profile', (
    tester,
  ) async {
    final feed = ProfileFeed()..consultantAuthor = true;
    final consultants = ProfileConsultants();
    await mount(tester, feed, consultants);
    await tester.tap(find.byKey(const ValueKey('feed-author-name')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ConsultantProfilePage>(find.byType(ConsultantProfilePage))
          .consultantId,
      posterId,
    );
    expect(consultants.requested, [posterId]);
    expect(feed.videoIds, isEmpty);
  });

  testWidgets(
    'following on the author profile updates the author and the feed on return',
    (tester) async {
      final feed = ProfileFeed();
      await mount(tester, feed, ProfileConsultants(), signedIn: true);
      await tester.tap(find.byKey(const ValueKey('feed-author-name')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Theo dõi'));
      await tester.pumpAndSettle();
      expect(feed.follows, [posterId]);
      expect(find.text('Đang theo dõi'), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      expect(find.text('Đã theo dõi'), findsOneWidget);
      expect(feed.profileIds, [posterId, posterId]);
    },
  );

  testWidgets(
    'profile errors retry without falling back to the property consultant',
    (tester) async {
      final feed = ProfileFeed()..unavailable = true;
      final consultants = ProfileConsultants();
      await mount(tester, feed, consultants);
      await tester.tap(find.byKey(const ValueKey('feed-author-name')));
      await tester.pumpAndSettle();
      expect(find.text('Không tìm thấy hồ sơ người đăng.'), findsOneWidget);
      expect(consultants.requested, isEmpty);
      feed.unavailable = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Ngọc Anh'), findsOneWidget);
      expect(feed.videoIds, [posterId]);
    },
  );

  testWidgets(
    'contact from property detail still opens the assigned consultant',
    (tester) async {
      final feed = ProfileFeed();
      final consultants = ProfileConsultants();
      await mount(tester, feed, consultants);
      await tester.tap(find.text('Xem chi tiết'));
      await tester.pumpAndSettle();
      expect(consultants.requested, [feed.video.property.consultantId]);
      await tester.tap(find.text('Chuyên viên tư vấn'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ConsultantProfilePage>(find.byType(ConsultantProfilePage))
            .consultantId,
        feed.video.property.consultantId,
      );
      expect(find.text('Quang Quân'), findsOneWidget);
      expect(feed.profileIds, isEmpty);
    },
  );
}
