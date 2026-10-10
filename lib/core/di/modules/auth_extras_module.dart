import 'package:get_it/get_it.dart';

import '../../../features/auth/domain/usecases/change_password.dart';
import '../../../features/auth/presentation/cubits/change_password_cubit.dart';
import '../../../features/auth/presentation/providers/auth_cubit.dart';

/// Signed-in password change (the reset-email flow is registered in
/// `Injection.init` with the rest of auth).
void registerAuthExtrasModule(GetIt sl) {
  sl
    ..registerLazySingleton(() => ChangePassword(sl()))
    ..registerFactory<ChangePasswordCubit>(() => ChangePasswordCubit(
          email: sl<AuthCubit>().state.user?.email,
          changePassword: sl(),
          sendPasswordReset: sl(),
        ));
}
