import 'dart:convert';

/// Everything the protocol keeps on the phone: private keys, sessions,
/// sender keys and the plaintext of messages already read (ratchet keys are
/// single-use, so a message can only ever be decrypted once).
///
/// Values are JSON maps under string keys:
///   identity · device · spk:<id> · spk_current · otk:<id> · otk_next ·
///   session:<peer> · trust:<peer> · skown:<conv> · sk:<conv>:<sender>:<epoch>
abstract interface class E2eeStore {
  Future<void> open(String userId);
  Future<void> close();
  Future<Map<String, dynamic>?> get(String key);
  Future<void> put(String key, Map<String, dynamic> value);
  Future<void> delete(String key);
  Future<List<String>> keys(String prefix);

  Future<void> putPlain(int messageId, String conversationId, Map<String, dynamic> value);
  Future<Map<String, dynamic>?> getPlain(int messageId);

  /// Newest first, for the key backup.
  Future<List<(int, String, Map<String, dynamic>)>> recentPlain(int limit);

  /// Removes every key and message on this phone for the open user.
  Future<void> wipe();
}

/// In-memory store for tests.
class MemoryE2eeStore implements E2eeStore {
  final Map<String, String> _kv = {};
  final Map<int, (String, String)> _plain = {};

  @override
  Future<void> open(String userId) async {}
  @override
  Future<void> close() async {}
  @override
  Future<Map<String, dynamic>?> get(String key) async =>
      _kv[key] == null ? null : Map<String, dynamic>.from(jsonDecode(_kv[key]!) as Map);
  @override
  Future<void> put(String key, Map<String, dynamic> value) async => _kv[key] = jsonEncode(value);
  @override
  Future<void> delete(String key) async => _kv.remove(key);
  @override
  Future<List<String>> keys(String prefix) async => [for (final k in _kv.keys) if (k.startsWith(prefix)) k];
  @override
  Future<void> putPlain(int messageId, String conversationId, Map<String, dynamic> value) async =>
      _plain[messageId] = (conversationId, jsonEncode(value));
  @override
  Future<Map<String, dynamic>?> getPlain(int messageId) async =>
      _plain[messageId] == null ? null : Map<String, dynamic>.from(jsonDecode(_plain[messageId]!.$2) as Map);
  @override
  Future<List<(int, String, Map<String, dynamic>)>> recentPlain(int limit) async {
    final ids = _plain.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final id in ids.take(limit))
        (id, _plain[id]!.$1, Map<String, dynamic>.from(jsonDecode(_plain[id]!.$2) as Map)),
    ];
  }
  @override
  Future<void> wipe() async {
    _kv.clear();
    _plain.clear();
  }
}
