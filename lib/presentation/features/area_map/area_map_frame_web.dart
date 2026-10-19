import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

class AreaMapFrame extends StatefulWidget {
  const AreaMapFrame({
    super.key,
    required this.url,
    required this.onFrameLoaded,
    required this.onFrameError,
  });
  final Uri url;
  final VoidCallback onFrameLoaded;
  final ValueChanged<String> onFrameError;
  @override
  State<AreaMapFrame> createState() => _AreaMapFrameState();
}

class _AreaMapFrameState extends State<AreaMapFrame> {
  static int _sequence = 0;
  late final String _viewType;
  late final web.HTMLIFrameElement _frame;
  late final JSFunction _onLoad;
  late final JSFunction _onError;
  @override
  void initState() {
    super.initState();
    _viewType = 'xland-area-map-${_sequence++}';
    _frame = web.HTMLIFrameElement()
      ..title = 'Google Maps — bản đồ khu vực tham khảo'
      ..src = widget.url.toString()
      ..referrerPolicy = 'strict-origin-when-cross-origin'
      ..allow = 'geolocation \'none\'; camera \'none\'; microphone \'none\'';
    _frame.style
      ..border = '0'
      ..width = '100%'
      ..height = '100%'
      ..minHeight = '200px';
    _onLoad = ((web.Event event) {
      if (mounted) widget.onFrameLoaded();
    }).toJS;
    _onError = ((web.Event event) {
      if (mounted) widget.onFrameError('Không mở được khung bản đồ');
    }).toJS;
    _frame.addEventListener('load', _onLoad);
    _frame.addEventListener('error', _onError);
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _frame,
    );
  }

  @override
  void dispose() {
    _frame.removeEventListener('load', _onLoad);
    _frame.removeEventListener('error', _onError);
    _frame.src = 'about:blank';
    _frame.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
