import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/xland_domain.dart';

class VideoLikeState {
  const VideoLikeState({
    required this.liked,
    required this.count,
    this.pending = false,
  });
  final bool liked;
  final int count;
  final bool pending;
}

/// Owned by the feed, so scrolling can dispose a player without losing a write.
/// A new account gets new instances; late responses cannot revive closed state.
class VideoLikeCubit extends Cubit<VideoLikeState> {
  VideoLikeCubit(FeedVideo video, this._repository)
    : videoId = video.id,
      super(VideoLikeState(liked: video.isLiked, count: video.likeCount));

  final String videoId;
  final FeedRepository _repository;

  Future<void> toggle() async {
    if (isClosed || state.pending) return;
    final before = state;
    final liked = !before.liked;
    final optimisticCount = liked
        ? before.count + 1
        : (before.count > 0 ? before.count - 1 : 0);
    emit(VideoLikeState(liked: liked, count: optimisticCount, pending: true));
    try {
      final result = await _repository.setLiked(videoId, liked);
      if (isClosed) return;
      emit(
        VideoLikeState(
          liked: result.active,
          count:
              result.count ??
              (result.active == liked ? optimisticCount : before.count),
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(before);
      rethrow;
    }
  }
}
