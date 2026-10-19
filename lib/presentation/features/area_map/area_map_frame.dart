export 'area_map_frame_stub.dart'
    if (dart.library.io) 'area_map_frame_native.dart'
    if (dart.library.js_interop) 'area_map_frame_web.dart';
