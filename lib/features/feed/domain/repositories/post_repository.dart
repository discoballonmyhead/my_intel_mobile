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

  Future<Result<Post>> createPost({
    required String body,
    String? region,
    String? tag,
    String? mediaUrl,
    String postType = 'general',
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

  /// Author-only. Returns the post with its new body and edit metadata.
  Future<Result<Post>> editPost(Post post, String body);

  /// Author-only soft delete (`post_delete`).
  Future<Result<void>> deletePost(int postId);

  /// Previous versions, newest first. Author or staff only.
  Future<Result<List<PostEdit>>> getEditHistory(int postId);

  /// Realtime inserts on `content.posts` where `is_osint = false`.
  Stream<Post> watchNewPosts();
}
