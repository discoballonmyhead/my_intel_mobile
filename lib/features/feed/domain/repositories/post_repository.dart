import '../../../../core/utils/result.dart';
import '../entities/post.dart';
import '../entities/post_edit.dart';

abstract interface class PostRepository {
  /// The general (non-OSINT) feed, with reposts merged in and sorted by
  /// relevance timestamp.
  Future<Result<List<FeedItem>>> getFeed({int limit = 50});

  Future<Result<Post>> getPost(int postId);

  Future<Result<List<Post>>> getPostsByAuthor(String authorId, {int limit = 20});

  Future<Result<List<Post>>> getSavedPosts();

  /// A user's reposts of other people's posts, newest first.
  Future<Result<List<RepostedPost>>> getRepostsByUser(String userId);

  Future<Result<Post>> createPost({
    required String body,
    String? region,
    String? tag,
    String? mediaUrl,
    String postType = 'general',
    List<UploadedAttachment> attachments = const [],
    PollDraft? poll,
  });

  /// Returns the post in its new state so the provider can replace it without
  /// guessing at the counter.
  Future<Result<Post>> toggleLike(Post post);
  Future<Result<Post>> toggleSave(Post post);
  Future<Result<Post>> toggleRepost(Post post, {String? quote});

  Future<Result<String>> uploadMedia({
    required List<int> bytes,
    required String fileExtension,
    String? contentType,
  });

  /// Uploads into the viewer's own `mint-media` folder and returns where it
  /// landed, for use as an attachment.
  Future<Result<({String path, String url})>> uploadFile({
    required List<int> bytes,
    required String fileExtension,
    String? contentType,
  });

  /// Casts the viewer's vote. Votes are final; returns the post with the
  /// poll's new counts.
  Future<Result<Post>> votePoll(Post post, int optionId);

  /// Author-only. Returns the post with its new body and edit metadata.
  Future<Result<Post>> editPost(Post post, String body);

  /// Author-only soft delete (`post_delete`).
  Future<Result<void>> deletePost(int postId);

  /// Previous versions, newest first. Author or staff only.
  Future<Result<List<PostEdit>>> getEditHistory(int postId);

  /// Realtime inserts on `content.posts` where `is_osint = false`.
  Stream<Post> watchNewPosts();
}
