import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/db_constants.dart';
import '../../../../core/network/rpc_runner.dart';
import '../../../../core/network/supabase_service.dart';
import '../models/user_access_model.dart';

abstract interface class AccountRemoteDataSource {
  Future<UserAccessModel> fetchMyAccess();
  Future<void> deleteSelf(String confirmation);
  Stream<void> watchAccessChanges(String userId);
}

class AccountRemoteDataSourceImpl implements AccountRemoteDataSource {
  AccountRemoteDataSourceImpl(this._service);
  final SupabaseService _service;

  @override
  Future<UserAccessModel> fetchMyAccess() => runRpc(() async {
        final res = await _service.rpc<dynamic>(AccountRpc.myAccess);
        return UserAccessModel.fromJson(asRow(res) ?? const {});
      });

  @override
  Future<void> deleteSelf(String confirmation) => runRpc(() async {
        await _service.rpc<dynamic>(AccountRpc.deleteSelf,
            params: {'p_confirmation': confirmation});
      });

  @override
  Stream<void> watchAccessChanges(String userId) {
    final controller = StreamController<void>.broadcast();
    RealtimeChannel? channel;

    controller.onListen = () {
      final filter = PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      );
      channel = _service.channel('admin:access:$userId')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: DbSchemas.admin,
          table: DbTables.sanctions,
          filter: filter,
          callback: (_) => controller.add(null),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: DbSchemas.admin,
          table: DbTables.userRoles,
          filter: filter,
          callback: (_) => controller.add(null),
        )
        ..subscribe();
    };
    controller.onCancel = () async {
      final c = channel;
      if (c != null) await _service.removeChannel(c);
      await controller.close();
    };
    return controller.stream;
  }
}
