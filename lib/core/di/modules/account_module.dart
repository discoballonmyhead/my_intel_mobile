import 'package:get_it/get_it.dart';

import '../../../features/account/data/datasources/account_remote_data_source.dart';
import '../../../features/account/data/repositories/account_repository_impl.dart';
import '../../../features/account/domain/repositories/account_repository.dart';
import '../../../features/account/domain/usecases/account_usecases.dart';
import '../../../features/account/presentation/cubits/access_cubit.dart';
import '../../../features/account/presentation/cubits/delete_account_cubit.dart';

/// Roles, bans and self-service account deletion.
void registerAccountModule(GetIt sl) {
  sl
    ..registerLazySingleton<AccountRemoteDataSource>(
        () => AccountRemoteDataSourceImpl(sl()))
    ..registerLazySingleton<AccountRepository>(
        () => AccountRepositoryImpl(sl()))
    ..registerLazySingleton(() => GetMyAccess(sl()))
    ..registerLazySingleton(() => WatchAccessChanges(sl()))
    ..registerLazySingleton(() => DeleteMyAccount(sl()))
    // App-wide: the router and the shell read it.
    ..registerLazySingleton<AccessCubit>(() => AccessCubit(
          getMyAccess: sl(),
          watchAccessChanges: sl(),
        ))
    ..registerFactory<DeleteAccountCubit>(() => DeleteAccountCubit(
          deleteMyAccount: sl(),
          signOut: sl(),
        ));
}
