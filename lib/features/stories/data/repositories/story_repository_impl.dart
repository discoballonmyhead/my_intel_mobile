import '../../../../core/error/exceptions.dart' as ex;
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/theme/app_colors.dart' show AppColors;
import '../../../../core/utils/result.dart';
import '../../../profile/data/datasources/profile_remote_data_source.dart';
import '../../../profile/domain/entities/profile.dart';
import '../../domain/entities/story.dart';
import '../../domain/entities/story_publication.dart';
import '../../domain/repositories/story_repository.dart';
import '../datasources/story_remote_data_source.dart';
import '../models/story_model.dart';
import '../models/story_publication_model.dart';

class StoryRepositoryImpl implements StoryRepository {
  StoryRepositoryImpl(this._remote, this._profiles);

  final StoryRemoteDataSource _remote;
  final ProfileRemoteDataSource _profiles;

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
  Future<Result<StoryPublication>> publishPost({
    required String body,
    required String tag,
    String? region,
    double? regionLat,
    double? regionLng,
    int? threadId,
    String? headline,
    String? summary,
  }) {
    return guard(() async {
      final row = await _remote.publish(
        body: body,
        tag: tag,
        region: region,
        regionLat: regionLat,
        regionLng: regionLng,
        threadId: threadId,
        headline: headline,
        summary: summary,
      );
      return StoryPublicationModel.fromJson(row);
    });
  }

  @override
  Future<Result<void>> setStoryMeta(
    int storyId, {
    String? headline,
    String? summary,
    String? tag,
    String? region,
    double? regionLat,
    double? regionLng,
  }) =>
      guard(() => _remote.setMeta(
            storyId,
            headline: headline,
            summary: summary,
            tag: tag,
            region: region,
            regionLat: regionLat,
            regionLng: regionLng,
          ));

  @override
  Future<Result<StoryContext>> getStoryContext(int storyId) => guard(
      () async => StoryContextModel.fromJson(await _remote.fetchContext(storyId)));

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
