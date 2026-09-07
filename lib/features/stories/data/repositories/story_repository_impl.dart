import '../../../../core/error/exceptions.dart' as ex;
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/theme/app_colors.dart' show AppColors;
import '../../../../core/utils/result.dart';
import '../../../feed/data/datasources/post_remote_data_source.dart';
import '../../../feed/data/models/post_model.dart';
import '../../../profile/data/datasources/profile_remote_data_source.dart';
import '../../../profile/domain/entities/profile.dart';
import '../../domain/entities/story.dart';
import '../../domain/repositories/story_repository.dart';
import '../datasources/story_remote_data_source.dart';
import '../models/story_model.dart';

class StoryRepositoryImpl implements StoryRepository {
  StoryRepositoryImpl(this._remote, this._posts, this._profiles, this._service);

  final StoryRemoteDataSource _remote;
  final PostRemoteDataSource _posts;
  final ProfileRemoteDataSource _profiles;
  final SupabaseService _service;

  /// How long to wait for `trg_auto_link_post_to_stories` to link a new post.
  static const Duration _pollInterval = Duration(milliseconds: 400);
  static const int _pollAttempts = 5;

  @override
  Future<Result<List<Story>>> getStories({int limit = 50}) {
    return guard(() async {
      final rows = await _remote.fetchStories(limit: limit);
      final authors = await _resolveAuthors(rows);
      return rows
          .map((row) => StoryModel.fromJson(row, authors: authors) as Story)
          .toList();
    });
  }

  @override
  Future<Result<Story>> getStory(int storyId) {
    return guard(() async {
      final row = await _remote.fetchStory(storyId);
      if (row == null) throw const ex.NotFoundException('Story not found.');
      final authors = await _resolveAuthors([row]);
      return StoryModel.fromJson(row, authors: authors);
    });
  }

  @override
  Future<Result<List<Story>>> searchStories(String query, {int limit = 15}) {
    return guard(() async {
      final rows = await _remote.searchStories(query, limit: limit);
      return rows.map((row) => StoryModel.fromJson(row) as Story).toList();
    });
  }

  @override
  Future<Result<List<Story>>> getRecentStories({int limit = 20}) {
    return guard(() async {
      final rows = await _remote.fetchRecentStories(limit: limit);
      return rows.map((row) => StoryModel.fromJson(row) as Story).toList();
    });
  }

  @override
  Future<Result<List<Story>>> getStoriesByContributor(String userId) {
    return guard(() async {
      final ids = await _remote.storyIdsForAuthor(userId);
      if (ids.isEmpty) return <Story>[];
      final rows = await _remote.fetchStories(limit: 200);
      return rows
          .where((row) => ids.contains((row['id'] as num).toInt()))
          .map((row) => StoryModel.fromJson(row) as Story)
          .toList();
    });
  }

  @override
  Future<Result<Story?>> publishIntel({
    required String body,
    required String tag,
    required String region,
    double? regionLat,
    double? regionLng,
    int? attachToStoryId,
    String? headline,
    String? summary,
  }) {
    return guard(() async {
      final userId = _requireAnalystId();

      // `manual_story_id` tells the trigger to skip auto-clustering and attach
      // straight to the chosen story.
      final row = await _posts.insertPost(PostModel.toInsertJson(
        authorId: userId,
        body: body.trim(),
        tag: tag,
        region: region,
        isOsint: true,
        postType: 'news',
        regionLat: regionLat,
        regionLng: regionLng,
        manualStoryId: attachToStoryId,
      ));
      final postId = (row['id'] as num).toInt();

      if (attachToStoryId != null) {
        return (await getStory(attachToStoryId)).valueOrNull;
      }

      // Auto-cluster path: wait for the trigger to write story_sources.
      final storyIds = await _awaitStoryLink(postId);
      if (storyIds.isEmpty) return null;

      // If the trigger linked to more than one story, keep the last and drop
      // the rest, matching the web client's clean-up.
      if (storyIds.length > 1) {
        await _remote.unlinkStorySources(
          postId,
          storyIds.sublist(0, storyIds.length - 1),
        );
      }
      final storyId = storyIds.last;

      final resolvedHeadline =
          headline ?? await _fallbackHeadline(body);
      await _remote.updateStory(storyId, {
        'headline': resolvedHeadline,
        'summary': summary ?? body.trim(),
        'tag': tag,
        'region': region,
        'region_lat': regionLat,
        'region_lng': regionLng,
      });

      return (await getStory(storyId)).valueOrNull;
    });
  }

  @override
  Future<Result<List<RegionActivity>>> getRegionActivity() {
    return guard(() async {
      final rows = await _remote.fetchRegionRows();

      final grouped = <String, ({double lat, double lng, int count, bool breaking})>{};
      for (final row in rows) {
        final name = row['region'] as String?;
        final lat = (row['region_lat'] as num?)?.toDouble();
        final lng = (row['region_lng'] as num?)?.toDouble();
        if (name == null || name == 'global' || lat == null || lng == null) {
          continue;
        }
        final breaking = (row['is_breaking'] as bool?) ?? false;
        final existing = grouped[name];
        grouped[name] = existing == null
            ? (lat: lat, lng: lng, count: 1, breaking: breaking)
            : (
                lat: existing.lat,
                lng: existing.lng,
                count: existing.count + 1,
                breaking: existing.breaking || breaking,
              );
      }

      return grouped.entries
          .map((e) => RegionActivity(
                name: e.key,
                latitude: e.value.lat,
                longitude: e.value.lng,
                count: e.value.count,
                hasBreaking: e.value.breaking,
              ))
          .toList()
        ..sort((a, b) => b.count.compareTo(a.count));
    });
  }

  Future<List<int>> _awaitStoryLink(int postId) async {
    for (var attempt = 0; attempt < _pollAttempts; attempt++) {
      await Future<void>.delayed(_pollInterval);
      final ids = await _remote.storyIdsForPost(postId);
      if (ids.isNotEmpty) return ids;
    }
    return const [];
  }

  /// Builds a headline from the database's own keyword extractor when no AI
  /// headline was supplied.
  Future<String> _fallbackHeadline(String body) async {
    final keywords = await _remote.extractKeywords(body);
    if (keywords.isEmpty) return _truncate(body.trim());

    final candidate = keywords
        .take(8)
        .map((k) => k.isEmpty ? k : '${k[0].toUpperCase()}${k.substring(1)}')
        .join(' ');

    return _truncate(candidate.length > 10 ? candidate : body.trim());
  }

  String _truncate(String value) =>
      value.length > 100 ? '${value.substring(0, 97)}...' : value;

  /// RLS already restricts `content.stories` inserts to osint/admin; this only
  /// produces a clearer message than a bare 42501 when nobody is signed in.
  String _requireAnalystId() {
    final id = _service.currentUserId;
    if (id == null) {
      throw const ex.AuthException('Sign in as an analyst to publish.');
    }
    return id;
  }

  Future<Map<String, Profile>> _resolveAuthors(
    List<Map<String, dynamic>> storyRows,
  ) async {
    final ids = storyRows.expand(StorySourceModel.authorIdsOf);
    final profiles = await _profiles.profilesByIds(ids);
    return profiles.map((key, value) => MapEntry(key, value as Profile));
  }
}

/// Colour used by the map for a region's activity level.
extension RegionActivityColor on RegionActivity {
  int get colorValue => hasBreaking
      ? AppColors.regionBreaking.toARGB32()
      : isBusy
          ? AppColors.regionBusy.toARGB32()
          : AppColors.regionQuiet.toARGB32();
}
