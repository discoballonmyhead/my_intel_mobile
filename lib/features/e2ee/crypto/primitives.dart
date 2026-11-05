import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// The handful of audited primitives the protocol is built from
/// (package:cryptography, Apache-2.0). Nothing here is home-made crypto:
/// X25519, Ed25519, HKDF-SHA256, HMAC-SHA256, AES-256-GCM, Argon2id.
class Crypto {
  const Crypto._();

  static final X25519 _x25519 = X25519();
  static final Ed25519 _ed25519 = Ed25519();
  static final Hmac _hmac = Hmac.sha256();
  static final AesGcm _aes = AesGcm.with256bits();
  static final Random _rng = Random.secure();

  static Uint8List randomBytes(int n) =>
      Uint8List.fromList(List<int>.generate(n, (_) => _rng.nextInt(256)));

  // ── X25519 ──
  static Future<DhKeyPair> newDhKeyPair() async =>
      DhKeyPair.fromSeed(randomBytes(32));

  static Future<Uint8List> dh(DhKeyPair mine, List<int> theirPublic) async {
    final kp = await _x25519.newKeyPairFromSeed(mine.privateKey);
    final shared = await _x25519.sharedSecretKey(
      keyPair: kp,
      remotePublicKey: SimplePublicKey(theirPublic, type: KeyPairType.x25519),
    );
    return Uint8List.fromList(await shared.extractBytes());
  }

  // ── Ed25519 ──
  static Future<Uint8List> sign(SigningKeyPair key, List<int> message) async {
    final kp = await _ed25519.newKeyPairFromSeed(key.seed);
    final sig = await _ed25519.sign(message, keyPair: kp);
    return Uint8List.fromList(sig.bytes);
  }

  static Future<bool> verify(
      List<int> publicKey, List<int> message, List<int> signature) async {
    if (signature.length != 64 || publicKey.length != 32) return false;
    return _ed25519.verify(
      message,
      signature: Signature(signature,
          publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519)),
    );
  }

  // ── HKDF / HMAC ──
  static Future<Uint8List> hkdf(List<int> ikm,
      {required List<int> salt, required String info, required int length}) async {
    final key = await Hkdf(hmac: _hmac, outputLength: length).deriveKey(
      secretKey: SecretKey(ikm),
      nonce: salt,
      info: utf8.encode(info),
    );
    return Uint8List.fromList(await key.extractBytes());
  }

  static Future<Uint8List> hmac(List<int> key, List<int> data) async {
    final mac = await _hmac.calculateMac(data, secretKey: SecretKey(key));
    return Uint8List.fromList(mac.bytes);
  }

  // ── AES-256-GCM: output = ciphertext ‖ 16-byte tag ──
  static Future<Uint8List> seal(List<int> key, List<int> nonce,
      List<int> plaintext, {List<int> aad = const []}) async {
    final box = await _aes.encrypt(plaintext,
        secretKey: SecretKey(key), nonce: nonce, aad: aad);
    return Uint8List.fromList([...box.cipherText, ...box.mac.bytes]);
  }

  /// Throws [SecretBoxAuthenticationError] if anything was tampered with.
  static Future<Uint8List> open(List<int> key, List<int> nonce, List<int> sealed,
      {List<int> aad = const []}) async {
    if (sealed.length < 16) throw const FormatException('ciphertext too short');
    final box = SecretBox(sealed.sublist(0, sealed.length - 16),
        nonce: nonce, mac: Mac(sealed.sublist(sealed.length - 16)));
    final clear =
        await _aes.decrypt(box, secretKey: SecretKey(key), aad: aad);
    return Uint8List.fromList(clear);
  }

  /// Message key → (AES key, nonce). The nonce never repeats because every
  /// message key is used exactly once.
  static Future<(Uint8List, Uint8List)> messageKeys(List<int> mk) async {
    final out = await hkdf(mk,
        salt: Uint8List(32), info: 'MintMessageKeys', length: 44);
    return (out.sublist(0, 32), out.sublist(32, 44));
  }

  // ── Argon2id for the PIN backup ──
  static Future<Uint8List> argon2id(String pin, List<int> salt,
      {int memoryKiB = 19456, int iterations = 2, int parallelism = 1}) async {
    final key = await Argon2id(
      parallelism: parallelism,
      memory: memoryKiB,
      iterations: iterations,
      hashLength: 32,
    ).deriveKey(secretKey: SecretKey(utf8.encode(pin)), nonce: salt);
    return Uint8List.fromList(await key.extractBytes());
  }

  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var r = 0;
    for (var i = 0; i < a.length; i++) {
      r |= a[i] ^ b[i];
    }
    return r == 0;
  }
}

/// X25519 key pair kept as raw bytes so it can be stored and restored.
class DhKeyPair {
  const DhKeyPair(this.privateKey, this.publicKey);

  final Uint8List privateKey;
  final Uint8List publicKey;

  static Future<DhKeyPair> fromSeed(List<int> seed) async {
    final kp = await X25519().newKeyPairFromSeed(seed);
    final pub = await kp.extractPublicKey();
    return DhKeyPair(Uint8List.fromList(await kp.extractPrivateKeyBytes()),
        Uint8List.fromList(pub.bytes));
  }

  Map<String, dynamic> toJson() =>
      {'priv': b64(privateKey), 'pub': b64(publicKey)};

  factory DhKeyPair.fromJson(Map<String, dynamic> j) =>
      DhKeyPair(unb64(j['priv'] as String), unb64(j['pub'] as String));
}

/// Ed25519 key pair (seed + public key).
class SigningKeyPair {
  const SigningKeyPair(this.seed, this.publicKey);

  final Uint8List seed;
  final Uint8List publicKey;

  static Future<SigningKeyPair> generate() => fromSeed(Crypto.randomBytes(32));

  static Future<SigningKeyPair> fromSeed(List<int> seed) async {
    final kp = await Ed25519().newKeyPairFromSeed(seed);
    final pub = await kp.extractPublicKey();
    return SigningKeyPair(Uint8List.fromList(seed), Uint8List.fromList(pub.bytes));
  }

  Map<String, dynamic> toJson() => {'seed': b64(seed), 'pub': b64(publicKey)};

  factory SigningKeyPair.fromJson(Map<String, dynamic> j) =>
      SigningKeyPair(unb64(j['seed'] as String), unb64(j['pub'] as String));
}

/// Standard base64 (with padding), the format the database checks.
String b64(List<int> bytes) => base64.encode(bytes);
Uint8List unb64(String s) => base64.decode(s);

/// Stable JSON for anything that goes into associated data.
String canonicalJson(Map<String, dynamic> m) {
  final keys = m.keys.toList()..sort();
  return jsonEncode({for (final k in keys) k: m[k]});
}

Uint8List concat(List<List<int>> parts) =>
    Uint8List.fromList([for (final p in parts) ...p]);
