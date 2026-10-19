import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/maps/area_map.dart';
import '../../../domain/failures/xland_failure.dart';

class AreaMapState {
  const AreaMapState({
    this.loading = false,
    this.map,
    this.error,
    this.category = AreaMapCategory.all,
  });
  final bool loading;
  final AreaMapPresentation? map;
  final XlandFailure? error;
  final AreaMapCategory category;
}

class AreaMapCubit extends Cubit<AreaMapState> {
  AreaMapCubit(this.repository, this.propertyId) : super(const AreaMapState());
  final AreaMapRepository repository;
  final String propertyId;
  int _generation = 0;
  Future<void> load() async {
    final generation = ++_generation;
    emit(const AreaMapState(loading: true));
    try {
      final map = await repository.getAreaMap(propertyId);
      if (isClosed || generation != _generation) return;
      if (map.propertyId != propertyId) {
        throw const XlandFailure(
          code: FailureCode.internalError,
          message: 'Dữ liệu bản đồ không thuộc lô đang xem',
        );
      }
      emit(AreaMapState(map: map));
    } on XlandFailure catch (error) {
      if (!isClosed && generation == _generation) {
        emit(AreaMapState(error: error));
      }
    } catch (_) {
      if (!isClosed && generation == _generation) {
        emit(
          const AreaMapState(
            error: XlandFailure(
              code: FailureCode.upstreamUnavailable,
              message: 'Chưa tải được bản đồ khu vực',
            ),
          ),
        );
      }
    }
  }

  void select(AreaMapCategory category) {
    if (state.map?.isReady != true) return;
    emit(AreaMapState(map: state.map, category: category));
  }

  @override
  Future<void> close() {
    _generation++;
    return super.close();
  }
}
