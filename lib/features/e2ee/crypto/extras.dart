import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' show Sha512;

import 'primitives.dart';

/// Message franking: tag = HMAC-SHA256(key, text). The key travels inside the
/// encrypted payload; the tag is stored by the server in clear, so a report
/// (text + key) can be checked without the server ever reading messages.
/// Must match `messaging.frank_ok` in migration 18 (standard base64).
class Franking {
  static Future<({String key, String tag})> create(String text) async {
    final key = Crypto.randomBytes(32);
    final tag = await Crypto.hmac(key, utf8.encode(text));
    return (key: b64(key), tag: b64(tag));
  }

  static Future<bool> check(String text, String keyB64, String tagB64) async =>
      Crypto.constantTimeEquals(
          await Crypto.hmac(unb64(keyB64), utf8.encode(text)), unb64(tagB64));
}

/// PIN backup: backup key = HKDF(Argon2id(PIN, salt) ‖ server secret).
/// The server only ever sees verifier = HMAC(Argon2id(PIN), label) and
/// wipes the backup after 10 wrong tries (migration 18.4).
class BackupCrypto {
  static const Map<String, dynamic> kdf = {
    'alg': 'argon2id', 'm': 19456, 't': 2, 'p': 1, 'v': 1,
  };

  static Future<Uint8List> stretch(String pin, List<int> salt, Map<String, dynamic> params) =>
      Crypto.argon2id(pin, salt,
          memoryKiB: (params['m'] as num?)?.toInt() ?? 19456,
          iterations: (params['t'] as num?)?.toInt() ?? 2,
          parallelism: (params['p'] as num?)?.toInt() ?? 1);

  static Future<String> verifier(List<int> stretched) async =>
      b64(await Crypto.hmac(stretched, utf8.encode('mint-backup-verifier')));

  static Future<Uint8List> backupKey(List<int> stretched, List<int> serverSecret) =>
      Crypto.hkdf(concat([stretched, serverSecret]),
          salt: Uint8List(32), info: 'MintKeyBackup', length: 32);

  static Future<({String ciphertext, String nonce})> encrypt(
      List<int> key, Map<String, dynamic> payload) async {
    final nonce = Crypto.randomBytes(12);
    final ct = await Crypto.seal(key, nonce, utf8.encode(jsonEncode(payload)),
        aad: utf8.encode('mint-backup-v1'));
    return (ciphertext: b64(ct), nonce: b64(nonce));
  }

  static Future<Map<String, dynamic>> decrypt(
      List<int> key, String ciphertext, String nonce) async {
    final clear = await Crypto.open(key, unb64(nonce), unb64(ciphertext),
        aad: utf8.encode('mint-backup-v1'));
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(clear)) as Map);
  }
}

/// A 60-digit code two people compare to make sure nobody is in the middle
/// (same idea as Signal's safety numbers: hash of both identity keys).
class SafetyNumber {
  static Future<String> compute({
    required String myUserId,
    required List<int> myIdentitySign,
    required String theirUserId,
    required List<int> theirIdentitySign,
  }) async {
    Future<String> half(String id, List<int> key) async {
      var data = concat([key, utf8.encode(id)]);
      for (var i = 0; i < 5200; i++) {
        data = Uint8List.fromList((await Sha512().hash(concat([data, key]))).bytes);
      }
      final digits = StringBuffer();
      for (var i = 0; i < 30; i += 5) {
        final chunk = (data[i] << 32) | (data[i + 1] << 24) | (data[i + 2] << 16) |
            (data[i + 3] << 8) | data[i + 4];
        digits.write((chunk % 100000).toString().padLeft(5, '0'));
      }
      return digits.toString();
    }

    final a = await half(myUserId, myIdentitySign);
    final b = await half(theirUserId, theirIdentitySign);
    final both = myUserId.compareTo(theirUserId) < 0 ? '$a$b' : '$b$a';
    return [for (var i = 0; i < both.length; i += 5) both.substring(i, i + 5)].join(' ');
  }
}
