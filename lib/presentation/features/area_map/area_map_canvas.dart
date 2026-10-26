import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../domain/maps/area_map.dart';
import '../../theme/theme.dart';
import 'area_map_scope.dart';

class AreaMapView {
  const AreaMapView(this.center, this.zoom, this.planningEnabled, this.opacity);
  final LatLng center;
  final double zoom, opacity;
  final bool planningEnabled;
}

/// The centre is an administrative area, never an inferred parcel marker.
class AreaMapCanvas extends StatefulWidget {
  const AreaMapCanvas({
    super.key,
    required this.map,
    required this.onLoaded,
    required this.onError,
    this.tileProvider,
    this.openLink,
    this.fullscreen = false,
    this.initialView,
    this.onViewChanged,
  });
  final AreaMapPresentation map;
  final VoidCallback onLoaded;
  final ValueChanged<String> onError;
  final TileProvider? tileProvider;
  final Future<bool> Function(Uri)? openLink;
  final bool fullscreen;
  final AreaMapView? initialView;
  final ValueChanged<AreaMapView>? onViewChanged;

  @override
  State<AreaMapCanvas> createState() => _AreaMapCanvasState();
}

class _AreaMapCanvasState extends State<AreaMapCanvas> {
  final _controller = MapController();
  TileProvider? _tiles;
  bool _reportedLoaded = false, _reportedError = false, _mapReady = false;
  late bool _enabled;
  late double _opacity;
  bool _planningLoading = false, _withinCoverage = true, _aboveMinZoom = true;
  bool _planningTimedOut = false;
  String? _planningError;
  int _attempt = 0;
  Timer? _deadline;

  PlanningSource? get _source =>
      widget.map.planning?.isReady == true ? widget.map.planning!.source : null;
  LatLng get _areaCenter =>
      LatLng(widget.map.area!.latitude, widget.map.area!.longitude);

  @override
  void initState() {
    super.initState();
    _enabled =
        _source != null && (widget.initialView?.planningEnabled ?? false);
    _opacity = widget.initialView?.opacity ?? 0.7;
    if (_enabled) _startLoading();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tiles ??= widget.tileProvider ?? AreaMapScope.tileProvider(context);
  }

  @override
  void dispose() {
    _deadline?.cancel();
    _controller.dispose();
    super.dispose();
  }

  AreaMapView get _view => AreaMapView(
    _mapReady ? _controller.camera.center : _areaCenter,
    _mapReady
        ? _controller.camera.zoom
        : widget.map.area!.initialZoom.toDouble(),
    _enabled,
    _opacity,
  );

  void _startLoading() {
    _deadline?.cancel();
    _attempt++;
    _planningError = null;
    _planningTimedOut = false;
    _planningLoading = true;
    final attempt = _attempt;
    _deadline = Timer(const Duration(seconds: 15), () {
      if (!mounted || !_enabled || !_planningLoading || attempt != _attempt) {
        return;
      }
      setState(() {
        _planningLoading = false;
        _planningTimedOut = true;
        _planningError =
            'Lớp quy hoạch tải quá lâu. Bạn vẫn có thể xem bản đồ nền.';
      });
    });
  }

  void _toggle(bool enabled) {
    setState(() {
      _enabled = enabled;
      if (enabled) {
        _startLoading();
      } else {
        _deadline?.cancel();
        _attempt++;
        _planningLoading = false;
        _planningError = null;
      }
    });
    if (enabled && _mapReady && _controller.camera.zoom < _source!.minZoom) {
      _controller.move(_controller.camera.center, _source!.minZoom.toDouble());
    }
    widget.onViewChanged?.call(_view);
  }

  void _positionChanged(MapCamera camera, bool hasGesture) {
    final bounds = _source?.coverageBounds;
    final visible = camera.visibleBounds;
    final within =
        bounds == null ||
        (visible.south < bounds.north &&
            visible.north > bounds.south &&
            visible.west < bounds.east &&
            visible.east > bounds.west);
    final above = _source == null || camera.zoom >= _source!.minZoom;
    if (within != _withinCoverage || above != _aboveMinZoom) {
      setState(() {
        _withinCoverage = within;
        _aboveMinZoom = above;
        if (_enabled && within && above) _startLoading();
      });
    }
    widget.onViewChanged?.call(
      AreaMapView(camera.center, camera.zoom, _enabled, _opacity),
    );
  }

