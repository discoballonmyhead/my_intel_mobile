import 'package:get_it/get_it.dart';
import 'package:mint/features/credibility/data/datasources/credibility_remote_data_source.dart';
import 'package:mint/features/credibility/data/repositories/credibility_repository_impl.dart';
import 'package:mint/features/credibility/domain/repositories/credibility_repository.dart';
import 'package:mint/features/credibility/domain/usecases/get_credibility.dart';
import 'package:mint/features/reactions/data/datasources/reaction_remote_data_source.dart';
import 'package:mint/features/reactions/data/repositories/reaction_repository_impl.dart';
import 'package:mint/features/reactions/domain/repositories/reaction_repository.dart';
import 'package:mint/features/reactions/domain/usecases/reaction_usecases.dart';
import 'package:mint/features/reactions/presentation/cubits/reactions_cubit.dart';
import 'package:mint/features/stories/data/datasources/story_ai_remote_data_source.dart';
import 'package:mint/features/stories/data/repositories/story_ai_repository_impl.dart';
import 'package:mint/features/stories/domain/repositories/story_ai_repository.dart';

/// Features backed by the RPCs shared with the web app (migration 12):
/// reactions, credibility and AI story text.
void registerWebParityModule(GetIt sl) {
  sl
    // Reactions
    ..registerLazySingleton<ReactionRemoteDataSource>(
        () => ReactionRemoteDataSourceImpl(sl()))
    ..registerLazySingleton<ReactionRepository>(
        () => ReactionRepositoryImpl(sl()))
    ..registerLazySingleton(() => GetPostReactions(sl()))
    ..registerLazySingleton(() => GetReactionsForPosts(sl()))
    ..registerLazySingleton(() => ToggleReaction(sl()))
    // Session-wide: every ReactionBar reads it; reset on account change.
    ..registerLazySingleton<ReactionsCubit>(() => ReactionsCubit(
          getReactionsForPosts: sl(),
          toggleReaction: sl(),
        ))

    // Credibility
    ..registerLazySingleton<CredibilityRemoteDataSource>(
        () => CredibilityRemoteDataSourceImpl(sl()))
    ..registerLazySingleton<CredibilityRepository>(
        () => CredibilityRepositoryImpl(sl()))
    ..registerLazySingleton(() => GetCredibility(sl()))

    // Story AI (headline / summary through the anthropic-proxy edge function)
    ..registerLazySingleton<StoryAiRemoteDataSource>(
        () => StoryAiRemoteDataSourceImpl(sl()))
    ..registerLazySingleton<StoryAiRepository>(
        () => StoryAiRepositoryImpl(sl()));
}
