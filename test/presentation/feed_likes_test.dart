import 'dart:async';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/domain/xland_domain.dart';
import 'package:xland_mobile/presentation/features/auth/cubit/auth_cubit.dart';
import 'package:xland_mobile/presentation/features/feed/widgets/video_player_item.dart';
import 'package:xland_mobile/presentation/features/shell/main_navigation_shell.dart';
import 'package:xland_mobile/presentation/shared/di/dependencies_scope.dart';
import 'package:xland_mobile/presentation/theme/theme.dart';

import 'fakes/fake_xland_dependencies.dart';

class ControlledFeed extends FakeFeedRepository {
  final pending = <Completer<MutationResult>>[];
  final requested = <bool>[];
  bool initialLiked = false;

  @override
  Future<Page<FeedVideo>> getFeed(
    PageQuery page, {
    FeedScope feedScope = FeedScope.recommended,
    Region? region,
    PropertyCategory? category,
  }) async {
    final source = (await super.getFeed(page)).items.first;
    return Page(
      items: List.generate(
        6,
        (i) => FeedVideo(
          id: 'video-$i',
          propertyId: source.propertyId,
          author: source.author,
          media: source.media,
          caption: source.caption,
          approximateArea: source.approximateArea,
          property: source.property,
          likeCount: initialLiked ? 101 : 100,
          commentCount: 0,
          viewCount: 0,
          isLiked: initialLiked,
          isSaved: false,
          publishedAt: source.publishedAt,
          isIllustrative: false,
        ),
      ),
      hasMore: false,
    );
  }

  @override
  Future<MutationResult> setLiked(String videoId, bool liked) {
    requested.add(liked);
    final result = Completer<MutationResult>();
    pending.add(result);
    return result.future;
  }
}

Future<AuthCubit> mountFeed(WidgetTester t, ControlledFeed feed) async {
  t.view.physicalSize = const Size(390, 850);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final d = createFakeDependencies();
  await d.account.signIn(
    const SignInInput(username: 'owner_a', password: 'review_password'),
  );
  final auth = AuthCubit(d.account);
  await auth.checkSession();
  addTearDown(auth.close);
  final deps = XlandDependencies(
    properties: d.properties,
    feed: feed,
    consultants: d.consultants,
    events: d.events,
    bookings: d.bookings,
    payments: d.payments,
    account: d.account,
    clubs: d.clubs,
    finance: d.finance,
    support: d.support,
  );
  await t.pumpWidget(
    DependenciesScope(
      dependencies: deps,
      child: BlocProvider.value(
        value: auth,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MainNavigationShell(),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return auth;
}

Future<void> jump(WidgetTester t, int index) async {
  final scrollable = t.state<ScrollableState>(
    find
        .descendant(
          of: find.byType(PageView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  scrollable.position.jumpTo(index * scrollable.position.viewportDimension);
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'successful response while player is disposed is visible on return',
    (t) async {
      final feed = ControlledFeed();
      await mountFeed(t, feed);
      final original = t.state(find.byType(VideoPlayerItem).first);
      await t.tap(find.byIcon(Icons.favorite_border).first);
      await t.pump();
      await jump(t, 4);
      expect(original.mounted, isFalse);
      feed.pending.single.complete(
        const MutationResult(active: true, count: 137),
      );
      await t.pumpAndSettle();
      await jump(t, 0);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.text('137'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'server like count wins and confirmed like survives page disposal',
    (t) async {
      final feed = ControlledFeed();
      await mountFeed(t, feed);
      final original = t.state(find.byType(VideoPlayerItem).first);
      await t.tap(find.byIcon(Icons.favorite_border).first);
      await t.pump();
      feed.pending.single.complete(
        const MutationResult(active: true, count: 137),
      );
      await t.pumpAndSettle();
      expect(find.text('137'), findsOneWidget);
      await jump(t, 4);
      expect(original.mounted, isFalse);
      await jump(t, 0);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.text('137'), findsOneWidget);
      await t.tap(find.byIcon(Icons.favorite));
      await t.pump();
      feed.pending.last.complete(
        const MutationResult(active: false, count: 136),
      );
      await t.pumpAndSettle();
      await jump(t, 4);
      await jump(t, 0);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.text('136'), findsOneWidget);
      expect(feed.requested, [true, false]);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'pending like survives scroll, blocks duplicate tap and rolls back on failure',
    (t) async {
      final feed = ControlledFeed();
      await mountFeed(t, feed);
      await t.tap(find.byIcon(Icons.favorite_border).first);
      await t.pump();
      await jump(t, 4);
      await jump(t, 0);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      await t.tap(find.byIcon(Icons.favorite));
      await t.pump();
      expect(feed.requested, [true]);
      feed.pending.single.completeError(
        const XlandFailure(code: FailureCode.offline, message: 'Test offline'),
      );
      await t.pumpAndSettle();
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      await jump(t, 4);
      await jump(t, 0);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'late like response after logout cannot restore prior owner state',
    (t) async {
      final feed = ControlledFeed();
      final auth = await mountFeed(t, feed);
      await t.tap(find.byIcon(Icons.favorite_border).first);
      await t.pump();
      await auth.signOut();
      await t.pumpAndSettle();
      feed.pending.single.complete(
        const MutationResult(active: true, count: 137),
      );
      await t.pumpAndSettle();
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('137'), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}
