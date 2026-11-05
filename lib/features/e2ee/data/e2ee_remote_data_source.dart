import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/db_constants.dart';
import '../../../core/network/rpc_runner.dart';
import '../../../core/network/supabase_service.dart';

import 'e2ee_api.dart';

class E2eeRemoteDataSourceImpl implements E2eeRemoteDataSource {
  E2eeRemoteDataSourceImpl(this._service);
  final SupabaseService _service;

  Future<dynamic> _call(String fn, [Map<String, dynamic>? params]) =>
      runRpc(() => _service.rpc<dynamic>(fn, params: params));

  @override
  Future<Map<String, dynamic>> registerDevice({
    required String deviceId,
    required int registrationId,
    required String identityDh,
    required String identitySign,
    required Map<String, dynamic> signedPreKey,
    required List<Map<String, dynamic>> oneTimePreKeys,
  }) async =>
      asRow(await _call(E2eeRpc.registerDevice, {
        'p_device_id': deviceId,
        'p_registration_id': registrationId,
        'p_identity_dh': identityDh,
        'p_identity_sign': identitySign,
        'p_signed_prekey': signedPreKey,
        'p_one_time_prekeys': oneTimePreKeys,
      })) ??
      const {};

  @override
  Future<void> setSignedPreKey(Map<String, dynamic> key) =>
      _call(E2eeRpc.setSignedPreKey, {'p_key': key});

  @override
  Future<int> uploadPreKeys(List<Map<String, dynamic>> keys) async =>
      asInt(await _call(E2eeRpc.uploadPreKeys, {'p_keys': keys})) ?? 0;

  @override
  Future<Map<String, dynamic>> status() async =>
      asRow(await _call(E2eeRpc.status)) ?? const {};

  @override
  Future<Map<String, dynamic>?> bundle(String userId) async =>
      asRow(await _call(E2eeRpc.bundle, {'p_user_id': userId}));

  @override
  Future<List<Map<String, dynamic>>> identities(List<String> userIds) async =>
      asRows(await _call(E2eeRpc.identities, {'p_user_ids': userIds}));

  @override
  Future<int> putSenderKeys(String conversationId, List<Map<String, dynamic>> items) async =>
      asInt(await _call(E2eeRpc.putSenderKeys,
          {'p_conversation_id': conversationId, 'p_items': items})) ??
      0;

  @override
  Future<List<Map<String, dynamic>>> senderKeys({String? conversationId}) async =>
      asRows(await _call(E2eeRpc.getSenderKeys, {'p_conversation_id': conversationId}));

  @override
  Future<void> ackSenderKeys(List<int> ids) =>
      ids.isEmpty ? Future.value() : _call(E2eeRpc.ackSenderKeys, {'p_ids': ids});

  @override
  Stream<void> watchSenderKeys(String userId) {
    final controller = StreamController<void>.broadcast();
    RealtimeChannel? channel;
    controller.onListen = () {
      channel = _service.channel('e2ee:sender_keys:$userId:${DateTime.now().microsecondsSinceEpoch}')
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: DbSchemas.messaging,
          table: 'sender_keys',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'recipient_id', value: userId),
          callback: (_) => controller.add(null),
        )
        ..subscribe();
    };
    controller.onCancel = () async {
      final c = channel;
      channel = null;
      if (c != null) await _service.removeChannel(c);
    };
    return controller.stream;
  }

  @override
  Future<Map<String, dynamic>> backupInfo() async =>
      asRow(await _call(E2eeRpc.backupInfo)) ?? const {'exists': false};

  @override
  Future<String> backupBegin() async => (await _call(E2eeRpc.backupBegin)) as String;

  @override
  Future<void> backupPut({
    required String ciphertext,
    required String nonce,
    required String salt,
    required Map<String, dynamic> kdf,
    required String verifier,
  }) =>
      _call(E2eeRpc.backupPut, {
        'p_ciphertext': ciphertext,
        'p_nonce': nonce,
        'p_salt': salt,
        'p_kdf': kdf,
        'p_verifier': verifier,
      });

  @override
  Future<Map<String, dynamic>> backupRestore(String verifier) async =>
      asRow(await _call(E2eeRpc.backupRestore, {'p_verifier': verifier})) ??
      const {'ok': false};

  @override
  Future<void> backupDelete() => _call(E2eeRpc.backupDelete);
}
