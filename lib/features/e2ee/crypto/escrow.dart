import 'dart:convert';
import 'dart:typed_data';

import 'primitives.dart';

/// Public-key "sealed box": anyone can seal to an X25519 public key, only
/// the holder of the private key can open it.
///
///   eph   = fresh X25519 key pair
///   ss    = X25519(eph.private, recipient.public)
///   k ‖ n = HKDF-SHA256(ikm: ss, salt: eph.public ‖ recipient.public,
///                       info: "mint-seal-v1|<label>", 44 bytes)
///   c     = AES-256-GCM(k, n, plaintext, aad)
///   blob  = {"e": b64(eph.public), "c": b64(c)}
///
/// The nonce is derived, never random: every seal has a new ephemeral key.
/// The same construction is specified for the web client (docs/E2EE_SPEC.md).
class SealedBox {
  const SealedBox._();

  static Future<Map<String, String>> seal(
    List<int> recipientPublic,
    List<int> plaintext, {
    required String label,
    String aad = '',
  }) async {
    final eph = await Crypto.newDhKeyPair();
    final ss = await Crypto.dh(eph, recipientPublic);
    final kn = await Crypto.hkdf(ss,
        salt: concat([eph.publicKey, recipientPublic]), info: 'mint-seal-v1|$label', length: 44);
    final c = await Crypto.seal(kn.sublist(0, 32), kn.sublist(32), plaintext, aad: utf8.encode(aad));
    return {'e': b64(eph.publicKey), 'c': b64(c)};
  }

  /// Throws if the blob was tampered with or isn't for this key.
  static Future<Uint8List> open(
    DhKeyPair recipient,
    Map<String, dynamic> blob, {
    required String label,
    String aad = '',
  }) async {
    final ephPublic = unb64(blob['e'] as String);
    final ss = await Crypto.dh(recipient, ephPublic);
    final kn = await Crypto.hkdf(ss,
        salt: concat([ephPublic, recipient.publicKey]), info: 'mint-seal-v1|$label', length: 44);
    return Crypto.open(kn.sublist(0, 32), kn.sublist(32), unb64(blob['c'] as String), aad: utf8.encode(aad));
  }
}

/// Shamir's secret sharing over GF(2^8) (AES field, x^8+x^4+x^3+x+1).
/// Any [threshold] shares rebuild the secret; fewer reveal nothing.
class Shamir {
  const Shamir._();

  static final List<int> _exp = List<int>.filled(512, 0);
  static final List<int> _log = List<int>.filled(256, 0);
  static bool _ready = false;

  static void _init() {
    if (_ready) return;
    var x = 1;
    for (var i = 0; i < 255; i++) {
      _exp[i] = x;
      _log[x] = i;
      // multiply by the generator 3
      x ^= _xtime(x);
    }
    for (var i = 255; i < 512; i++) {
      _exp[i] = _exp[i - 255];
    }
    _ready = true;
  }

  static int _xtime(int a) => ((a << 1) ^ ((a & 0x80) != 0 ? 0x1b : 0)) & 0xff;

  static int _mul(int a, int b) => a == 0 || b == 0 ? 0 : _exp[_log[a] + _log[b]];

  static int _div(int a, int b) {
    if (b == 0) throw ArgumentError('division by zero');
    return a == 0 ? 0 : _exp[(_log[a] + 255 - _log[b]) % 255];
  }

  /// Shares x = 1..[count]; each share is as long as the secret.
  static List<(int, Uint8List)> split(List<int> secret, {required int count, required int threshold}) {
    if (threshold < 2 || threshold > count || count > 255) {
      throw ArgumentError('need 2 <= threshold <= count <= 255');
    }
    _init();
    final shares = [for (var x = 1; x <= count; x++) (x, Uint8List(secret.length))];
    for (var i = 0; i < secret.length; i++) {
      // random polynomial of degree threshold-1 with f(0) = secret byte
      final coeffs = [secret[i], ...Crypto.randomBytes(threshold - 1)];
      for (final (x, y) in shares) {
        var acc = 0;
        for (var c = coeffs.length - 1; c >= 0; c--) {
          acc = _mul(acc, x) ^ coeffs[c];
        }
        y[i] = acc;
      }
    }
    return shares;
  }

