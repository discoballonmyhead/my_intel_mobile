import 'package:get_it/get_it.dart';

import '../../../features/e2ee/domain/message_crypto.dart';
import '../../../features/moderation/data/datasources/report_remote_data_source.dart';
import '../../../features/moderation/data/repositories/report_repository_impl.dart';
import '../../../features/moderation/domain/repositories/report_repository.dart';
import '../../../features/moderation/domain/usecases/report_usecases.dart';
import '../../../features/moderation/presentation/cubits/my_reports_cubit.dart';
import '../../../features/moderation/presentation/cubits/report_cubit.dart';

/// Filing reports and following their outcome. The moderator queue is in
/// the admin app (`features/admin`).
void registerReportsModule(GetIt sl) {
  sl
    ..registerLazySingleton<ReportRemoteDataSource>(
        () => ReportRemoteDataSourceImpl(sl()))
    ..registerLazySingleton<ReportRepository>(
        () => ReportRepositoryImpl(sl(), evidence: sl<MessageEvidenceSource>()))
    ..registerLazySingleton(() => SubmitReport(sl()))
    ..registerLazySingleton(() => GetMyReports(sl()))
    ..registerFactory<ReportCubit>(() => ReportCubit(submitReport: sl()))
    ..registerFactory<MyReportsCubit>(() => MyReportsCubit(getMyReports: sl()));
}
