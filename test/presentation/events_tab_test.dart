import 'dart:async';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/domain/xland_domain.dart';
import 'package:xland_mobile/presentation/features/auth/cubit/auth_cubit.dart';
import 'package:xland_mobile/presentation/features/events/pages/events_tab_page.dart';
import 'package:xland_mobile/presentation/features/events/pages/event_detail_page.dart';
import 'package:xland_mobile/presentation/features/clubs/pages/club_detail_page.dart';
import 'package:xland_mobile/presentation/features/events/widgets/community_cards.dart';
import 'package:xland_mobile/presentation/shared/di/dependencies_scope.dart';
import 'package:xland_mobile/presentation/theme/theme.dart';

import 'fakes/fake_xland_dependencies.dart';

XlandEvent event(int i, {EventStatus status = EventStatus.open}) => XlandEvent(
  id: 'event-$i',
  title: 'Sự kiện cộng đồng $i',
  tags: [i < 5 ? 'Bất động sản' : 'Sáng tạo'],
  media: const [],
  startsAt: DateTime.utc(2027, 1, i, 2),
  endsAt: DateTime.utc(2027, 1, i, 4),
  timeZone: 'Asia/Ho_Chi_Minh',
  venueName: 'Không gian cộng đồng Hà Nội',
  address: 'Hà Nội',
  maxSlots: 40,
  remainingSlots: 40,
  durationMinutes: 120,
  ticketPriceVnd: Vnd('0'),
  status: status,
  agenda: const [],
  speakers: const [],
  benefits: const [],
  isSaved: false,
  isIllustrative: true,
);

class Events extends FakeEventRepository {
  final calls = <({String? cursor, EventStatus? status})>[];
  bool failMore = false;
  Completer<Page<XlandEvent>>? pending;
  String? opened;
  @override
  Future<Page<XlandEvent>> getEvents(
    PageQuery page, {
    EventStatus? status,
  }) async {
    calls.add((cursor: page.cursor, status: status));
    if (pending != null) return pending!.future;
    if (page.cursor != null && failMore) {
      throw const XlandFailure(code: FailureCode.offline, message: 'Offline');
    }
    if (status != EventStatus.open) {
      return const Page(items: [], hasMore: false);
    }
    final more = page.cursor == null;
    return Page(
      items: more
          ? [for (var i = 1; i <= 4; i++) event(i)]
          : [event(5), event(6)],
      hasMore: more,
      nextCursor: more ? 'page-2' : null,
    );
  }

  @override
  Future<XlandEvent> getEvent(String eventId) async {
    opened = eventId;
    return event(int.parse(eventId.split('-').last));
  }
}

class Clubs extends FakeClubRepository {
  bool fail = false;
  bool empty = false;
  String? opened;
  int calls = 0;
  @override
  Future<Page<Club>> getClubs(PageQuery page) async {
    calls++;
    if (fail) {
      throw const XlandFailure(code: FailureCode.offline, message: 'Offline');
    }
    return Page(
      items: empty ? [] : [FakeClubRepository.sampleClub],
      hasMore: false,
    );
  }

  @override
  Future<Club> getClub(String clubId) async {
    opened = clubId;
    return FakeClubRepository.sampleClub;
  }
}

