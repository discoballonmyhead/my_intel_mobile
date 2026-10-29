import 'dart:async';

/// The `e2ee_*` and sender-key RPCs from migration 18. Only public keys,
/// ciphertext and the PIN verifier ever cross this boundary.
abstract interface class E2eeRemoteDataSource {
  Future<Map<String, dynamic>> registerDevice({
    required String deviceId,
    required int registrationId,
    required String identityDh,
    required String identitySign,
    required Map<String, dynamic> signedPreKey,
    required List<Map<String, dynamic>> oneTimePreKeys,
  });
  Future<void> setSignedPreKey(Map<String, dynamic> key);
  Future<int> uploadPreKeys(List<Map<String, dynamic>> keys);
  Future<Map<String, dynamic>> status();
  Future<Map<String, dynamic>?> bundle(String userId);
  Future<List<Map<String, dynamic>>> identities(List<String> userIds);

  Future<int> putSenderKeys(String conversationId, List<Map<String, dynamic>> items);
  Future<List<Map<String, dynamic>>> senderKeys({String? conversationId});
  Future<void> ackSenderKeys(List<int> ids);
  Stream<void> watchSenderKeys(String userId);

  Future<Map<String, dynamic>> backupInfo();
  Future<String> backupBegin();
  Future<void> backupPut({
    required String ciphertext,
    required String nonce,
    required String salt,
    required Map<String, dynamic> kdf,
    required String verifier,
  });
  Future<Map<String, dynamic>> backupRestore(String verifier);
  Future<void> backupDelete();
}