  /// Lagrange interpolation at x = 0.
  static Uint8List combine(List<(int, List<int>)> shares) {
    if (shares.length < 2) throw ArgumentError('need at least two shares');
    _init();
    final xs = shares.map((s) => s.$1).toList();
    if (xs.toSet().length != xs.length || xs.any((x) => x < 1 || x > 255)) {
      throw ArgumentError('shares must have distinct x in 1..255');
    }
    final len = shares.first.$2.length;
    final out = Uint8List(len);
    for (var j = 0; j < shares.length; j++) {
      // basis polynomial l_j(0) = prod_{m != j} x_m / (x_m - x_j); minus is xor
      var basis = 1;
      for (var m = 0; m < shares.length; m++) {
        if (m == j) continue;
        basis = _mul(basis, _div(xs[m], xs[m] ^ xs[j]));
      }
      final y = shares[j].$2;
      for (var i = 0; i < len; i++) {
        out[i] ^= _mul(y[i], basis);
      }
    }
    return out;
  }
}

/// One version of the platform's governance public key, as served by
/// `e2ee_governance()`.
class GovernanceKey {
  const GovernanceKey({
    required this.version,
    required this.publicKey,
    required this.threshold,
    required this.holders,
    required this.signature,
  });

  final int version;
  final Uint8List publicKey;
  final int threshold;
  final List<String> holders;
  final Uint8List signature;

  factory GovernanceKey.fromJson(Map<String, dynamic> j) => GovernanceKey(
        version: (j['version'] as num).toInt(),
        publicKey: unb64(j['public_key'] as String),
        threshold: (j['threshold'] as num).toInt(),
        holders: [for (final h in (j['holders'] as List? ?? const [])) '$h'],
        signature: unb64(j['signature'] as String),
      );

  /// What the governance root signs.
  static List<int> signedBytes({
    required int version,
    required List<int> publicKey,
    required int threshold,
    required List<String> holders,
  }) =>
      utf8.encode(canonicalJson({
        'holders': [...holders]..sort(),
        'k': threshold,
        'pub': b64(publicKey),
        'v': version,
      }));

  Future<bool> verify(List<int> rootPublicKey) => Crypto.verify(
        rootPublicKey,
        signedBytes(version: version, publicKey: publicKey, threshold: threshold, holders: holders),
        signature,
      );

  /// Short code people can compare by eye: first 10 bytes of SHA-256 style
  /// HMAC over the key, grouped.
  static Future<String> fingerprint(List<int> key) async {
    final h = await Crypto.hmac(utf8.encode('mint-fingerprint'), key);
    final hex = h.sublist(0, 10).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return [for (var i = 0; i < hex.length; i += 4) hex.substring(i, i + 4)].join(' ').toUpperCase();
  }
}

/// The governance copy of a message: the same plaintext the recipients
/// decrypt (payload + franking key), sealed to the governance key and bound
/// to the conversation, sender and key version.
class Escrow {
  const Escrow._();

  static String messageAad(String conversationId, String senderId, int version) =>
      'mint-escrow-v1|$conversationId|$senderId|$version';

  static String shareAad(int version, String holderId) => 'mint-share-v1|$version|$holderId';

  static String releaseAad(int requestId, int version, String approverId) =>
      'mint-release-v1|$requestId|$version|$approverId';

  /// `envelope.gov` for a new message.
  static Future<Map<String, dynamic>> sealMessage(
      GovernanceKey key, String conversationId, String senderId, List<int> clear) async {
    final blob = await SealedBox.seal(key.publicKey, clear,
        label: 'escrow', aad: messageAad(conversationId, senderId, key.version));
    return {'v': key.version, ...blob};
  }

  static Future<Uint8List> openMessage(DhKeyPair governanceKey, Map<String, dynamic> blob,
          {required String conversationId, required String senderId, required int version}) =>
      SealedBox.open(governanceKey, blob,
          label: 'escrow', aad: messageAad(conversationId, senderId, version));

  /// A share as sealed to (or released to) a holder: {"v", "x", "y"}.
  static List<int> sharePlaintext(int version, int x, List<int> y) =>
      utf8.encode(canonicalJson({'v': version, 'x': x, 'y': b64(y)}));

  static (int, Uint8List) parseShare(List<int> clear, {required int version}) {
    final j = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
    if ((j['v'] as num).toInt() != version) throw const FormatException('share for another version');
    return ((j['x'] as num).toInt(), unb64(j['y'] as String));
  }
}
