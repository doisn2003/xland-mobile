import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../domain/maps/area_map.dart';
import '../../theme/theme.dart';
import 'area_map_cubit.dart';
import 'area_map_scope.dart';

typedef AreaMapBuilder = Widget Function(
  AreaMapPresentation map,
  VoidCallback loaded,
  ValueChanged<String> failed,
);
typedef AreaLinkLauncher = Future<bool> Function(Uri uri);
Future<bool> _launch(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

class AreaMapPanel extends StatelessWidget {
  const AreaMapPanel({
    super.key,
    required this.propertyId,
    this.mapBuilder,
    this.openLink = _launch,
  });
  final String propertyId;
  final AreaMapBuilder? mapBuilder;
  final AreaLinkLauncher openLink;
  @override
  Widget build(BuildContext context) {
    final repository = AreaMapScope.of(context);
    return BlocProvider(
      key: ValueKey((repository, propertyId)),
      create: (_) => AreaMapCubit(repository, propertyId)..load(),
      child: BlocBuilder<AreaMapCubit, AreaMapState>(
        builder: (context, state) {
          final map = state.map;
          Future<void> open(Uri uri) async {
            var success = false;
            try {
              success = await openLink(uri);
            } catch (_) {
              /* Visible failure below. */
            }
            if (!success && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Chưa mở được liên kết. Hãy kiểm tra ứng dụng bản đồ hoặc trình duyệt.',
                  ),
                ),
              );
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Bản đồ khu vực', style: AppTypography.sectionTitle),
              const SizedBox(height: AppSpacing.s8),
              const Text(
                'Khu vực tham khảo theo xã/phường; không thể hiện vị trí lô đất.',
              ),
              if (map?.areaLabel != null) ...[
                const SizedBox(height: AppSpacing.s8),
                Text(map!.areaLabel!, style: AppTypography.bodyStrong),
              ],
              const SizedBox(height: AppSpacing.s12),
              if (state.loading)
                const SizedBox(
                  height: 240,
                  child: Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Đang tìm khu vực',
                    ),
                  ),
                )
              else if (state.error != null || map?.isReady != true) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  decoration: BoxDecoration(
                    color: AppColors.disabledSurface,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Text(
                    state.error?.message ??
                        map?.notice ??
                        'Chưa tải được bản đồ',
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: context.read<AreaMapCubit>().load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại bản đồ'),
                  ),
                ),
              ] else ...[
                _ObservedAreaMap(
                  key: ValueKey((map!.propertyId, map.area!.id)),
                  map: map,
                  builder: mapBuilder,
                ),
                Wrap(
                  spacing: AppSpacing.s8,
                  children: [
                    for (final credit in map.attributions)
                      TextButton(
                        onPressed: () => open(credit.url),
                        child: Text(credit.label, style: AppTypography.compact),
                      ),
                  ],
                ),
              ],
              if (map?.externalAreaMapUrl != null) ...[
                Wrap(
                  spacing: AppSpacing.s8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => open(map!.externalAreaMapUrl!),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Mở Google Maps'),
                    ),
                    if (map?.externalDirectionsUrl != null)
                      OutlinedButton.icon(
                        onPressed: () => open(map!.externalDirectionsUrl!),
                        icon: const Icon(Icons.directions_outlined),
                        label: const Text('Chỉ đường tới khu vực'),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  'Google Maps tìm theo tên xã/phường và tỉnh/thành. Điểm đến không phải vị trí lô đất hay điểm hẹn xem thực địa.',
                  style: AppTypography.compact,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ObservedAreaMap extends StatefulWidget {
  const _ObservedAreaMap({super.key, required this.map, this.builder});
  final AreaMapPresentation map;
  final AreaMapBuilder? builder;
  @override
  State<_ObservedAreaMap> createState() => _ObservedAreaMapState();
}

class _ObservedAreaMapState extends State<_ObservedAreaMap> {
  Timer? _timer;
  bool _loading = true;
  String? _error;
  int _attempt = 0;
  @override
  void initState() {
    super.initState();
    _deadline();
  }

  void _deadline() {
    _timer?.cancel();
    _timer = Timer(
      const Duration(seconds: 20),
      () =>
          _failed('Tải bản đồ quá thời gian. Hãy thử lại hoặc mở Google Maps.'),
    );
  }

  void _loaded() {
    if (!mounted || !_loading) return;
    _timer?.cancel();
    setState(() => _loading = false);
  }

  void _failed(String message) {
    if (!mounted) return;
    _timer?.cancel();
    setState(() {
      _loading = false;
      _error = message;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (_loading)
        const LinearProgressIndicator(semanticsLabel: 'Đang tải bản đồ'),
      KeyedSubtree(
        key: ValueKey(_attempt),
        child:
            widget.builder?.call(widget.map, _loaded, _failed) ??
            AreaMapCanvas(map: widget.map, onLoaded: _loaded, onError: _failed),
      ),
      if (_error != null) ...[
        Text(_error!, style: AppTypography.compact),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _attempt++;
              _error = null;
              _loading = true;
            });
            _deadline();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Tải lại bản đồ'),
        ),
      ],
    ],
  );
}

/// Administrative centre only: no property pin, GPS request or parcel boundary.
class AreaMapCanvas extends StatefulWidget {
  const AreaMapCanvas({
    super.key,
    required this.map,
    required this.onLoaded,
    required this.onError,
    this.tileProvider,
  });
  final AreaMapPresentation map;
  final VoidCallback onLoaded;
  final ValueChanged<String> onError;
  final TileProvider? tileProvider;
  @override
  State<AreaMapCanvas> createState() => _AreaMapCanvasState();
}

class _AreaMapCanvasState extends State<AreaMapCanvas> {
  final _controller = MapController();
  TileProvider? _tiles;
  bool _reportedLoaded = false, _reportedError = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tiles ??= widget.tileProvider ?? AreaMapScope.tileProvider(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final area = widget.map.area!;
    final center = LatLng(area.latitude, area.longitude);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: SizedBox(
            height: 300,
            child: FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: center,
                initialZoom: area.initialZoom.toDouble(),
                minZoom: 6,
                maxZoom: 16,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: widget.map.tileUrlTemplate,
                  tileProvider: _tiles,
                  userAgentPackageName: 'vn.xland.xland_mobile',
                  maxZoom: 16,
                  maxNativeZoom: 16,
                  panBuffer: 0,
                  keepBuffer: 1,
                  errorTileCallback: (_, _, _) {
                    if (_reportedError) return;
                    _reportedError = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        widget.onError(
                          'Một phần bản đồ chưa tải được hoặc đã đạt hạn mức trong ngày. Bạn có thể thử lại hoặc mở Google Maps.',
                        );
                      }
                    });
                  },
                  tileBuilder: (_, tile, image) {
                    if (!_reportedLoaded &&
                        image.loadFinishedAt != null &&
                        !image.loadError) {
                      _reportedLoaded = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) widget.onLoaded();
                      });
                    }
                    return tile;
                  },
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () =>
                _controller.move(center, area.initialZoom.toDouble()),
            icon: const Icon(Icons.center_focus_strong),
            label: const Text('Về khu vực'),
          ),
        ),
      ],
    );
  }
}
