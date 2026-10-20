import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../domain/xland_domain.dart';
import '../../../shared/di/dependencies_scope.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/theme.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import '../../auth/widgets/login_prompt_sheet.dart';

/// Modal bottom sheet for viewing and adding comments to a feed video.
class CommentsSheet extends StatefulWidget {
  const CommentsSheet({
    super.key,
    required this.videoId,
  });

  final String videoId;

  static Future<void> show(BuildContext context, {required String videoId}) {
    return showXLandBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(videoId: videoId),
    );
  }

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = true;
  String? _errorMessage;
  List<VideoComment> _comments = [];
  bool _isSending = false;

  String? _activeCommentKey;
  String? _lastCommentText;
  String? _lastCommentVideoId;
  String? _lastCommentUserId;

  String? _nextCursor;
  bool _hasMore = false;
  bool _isLoadingMore = false;
  String? _loadMoreError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadComments();
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    if (!mounted) return;
    final deps = DependenciesScope.of(context);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final page = await deps.feed.getComments(widget.videoId, const PageQuery(limit: 20));
      if (!mounted) return;
      setState(() {
        _comments = page.items;
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
        _isLoading = false;
      });
    } on XlandFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không thể tải bình luận: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreComments() async {
    if (_isLoadingMore || !_hasMore) return;
    final deps = DependenciesScope.of(context);
    setState(() {
      _isLoadingMore = true;
      _loadMoreError = null;
    });

    try {
      final page = await deps.feed.getComments(
        widget.videoId,
        PageQuery(cursor: _nextCursor, limit: 20),
      );
      if (!mounted) return;
      final existingIds = _comments.map((c) => c.id).toSet();
      final newItems = page.items.where((c) => !existingIds.contains(c.id)).toList();
      setState(() {
        _comments = [..._comments, ...newItems];
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
        _isLoadingMore = false;
      });
    } on XlandFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _loadMoreError = e.message;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadMoreError = 'Lỗi tải thêm: $e';
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _handleSendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSending) return;

    var authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) {
      final didLogin = await LoginPromptSheet.show(
        context,
        title: 'Đăng nhập để bình luận',
        message: 'Vui lòng đăng nhập để gửi câu hỏi hoặc trao đổi cùng cộng đồng.',
      );
      if (!didLogin || !mounted) return;
      authState = context.read<AuthCubit>().state;
      if (authState is! AuthAuthenticated) return;
    }

    final currentUserId = authState.session.profile.id;
    final isRetrySamePayload = _activeCommentKey != null &&
        _lastCommentText == text &&
        _lastCommentVideoId == widget.videoId &&
        _lastCommentUserId == currentUserId;

    final key = isRetrySamePayload
        ? _activeCommentKey!
        : 'cmt-${widget.videoId}-${DateTime.now().millisecondsSinceEpoch}';

    _activeCommentKey = key;
    _lastCommentText = text;
    _lastCommentVideoId = widget.videoId;
    _lastCommentUserId = currentUserId;

    final deps = DependenciesScope.of(context);
    setState(() => _isSending = true);

    try {
      final newComment = await deps.feed.addComment(
        widget.videoId,
        text,
        idempotencyKey: key,
      );

      if (!mounted) return;
      _commentController.clear();
      _activeCommentKey = null;
      _lastCommentText = null;
      _lastCommentVideoId = null;
      _lastCommentUserId = null;
      setState(() {
        _comments = [newComment, ..._comments];
        _isSending = false;
      });
    } on XlandFailure catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể gửi bình luận: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheetTop)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pageGutter,
        AppSpacing.s16,
        AppSpacing.pageGutter,
        bottomInset + AppSpacing.s12,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Bình luận (${_comments.length})', style: AppTypography.sheetTitle),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: AppSpacing.s16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.brandPrimary))
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 36),
                            const SizedBox(height: 8),
                            Text(_errorMessage!, style: AppTypography.body, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            PrimaryButton(label: 'Thử lại', onPressed: _loadComments),
                          ],
                        ),
                      )
                    : _comments.isEmpty
                        ? Center(
                            child: Text(
                              'Chưa có bình luận nào. Hãy là người đầu tiên đặt câu hỏi!',
                              style: AppTypography.compact.copyWith(color: AppColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.separated(
                            itemCount: _comments.length + (_hasMore ? 1 : 0),
                            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.s12),
                            itemBuilder: (context, idx) {
                              if (idx == _comments.length) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: _isLoadingMore
                                        ? const SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.brandPrimary,
                                            ),
                                          )
                                        : _loadMoreError != null
                                            ? TextButton.icon(
                                                onPressed: _loadMoreComments,
                                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                                label: Text('Lỗi: $_loadMoreError. Thử lại'),
                                              )
                                            : TextButton(
                                                onPressed: _loadMoreComments,
                                                child: const Text('Tải thêm bình luận'),
                                              ),
                                  ),
                                );
                              }
                              final c = _comments[idx];
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppColors.verifiedSurface,
                                    child: Text(
                                      c.author.displayName.isNotEmpty ? c.author.displayName[0] : 'U',
                                      style: AppTypography.compactStrong.copyWith(color: AppColors.brandPrimary),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.s8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(child:Text(c.author.displayName, style: AppTypography.compactStrong)),
                                            if (c.author.isVerified) ...[
                                              const SizedBox(width: 4),
                                              const Icon(Icons.verified_rounded, size: 14, color: AppColors.brandPrimary),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(c.text, style: AppTypography.body),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: 'Thêm bình luận hoặc hỏi tư vấn...',
                    hintStyle: AppTypography.compact.copyWith(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.disabledSurface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  onSubmitted: (_) => _handleSendComment(),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandPrimary),
                      )
                    : const Icon(Icons.send_rounded, color: AppColors.brandPrimary),
                onPressed: _isSending ? null : _handleSendComment,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
