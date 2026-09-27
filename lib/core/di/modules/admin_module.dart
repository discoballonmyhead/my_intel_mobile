import 'package:get_it/get_it.dart';

import '../../../features/admin/data/datasources/admin_remote_data_source.dart';
import '../../../features/admin/data/repositories/admin_repository_impl.dart';
import '../../../features/admin/domain/repositories/admin_repository.dart';
import '../../../features/admin/domain/usecases/admin_usecases.dart';
import '../../../features/admin/presentation/cubits/admin_dashboard_cubit.dart';
import '../../../features/admin/presentation/cubits/admin_user_detail_cubit.dart';
import '../../../features/admin/presentation/cubits/admin_users_cubit.dart';
import '../../../features/admin/presentation/cubits/audit_log_cubit.dart';
import '../../../features/admin/presentation/cubits/osint_review_cubit.dart';

/// Staff console: users, roles, OSINT review, bans, audit.
void registerAdminModule(GetIt sl) {
  sl
    ..registerLazySingleton<AdminRemoteDataSource>(
        () => AdminRemoteDataSourceImpl(sl()))
    ..registerLazySingleton<AdminRepository>(
        () => AdminRepositoryImpl(sl(), sl()))
    ..registerLazySingleton(() => GetAdminStats(sl()))
    ..registerLazySingleton(() => GetAdminUsers(sl()))
    ..registerLazySingleton(() => GetAdminUserDetail(sl()))
    ..registerLazySingleton(() => GetOsintApplications(sl()))
    ..registerLazySingleton(() => ApproveOsint(sl()))
    ..registerLazySingleton(() => DeclineOsint(sl()))
    ..registerLazySingleton(() => RevokeOsint(sl()))
    ..registerLazySingleton(() => GrantRole(sl()))
    ..registerLazySingleton(() => RevokeRole(sl()))
    ..registerLazySingleton(() => BanUser(sl()))
    ..registerLazySingleton(() => UnbanUser(sl()))
    ..registerLazySingleton(() => LiftSanction(sl()))
    ..registerLazySingleton(() => AdminDeleteAccount(sl()))
    ..registerLazySingleton(() => GetAuditLog(sl()))
    ..registerFactory<AdminDashboardCubit>(() => AdminDashboardCubit(
          getStats: sl(),
          watchReports: sl(),
        ))
    ..registerFactory<AdminUsersCubit>(() => AdminUsersCubit(getUsers: sl()))
    ..registerFactory<OsintReviewCubit>(() => OsintReviewCubit(
          getApplications: sl(),
          approveOsint: sl(),
          declineOsint: sl(),
          revokeOsint: sl(),
        ))
    ..registerFactory<AuditLogCubit>(() => AuditLogCubit(getAuditLog: sl()))
    // sl<AdminUserDetailCubit>(param1: userId)
    ..registerFactoryParam<AdminUserDetailCubit, String, void>(
      (userId, _) => AdminUserDetailCubit(
        userId: userId,
        getDetail: sl(),
        grantRole: sl(),
        revokeRole: sl(),
        revokeOsint: sl(),
        banUser: sl(),
        unbanUser: sl(),
        liftSanction: sl(),
        warnUser: sl(),
        deleteAccount: sl(),
      ),
    );
}
