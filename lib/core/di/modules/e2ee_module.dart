import 'package:get_it/get_it.dart';

import '../../../features/e2ee/data/e2ee_api.dart';
import '../../../features/e2ee/data/e2ee_remote_data_source.dart';
import '../../../features/e2ee/data/e2ee_service.dart';
import '../../../features/e2ee/data/e2ee_store.dart';
import '../../../features/e2ee/data/e2ee_store_sqflite.dart';
import '../../../features/e2ee/domain/message_crypto.dart';
import '../../../features/e2ee/presentation/cubits/e2ee_cubit.dart';

/// End-to-end encryption for messaging (one service for the whole session).
void registerE2eeModule(GetIt sl) {
  sl
    ..registerLazySingleton<E2eeRemoteDataSource>(
        () => E2eeRemoteDataSourceImpl(sl()))
    ..registerLazySingleton<E2eeStore>(SqfliteE2eeStore.new)
    ..registerLazySingleton<E2eeService>(() => E2eeService(sl(), sl()))
    // messaging and reports only see these two interfaces
    ..registerLazySingleton<MessageCrypto>(() => sl<E2eeService>())
    ..registerLazySingleton<MessageEvidenceSource>(() => sl<E2eeService>())
    ..registerLazySingleton<E2eeCubit>(
        () => E2eeCubit(service: sl(), api: sl()));
}