Future<void> mount(
  WidgetTester tester,
  Events events,
  Clubs clubs, {
  double width = 390,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final base = createFakeDependencies();
  final deps = XlandDependencies(
    properties: base.properties,
    feed: base.feed,
    consultants: base.consultants,
    events: events,
    bookings: base.bookings,
    payments: base.payments,
    account: base.account,
    clubs: clubs,
    finance: base.finance,
    support: base.support,
  );
  final auth = AuthCubit(base.account);
  addTearDown(auth.close);
  await tester.pumpWidget(
    DependenciesScope(
      dependencies: deps,
      child: BlocProvider.value(
        value: auth,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(body: EventsTabPage()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    final font = FontLoader('Roboto');
    for (final weight in ['Regular', 'Medium', 'Bold']) {
      font.addFont(rootBundle.load('assets/fonts/Roboto-$weight.ttf'));
    }
    await font.load();
  });
  testWidgets('clubs precede a 2x2 event grid; both cards open real IDs', (
    tester,
  ) async {
    final events = Events(), clubs = Clubs();
    await mount(tester, events, clubs);
    expect(
      tester.getTopLeft(find.byType(ClubGridCard)).dy,
      lessThan(tester.getTopLeft(find.byType(EventGridCard).first).dy),
    );
    final cards = find.byType(EventGridCard);
    expect(cards, findsNWidgets(4));
    expect(
      tester.getTopLeft(cards.at(0)).dy,
      tester.getTopLeft(cards.at(1)).dy,
    );
    expect(
      tester.getTopLeft(cards.at(0)).dx,
      lessThan(tester.getTopLeft(cards.at(1)).dx),
    );
    expect(
      tester.getTopLeft(cards.at(2)).dy,
      greaterThan(tester.getTopLeft(cards.at(0)).dy),
    );
    expect(find.text('01/01/2027 · 09:00'), findsOneWidget);
    await tester.tap(find.byType(ClubGridCard));
    await tester.pumpAndSettle();
    expect(find.byType(ClubDetailPage), findsOneWidget);
    expect(clubs.opened, FakeClubRepository.sampleClub.id);
    Navigator.of(tester.element(find.byType(ClubDetailPage))).pop();
    await tester.pumpAndSettle();
    await reveal(tester, cards.first);
    await tester.tap(cards.first);
    await tester.pumpAndSettle();
    expect(find.byType(EventDetailPage), findsOneWidget);
    expect(events.opened, 'event-1');
  });

  testWidgets(
    'pagination retries preserve cards and use the same cursor; refresh resets both lists',
    (tester) async {
      final events = Events()..failMore = true;
      final clubs = Clubs();
      await mount(tester, events, clubs);
      await reveal(tester, find.text('Xem thêm sự kiện'));
      await tester.tap(find.text('Xem thêm sự kiện'));
      await tester.pumpAndSettle();
      expect(find.byType(EventGridCard), findsNWidgets(4));
      events.failMore = false;
      await reveal(tester, find.text('Thử lại'));
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.byType(EventGridCard), findsNWidgets(6));
      expect(events.calls.map((c) => c.cursor), [null, 'page-2', 'page-2']);
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(events.calls.last.cursor, isNull);
      expect(clubs.calls, 2);
      expect(find.byType(EventGridCard), findsNWidgets(4));
    },
  );

  testWidgets(
    'club failure is isolated; empty event status and club retry work',
    (tester) async {
      final events = Events(), clubs = Clubs()..fail = true;
      await mount(tester, events, clubs);
      expect(find.byType(EventGridCard), findsNWidgets(4));
      clubs.fail = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.byType(ClubGridCard), findsOneWidget);
      await reveal(tester, find.widgetWithText(ChoiceChip, 'Hết chỗ'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Hết chỗ'));
      await tester.pumpAndSettle();
      expect(events.calls.last.status, EventStatus.soldOut);
      expect(find.byType(EventGridCard), findsNothing);
      expect(find.textContaining('Chưa có sự kiện hết chỗ'), findsOneWidget);
    },
  );

  testWidgets(
    'late response from old status cannot overwrite the selected filter',
    (tester) async {
      final events = Events(), clubs = Clubs()..empty = true;
      await mount(tester, events, clubs);
      final pending = Completer<Page<XlandEvent>>();
      events.pending = pending;
      await tester.tap(find.widgetWithText(ChoiceChip, 'Hết chỗ'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      events.pending = null;
      await tester.tap(find.widgetWithText(ChoiceChip, 'Đang mở'));
      await tester.pumpAndSettle();
      pending.complete(
        Page(items: [event(9, status: EventStatus.soldOut)], hasMore: false),
      );
      await tester.pumpAndSettle();
      expect(find.byType(EventGridCard), findsNWidgets(4));
      expect(find.text('Sự kiện cộng đồng 9'), findsNothing);
    },
  );

  for (final width in [320.0, 390.0]) {
    testWidgets(
      'two columns have no overflow at width $width and text scale 2',
      (tester) async {
        await mount(tester, Events(), Clubs(), width: width, scale: 2);
        await reveal(tester, find.text('Xem thêm sự kiện'));
        expect(tester.takeException(), isNull);
        expect(find.byType(EventGridCard), findsNWidgets(4));
      },
    );
  }
}
