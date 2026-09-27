import 'package:get_it/get_it.dart';

import '../../../features/moderation/data/datasources/report_remote_data_source.dart';
import '../../../features/moderation/data/repositories/report_repository_impl.dart';
import '../../../features/moderation/domain/entities/report.dart';
import '../../../features/moderation/domain/repositories/report_repository.dart';
import '../../../features/moderation/domain/usecases/report_usecases.dart';
import '../../../features/moderation/presentation/cubits/mod_queue_cubit.dart';
import '../../../features/moderation/presentation/cubits/my_reports_cubit.dart';
import '../../../features/moderation/presentation/cubits/report_cubit.dart';
import '../../../features/moderation/presentation/cubits/report_detail_cubit.dart';

/// User reports and the moderator queue.
void registerReportsModule(GetIt sl) {
  sl
    ..registerLazySingleton<ReportRemoteDataSource>(
        () => ReportRemoteDataSourceImpl(sl()))
    ..registerLazySingleton<ReportRepository>(
        () => ReportRepositoryImpl(sl(), sl()))
    ..registerLazySingleton(() => SubmitReport(sl()))
    ..registerLazySingleton(() => GetMyReports(sl()))
    ..registerLazySingleton(() => GetReportQueue(sl()))
    ..registerLazySingleton(() => GetReportsForTarget(sl()))
    ..registerLazySingleton(() => ClaimReportTarget(sl()))
    ..registerLazySingleton(() => ResolveReportTarget(sl()))
    ..registerLazySingleton(() => ModRemovePost(sl()))
    ..registerLazySingleton(() => ModRestorePost(sl()))
    ..registerLazySingleton(() => ModSetPostVisibility(sl()))
    ..registerLazySingleton(() => ModRemoveMessage(sl()))
    ..registerLazySingleton(() => WarnUser(sl()))
    ..registerLazySingleton(() => WatchReports(sl()))
    ..registerFactory<ReportCubit>(() => ReportCubit(submitReport: sl()))
    ..registerFactory<MyReportsCubit>(() => MyReportsCubit(getMyReports: sl()))
    ..registerFactory<ModQueueCubit>(() => ModQueueCubit(
          getQueue: sl(),
          watchReports: sl(),
        ))
    // sl<ReportDetailCubit>(param1: ReportTarget(...))
    ..registerFactoryParam<ReportDetailCubit, ReportTarget, void>(
      (target, _) => ReportDetailCubit(
        target: target,
        getReports: sl(),
        claim: sl(),
        resolve: sl(),
        removePost: sl(),
        restorePost: sl(),
        removeMessage: sl(),
        warnUser: sl(),
        banUser: sl(),
      ),
    );
}