  Future<void> _open(Uri url) async {
    var opened = false;
    try {
      opened =
          await (widget.openLink?.call(url) ??
              launchUrl(url, mode: LaunchMode.externalApplication));
    } catch (_) {
      /* Show a user-facing failure below. */
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa mở được nguồn quy hoạch. Hãy thử lại.'),
        ),
      );
    }
  }

  void _showLegend() {
    final source = _source!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Chú giải quy hoạch', style: AppTypography.sectionTitle),
              const SizedBox(height: AppSpacing.s12),
              const Text(
                'Ký hiệu và màu sắc phụ thuộc từng đồ án. Đối chiếu với chú giải của đồ án; không suy luận loại đất chỉ từ màu sắc.',
              ),
              const SizedBox(height: AppSpacing.s8),
              const Text(
                'Kéo thanh độ đậm về 0% để xem nền, tới 100% để đọc rõ lớp quy hoạch. Vùng không có màu có thể chưa có dữ liệu.',
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(_publicationLabel(source)),
            ],
          ),
        ),
      ),
    );
  }

  String _publicationLabel(PlanningSource source) {
    final date = source.publishedAt;
    return date == null
        ? 'Nguồn chưa cung cấp ngày công bố dữ liệu.'
        : 'Ngày công bố dữ liệu: ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _openFullscreen() async {
    var latest = _view;
    final repository = AreaMapScope.of(context);
    TileProvider createProvider() => AreaMapScope.tileProvider(context);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Bản đồ khu vực')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.s12),
              child: AreaMapScope(
                repository: repository,
                createTileProvider: createProvider,
                child: AreaMapCanvas(
                  map: widget.map,
                  fullscreen: true,
                  initialView: latest,
                  onViewChanged: (view) => latest = view,
                  openLink: widget.openLink,
                  onLoaded: () {},
                  onError: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _enabled = latest.planningEnabled;
      _opacity = latest.opacity;
      if (_enabled) {
        _startLoading();
      } else {
        _deadline?.cancel();
        _planningLoading = false;
      }
    });
    _controller.move(latest.center, latest.zoom);
  }

  @override
  Widget build(BuildContext context) {
    final planning = widget.map.planning;
    final source = _source;
    final attempt = _attempt;
    final mapMaxZoom = source?.maxNativeZoom.toDouble() ?? 16.0;
    final bounds = source?.coverageBounds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (planning != null) ...[
          if (source != null)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Xem quy hoạch'),
              // subtitle: const Text('Lớp phủ quy hoạch khu vực'),
              value: _enabled,
              onChanged: _toggle,
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s12),
              child: Text(planning.notice),
            ),
          if (_enabled && source != null) ...[
            Text(
              'Độ đậm quy hoạch: ${(_opacity * 100).round()}%',
              style: AppTypography.bodyStrong,
            ),
            Slider(
              key: const ValueKey('planning-opacity'),
              value: _opacity,
              label: '${(_opacity * 100).round()}%',
              divisions: 50,
              semanticFormatterCallback: (value) =>
                  '${(value * 100).round()} phần trăm',
              onChanged: (value) {
                setState(() => _opacity = value);
                widget.onViewChanged?.call(_view);
              },
            ),
            if (!_withinCoverage)
              const Text('Chưa có dữ liệu quy hoạch trong vùng đang xem.')
            else if (!_aboveMinZoom)
              Text('Phóng to từ mức ${source.minZoom} để xem quy hoạch.')
            else if (_planningLoading)
              const LinearProgressIndicator(
                semanticsLabel: 'Đang tải lớp quy hoạch',
              ),
            if (_planningError != null && _withinCoverage && _aboveMinZoom) ...[
              Text(_planningError!, style: AppTypography.compact),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(_startLoading),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại lớp quy hoạch'),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.s8),
          ],
        ],
        ClipRRect(
          // Controls appear above/below the map as the overlay loads. Keep the
          // map mounted so its camera and TileLayer-owned HTTP clients survive.
          key: const ValueKey('area-map-surface'),
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: SizedBox(
            height: widget.fullscreen
                ? math.max(300.0, MediaQuery.sizeOf(context).height * 0.55)
                : 300,
            child: FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: widget.initialView?.center ?? _areaCenter,
                initialZoom:
                    widget.initialView?.zoom ??
                    widget.map.area!.initialZoom.toDouble(),
                minZoom: 6,
                maxZoom: mapMaxZoom,
                onMapReady: () {
                  _mapReady = true;
                  _positionChanged(_controller.camera, false);
                },
                onPositionChanged: _positionChanged,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: widget.map.tileUrlTemplate,
                  tileProvider: _tiles,
                  userAgentPackageName: 'vn.xland.xland_mobile',
                  // Retain the existing Geoapify quota/zoom contract; enlarge its z16 tiles at z17+.
                  maxZoom: mapMaxZoom,
                  maxNativeZoom: 16,
                  panBuffer: 0,
                  keepBuffer: 1,
                  errorTileCallback: (_, _, _) {
                    if (_reportedError) return;
                    _reportedError = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        widget.onError(
                          'Một phần bản đồ nền chưa tải được hoặc đã đạt hạn mức trong ngày.',
                        );
                        if (widget.fullscreen) setState(() {});
                      }
                    });
                  },
                  tileBuilder: (_, tile, image) => ListenableBuilder(
                    listenable: image,
                    child: tile,
                    builder: (_, child) {
                      if (!_reportedLoaded &&
                          image.loadFinishedAt != null &&
                          !image.loadError) {
                        _reportedLoaded = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) widget.onLoaded();
                        });
                      }
                      return child!;
                    },
                  ),
                ),
                if (_enabled &&
                    source != null &&
                    _withinCoverage &&
                    _aboveMinZoom)
                  Opacity(
                    key: const ValueKey('planning-layer-opacity'),
                    opacity: _opacity,
                    child: _PlanningTiles(
                      key: ValueKey((source.revision, attempt)),
                      source: source,
                      bounds: bounds == null
                          ? null
                          : LatLngBounds(
                              LatLng(bounds.south, bounds.west),
                              LatLng(bounds.north, bounds.east),
                            ),
                      onLoaded: () {
                        if (!mounted ||
                            !_enabled ||
                            attempt != _attempt ||
                            (!_planningLoading && !_planningTimedOut)) {
                          return;
                        }
                        _deadline?.cancel();
                        setState(() {
                          _planningLoading = false;
                          if (_planningTimedOut) _planningError = null;
                          _planningTimedOut = false;
                        });
                      },
                      onError: () {
                        if (!mounted ||
                            !_enabled ||
                            attempt != _attempt ||
                            (_planningError != null && !_planningTimedOut)) {
                          return;
                        }
                        _deadline?.cancel();
                        setState(() {
                          _planningLoading = false;
                          _planningTimedOut = false;
                          _planningError = 'Một phần lớp quy hoạch chưa có dữ liệu hoặc chưa tải được. Bản đồ nền vẫn sử dụng được.';
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        Wrap(
          spacing: AppSpacing.s8,
          children: [
            TextButton.icon(
              onPressed: () => _controller.move(
                _areaCenter,
                _enabled
                    ? math.max(
                        widget.map.area!.initialZoom.toDouble(),
                        source!.minZoom.toDouble(),
                      )
                    : widget.map.area!.initialZoom.toDouble(),
              ),
              icon: const Icon(Icons.center_focus_strong),
              label: const Text('Về khu vực'),
            ),
            if (!widget.fullscreen)
              TextButton.icon(
                onPressed: _openFullscreen,
                icon: const Icon(Icons.fullscreen),
                label: const Text('Xem toàn màn hình'),
              ),
            if (_enabled && source != null)
              TextButton.icon(
                onPressed: _showLegend,
                icon: const Icon(Icons.info_outline),
                label: const Text('Chú giải'),
              ),
          ],
        ),
        if (_enabled && source != null) ...[
          Text(planning!.notice, style: AppTypography.compact),
          Text(_publicationLabel(source), style: AppTypography.compact),
        ],
        if (widget.fullscreen) ...[
          
          Wrap(
            children: [
              for (final credit in widget.map.attributions)
                TextButton(
                  onPressed: () => _open(credit.url),
                  child: Text(credit.label, style: AppTypography.compact),
                ),
            ],
          ),
          if (_reportedError)
            const Text(
              'Một phần bản đồ nền chưa tải được. Hãy kiểm tra kết nối và thử lại.',
            ),
        ],
      ],
    );
  }
}

/// Owns a separate transport per layer lifetime. Opacity changes retain this state.
class _PlanningTiles extends StatefulWidget {
  const _PlanningTiles({
    super.key,
    required this.source,
    required this.bounds,
    required this.onLoaded,
    required this.onError,
  });
  final PlanningSource source;
  final LatLngBounds? bounds;
  final VoidCallback onLoaded, onError;
  @override
  State<_PlanningTiles> createState() => _PlanningTilesState();
}

class _PlanningTilesState extends State<_PlanningTiles> {
  TileProvider? _provider;
  bool _loaded = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider ??= AreaMapScope.tileProvider(context);
  }

  @override
  Widget build(BuildContext context) => TileLayer(
    urlTemplate: widget.source.tileUrlTemplate,
    tileProvider: _provider,
    userAgentPackageName: 'vn.xland.xland_mobile',
    minZoom: widget.source.minZoom.toDouble(),
    minNativeZoom: widget.source.minZoom,
    maxZoom: widget.source.maxNativeZoom.toDouble(),
    maxNativeZoom: widget.source.maxNativeZoom,
    tileBounds: widget.bounds,
    panBuffer: 0,
    keepBuffer: 1,
    retinaMode: false,
    errorTileCallback: (_, _, _) =>
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onError();
        }),
    tileBuilder: (_, tile, image) => ListenableBuilder(
      listenable: image,
      child: tile,
      builder: (_, child) {
        if (!_loaded && image.loadFinishedAt != null && !image.loadError) {
          _loaded = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onLoaded();
          });
        }
        return child!;
      },
    ),
  );
}
