import 'package:flutter/material.dart' hide Page;

import '../../../../domain/xland_domain.dart';
import '../../../shared/di/dependencies_scope.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/theme.dart';
import '../../clubs/pages/club_detail_page.dart';
import '../widgets/community_cards.dart';
import 'event_detail_page.dart';

/// Clubs first, followed by four events per page in two columns.
class EventsTabPage extends StatefulWidget {
  const EventsTabPage({super.key});
  @override
  State<EventsTabPage> createState() => _EventsTabPageState();
}

class _EventsTabPageState extends State<EventsTabPage> {
  final _clubs = _Collection<Club>();
  final _events = _Collection<XlandEvent>();
  EventStatus _status = EventStatus.open;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    await Future.wait([_loadClubs(reset: true), _loadEvents(reset: true)]);
  }

  Future<void> _loadClubs({bool reset = false}) async {
    final deps = DependenciesScope.maybeOf(context);
    if (deps == null) return;
    await _load(_clubs, deps.clubs.getClubs, (c) => c.id, reset: reset);
  }

  Future<void> _loadEvents({bool reset = false}) async {
    final deps = DependenciesScope.maybeOf(context);
    if (deps == null) return;
    final status = _status;
    await _load(
      _events,
      (q) => deps.events.getEvents(q, status: status),
      (e) => e.id,
      reset: reset,
    );
  }

  Future<void> _load<T>(
    _Collection<T> collection,
    Future<Page<T>> Function(PageQuery) fetch,
    String Function(T) id, {
    required bool reset,
  }) async {
    if (!mounted || (!reset && collection.loading)) return;
    final generation = ++collection.generation;
    setState(() {
      collection.loading = true;
      collection.error = false;
      if (reset) {
        collection.items = [];
        collection.cursor = null;
        collection.hasMore = false;
      }
    });
    try {
      final page = await fetch(PageQuery(limit: 4, cursor: collection.cursor));
      if (!mounted || generation != collection.generation) return;
      setState(() {
        collection.items = {
          for (final item in [...collection.items, ...page.items])
            id(item): item,
        }.values.toList();
        collection.cursor = page.nextCursor;
        collection.hasMore = page.hasMore && page.nextCursor != null;
        collection.loading = false;
      });
    } catch (_) {
      if (!mounted || generation != collection.generation) return;
      setState(() {
        collection.error = true;
        collection.loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const XLandAppBar(variant: XLandAppBarVariant.light, title: 'Sự kiện'),
      Expanded(
        child: RefreshIndicator(
          color: AppColors.brandPrimary,
          onRefresh: _refresh,
          child: ListView(
            key: const PageStorageKey('community-discovery'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Text(
                'Gặp gỡ. Chia sẻ. Kết nối.',
                style: AppTypography.pageHero.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 6),
              Text(
                'Tìm cộng đồng của bạn, khám phá những trải nghiệm mới.',
                style: AppTypography.compact.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              const _SectionHeading(
                icon: Icons.groups_outlined,
                title: 'Câu lạc bộ',
                subtitle: 'Cùng sở thích, thêm kết nối',
              ),
              const SizedBox(height: 12),
              _section<Club>(
                collection: _clubs,
                label: 'câu lạc bộ',
                empty: 'Các câu lạc bộ mới sẽ sớm có mặt tại đây.',
                load: _loadClubs,
                card: (club) => ClubGridCard(
                  club: club,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ClubDetailPage(clubId: club.id),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),
              const _SectionHeading(
                icon: Icons.event_outlined,
                title: 'Sự kiện XLand',
                subtitle: 'Học hỏi và trải nghiệm cùng nhau',
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final status in EventStatus.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(eventStatusLabel(status)),
                          selected: _status == status,
                          selectedColor: AppColors.brandPrimary,
                          labelStyle: AppTypography.compactStrong.copyWith(
                            color: _status == status
                                ? AppColors.onPrimary
                                : AppColors.textSecondary,
                          ),
                          showCheckmark: false,
                          onSelected: (selected) {
                            if (!selected) return;
                            setState(() => _status = status);
                            _loadEvents(reset: true);
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _section<XlandEvent>(
                collection: _events,
                label: 'sự kiện',
                empty:
                    'Chưa có sự kiện ${eventStatusLabel(_status).toLowerCase()}.\nHãy khám phá các mục khác hoặc quay lại sau.',
                load: _loadEvents,
                card: (event) => EventGridCard(
                  event: event,
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => EventDetailPage(eventId: event.id),
                      ),
                    );
                    if (mounted) await _loadEvents(reset: true);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _section<T>({
    required _Collection<T> collection,
    required String label,
    required String empty,
    required Future<void> Function() load,
    required Widget Function(T) card,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (collection.items.isNotEmpty)
        CommunityGrid(children: collection.items.map(card).toList()),
      if (collection.loading)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Đang tải $label',
              color: AppColors.brandPrimary,
            ),
          ),
        )
      else if (collection.error)
        _CollectionNotice(
          icon: Icons.wifi_off_rounded,
          message: 'Chưa thể tải $label. Vui lòng thử lại.',
          action: TextButton.icon(
            onPressed: load,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        )
      else if (collection.items.isEmpty)
        _CollectionNotice(icon: Icons.explore_outlined, message: empty)
      else if (collection.hasMore)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: OutlinedButton.icon(
            onPressed: load,
            icon: const Icon(Icons.expand_more),
            label: Text('Xem thêm $label'),
          ),
        ),
    ],
  );
}

class _Collection<T> {
  List<T> items = [];
  String? cursor;
  bool loading = false;
  bool error = false;
  bool hasMore = false;
  int generation = 0;
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.verifiedSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.brandPrimary, size: 22),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.sectionTitle),
            Text(
              subtitle,
              style: AppTypography.compact.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _CollectionNotice extends StatelessWidget {
  const _CollectionNotice({
    required this.icon,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Icon(icon, color: AppColors.textSecondary),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.compact,
        ),
        ?action,
      ],
    ),
  );
}
