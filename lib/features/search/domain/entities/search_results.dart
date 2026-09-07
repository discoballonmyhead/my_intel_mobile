import 'package:equatable/equatable.dart';

import '../../../feed/domain/entities/post.dart';
import '../../../profile/domain/entities/profile.dart';
import '../../../stories/domain/entities/story.dart';

/// A search hits three tables at once, so the result carries all three lists
/// rather than a flattened, type-erased blob.
class SearchResults extends Equatable {
  const SearchResults({
    this.stories = const [],
    this.posts = const [],
    this.profiles = const [],
  });

  final List<Story> stories;
  final List<Post> posts;
  final List<Profile> profiles;

  bool get isEmpty => stories.isEmpty && posts.isEmpty && profiles.isEmpty;
  int get total => stories.length + posts.length + profiles.length;

  @override
  List<Object?> get props => [stories, posts, profiles];
}

/// Query plus its filters. A `#tag` query switches from full-text search to a
/// tag match, which is why the raw text alone is not enough.
class SearchQuery extends Equatable {
  const SearchQuery({
    required this.text,
    this.tag,
    this.cutoff,
  });

  final String text;
  final String? tag;
  final DateTime? cutoff;

  /// Queries beginning with `#` are treated as tag lookups.
  bool get isTagQuery => text.startsWith('#');

  String get normalised =>
      isTagQuery ? text.substring(1).toUpperCase() : text.trim();

  bool get isValid => normalised.length >= 2;

  @override
  List<Object?> get props => [text, tag, cutoff];
}
