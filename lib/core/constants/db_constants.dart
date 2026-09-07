/// Names of the Postgres schemas, tables, RPCs and storage buckets exposed by
/// the backend. Centralised so a rename is a one-line change and the data
/// layer never hard-codes a raw string.
class DbSchemas {
  const DbSchemas._();
  static const String content = 'content';
  static const String identity = 'identity';
  static const String media = 'media';
  static const String moderation = 'moderation';
}

class DbTables {
  const DbTables._();

  // content
  static const String posts = 'posts';
  static const String likes = 'likes';
  static const String savedPosts = 'saved_posts';
  static const String reposts = 'reposts';
  static const String stories = 'stories';
  static const String storySources = 'story_sources';

  // identity
  static const String profiles = 'profiles';
  static const String follows = 'follows';
  static const String osintApplications = 'osint_applications';

  // media
  static const String videos = 'videos';
  static const String videoLikes = 'video_likes';
  static const String liveStreams = 'live_streams';

  // moderation
  static const String claims = 'claims';
  static const String communityNotes = 'community_notes';
  static const String feedback = 'feedback';
}

/// `public` schema functions callable through PostgREST rpc().
class DbRpc {
  const DbRpc._();
  static const String extractKeywords = 'extract_keywords';
  static const String keywordOverlapScore = 'keyword_overlap_score';
  static const String findSimilarPosts = 'find_similar_posts';
  static const String findSimilarStories = 'find_similar_stories';
  static const String upsertAuraPoints = 'upsert_aura_points';
}

class StorageBuckets {
  const StorageBuckets._();
  static const String mintMedia = 'mint-media';
  static const String videos = 'videos';
}
