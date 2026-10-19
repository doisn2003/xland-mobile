import '../../domain/xland_domain.dart';

/// Development-only typed projection, applied AFTER the real HTTPS wire mapper.
/// Never weakens wire URL validation or changes API data, identity or mutations.
final class DemoMediaOverlay {
  DemoMediaOverlay(this.baseUrl, {this.scenario = 'normal',this.reportMode=false}) {
    if (baseUrl.scheme != 'http' ||
        !['localhost', '127.0.0.1', '10.0.2.2'].contains(baseUrl.host) ||
        !['normal', 'expired', 'unavailable'].contains(scenario)) {
      throw ArgumentError('Synthetic media requires an explicit local demo');
    }
  }
  final Uri baseUrl;
  final String scenario;
  final bool reportMode;
  FeedVideo video(FeedVideo v) {
    if (!v.isIllustrative ||
        !v.media.isIllustrative ||
        v.media.kind != MediaKind.video ||
        v.media.url != null) {
      return v;
    }
    final reportName=v.id.codeUnits.fold<int>(0,(sum,unit)=>sum+unit)%3==0 ? 'coastal' : 'countryside';
    final path = switch (scenario) {
      'expired' => '/expired',
      'unavailable' => '/broken',
      _ => reportMode ? '/report/$reportName.mp4' : '/demo-video.mp4',
    };
    return FeedVideo(
      id: v.id,
      propertyId: v.propertyId,
      author: v.author,
      media: MediaAsset(
        id: v.media.id,
        kind: v.media.kind,
        url: baseUrl.resolve(path),
        thumbnailUrl: baseUrl.resolve(reportMode ? '/report/$reportName.png' : '/demo-poster.png'),
        durationSeconds: reportMode ? 8 : 4,
        altText: 'Video minh họa, không phải cảnh đất thật',
        isIllustrative: true,
      ),
      caption: v.caption,
      approximateArea: v.approximateArea,
      property: v.property,
      likeCount: v.likeCount,
      commentCount: v.commentCount,
      viewCount: v.viewCount,
      isLiked: v.isLiked,
      isSaved: v.isSaved,
      publishedAt: v.publishedAt,
      isIllustrative: v.isIllustrative,
    );
  }

  Page<FeedVideo> page(Page<FeedVideo> p) => Page(
    items: p.items.map(video).toList(growable: false),
    hasMore: p.hasMore,
    nextCursor: p.nextCursor,
    total: p.total,
  );
}

final class DemoMediaFeedRepository implements FeedRepository {
  const DemoMediaFeedRepository(this.delegate, this.overlay);
  final FeedRepository delegate;
  final DemoMediaOverlay overlay;
  @override
  Future<Page<FeedVideo>> getFeed(
    PageQuery page, {
    FeedScope feedScope = FeedScope.recommended,
    Region? region,
    PropertyCategory? category,
  }) async => overlay.page(
    await delegate.getFeed(
      page,
      feedScope: feedScope,
      region: region,
      category: category,
    ),
  );
  @override
  Future<FeedVideo> getVideo(String videoId) async =>
      overlay.video(await delegate.getVideo(videoId));
  @override
  Future<Page<FeedVideo>> getSavedVideos(PageQuery page) async =>
      overlay.page(await delegate.getSavedVideos(page));
  @override
  Future<MutationResult> setLiked(String videoId, bool liked) =>
      delegate.setLiked(videoId, liked);
  @override
  Future<MutationResult> setSaved(String videoId, bool saved) =>
      delegate.setSaved(videoId, saved);
  @override
  Future<Page<VideoComment>> getComments(String videoId, PageQuery page) =>
      delegate.getComments(videoId, page);
  @override
  Future<VideoComment> addComment(
    String videoId,
    String text, {
    required String idempotencyKey,
  }) => delegate.addComment(videoId, text, idempotencyKey: idempotencyKey);
  @override
  Future<void> deleteComment(String videoId, String commentId) =>
      delegate.deleteComment(videoId, commentId);
  @override
  Future<MutationResult> setFollowing(String authorId, bool following) =>
      delegate.setFollowing(authorId, following);
  @override
  Future<Page<PublicAuthor>> getFollowing(PageQuery page) =>
      delegate.getFollowing(page);
  @override
  Future<ShareLink> getShareLink(String videoId) =>
      delegate.getShareLink(videoId);
}

final class DemoMediaConsultantRepository implements ConsultantRepository {
  const DemoMediaConsultantRepository(this.delegate, this.overlay);
  final ConsultantRepository delegate;
  final DemoMediaOverlay overlay;
  @override
  Future<Consultant> getConsultant(String id) => delegate.getConsultant(id);
  @override
  Future<Page<FeedVideo>> getVideos(String id, PageQuery page) async =>
      overlay.page(await delegate.getVideos(id, page));
  @override
  Future<Page<Property>> getListings(String id, PageQuery page) =>
      delegate.getListings(id, page);
  @override
  Future<Page<ConsultantReview>> getReviews(String id, PageQuery page) =>
      delegate.getReviews(id, page);
  @override
  Future<List<AvailabilitySlot>> getAvailability(
    String id,
    String fromDate,
    String toDate,
  ) => delegate.getAvailability(id, fromDate, toDate);
}
