import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../crypto/primitives.dart';
import 'e2ee_store.dart';

/// On-device store: SQLite file, every value sealed with AES-256-GCM under
/// a random key kept in the Keychain / Android Keystore.
class SqfliteE2eeStore implements E2eeStore {
  SqfliteE2eeStore({FlutterSecureStorage? secure})
      : _secure = secure ??
            const FlutterSecureStorage(
              // Keychain item never leaves this device (not in iCloud backups);
              // Android keeps it in the hardware-backed Keystore.
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
            );

  final FlutterSecureStorage _secure;
  Database? _db;
  Uint8List? _key;
  String? _vaultName;

  Database get _d => _db ?? (throw StateError('E2eeStore not open'));

  @override
  Future<void> open(String userId) async {
    await close();
    final tag = b64(await Crypto.hmac(utf8.encode('mint-e2ee-store'), utf8.encode(userId)))
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .substring(0, 16);
    _vaultName = 'mint_e2ee_key_$tag';
    var key = await _secure.read(key: _vaultName!);
    if (key == null) {
      key = b64(Crypto.randomBytes(32));
      await _secure.write(key: _vaultName!, value: key);
    }
    _key = unb64(key);
    _db = await openDatabase(
      p.join(await getDatabasesPath(), 'mint_e2ee_$tag.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('create table kv (k text primary key, v blob not null)');
        await db.execute('create table plain (id integer primary key, conv text not null, '
            'v blob not null, at integer not null)');
        await db.execute('create index plain_conv on plain (conv, id)');
      },
    );
  }

  @override
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _key = null;
  }

  Future<Uint8List> _seal(Map<String, dynamic> value, String aad) async {
    final nonce = Crypto.randomBytes(12);
    final ct = await Crypto.seal(_key!, nonce, utf8.encode(jsonEncode(value)), aad: utf8.encode(aad));
    return concat([nonce, ct]);
  }

  Future<Map<String, dynamic>> _open(Uint8List blob, String aad) async {
    final clear = await Crypto.open(_key!, blob.sublist(0, 12), blob.sublist(12), aad: utf8.encode(aad));
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(clear)) as Map);
  }

  @override
  Future<Map<String, dynamic>?> get(String key) async {
    final rows = await _d.query('kv', columns: ['v'], where: 'k = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return _open(rows.first['v']! as Uint8List, key);
  }

  @override
  Future<void> put(String key, Map<String, dynamic> value) async {
    await _d.insert('kv', {'k': key, 'v': await _seal(value, key)},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> delete(String key) => _d.delete('kv', where: 'k = ?', whereArgs: [key]);

  @override
  Future<List<String>> keys(String prefix) async {
    final rows = await _d.query('kv', columns: ['k'], where: 'k like ?', whereArgs: ['$prefix%']);
    return [for (final r in rows) r['k']! as String];
  }

  @override
  Future<void> putPlain(int messageId, String conversationId, Map<String, dynamic> value) async {
    await _d.insert('plain', {
      'id': messageId,
      'conv': conversationId,
      'v': await _seal(value, 'plain:$messageId'),
      'at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<Map<String, dynamic>?> getPlain(int messageId) async {
    final rows = await _d.query('plain', columns: ['v'], where: 'id = ?', whereArgs: [messageId]);
    if (rows.isEmpty) return null;
    return _open(rows.first['v']! as Uint8List, 'plain:$messageId');
  }

  @override
  Future<List<(int, String, Map<String, dynamic>)>> recentPlain(int limit) async {
    final rows = await _d.query('plain', orderBy: 'id desc', limit: limit);
    return [
      for (final r in rows)
        (r['id']! as int, r['conv']! as String,
            await _open(r['v']! as Uint8List, 'plain:${r['id']}')),
    ];
  }

  @override
  Future<void> wipe() async {
    await _d.delete('kv');
    await _d.delete('plain');
  }
}

