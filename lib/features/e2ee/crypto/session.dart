import 'dart:convert';
import 'dart:typed_data';

import 'primitives.dart';

/// Signal's X3DH key agreement + Double Ratchet, following the published
/// specifications (signal.org/docs). One [Session] per pair of devices.
///
/// Envelope (stored by the server next to the ciphertext, not secret):
///   { "v":1, "t":"msg"|"pkmsg", "h":{"dh":…, "pn":…, "n":…},
///     "x3dh":{ "ik":…, "iks":…, "ek":…, "spk":…, "opk":…|null, "reg":… } }  // pkmsg only
class ProtocolInfo {
  static const int version = 1;
  static const int maxSkip = 1000;
  static final Uint8List _f = Uint8List.fromList(List.filled(32, 0xFF));
}

class E2eeException implements Exception {
  const E2eeException(this.code, [this.detail]);
  final String code;
  final String? detail;
  @override
  String toString() => 'E2eeException($code${detail == null ? '' : ': $detail'})';
}

/// Long-term identity: X25519 for agreement, Ed25519 for signatures.
class IdentityKeys {
  const IdentityKeys({required this.dh, required this.sign, required this.registrationId});
  final DhKeyPair dh;
  final SigningKeyPair sign;
  final int registrationId;

  Map<String, dynamic> toJson() =>
      {'dh': dh.toJson(), 'sign': sign.toJson(), 'reg': registrationId};
  factory IdentityKeys.fromJson(Map<String, dynamic> j) => IdentityKeys(
        dh: DhKeyPair.fromJson(Map<String, dynamic>.from(j['dh'] as Map)),
        sign: SigningKeyPair.fromJson(Map<String, dynamic>.from(j['sign'] as Map)),
        registrationId: j['reg'] as int,
      );

  static Future<IdentityKeys> generate() async {
    final r = Crypto.randomBytes(2);
    return IdentityKeys(
      dh: await Crypto.newDhKeyPair(),
      sign: await SigningKeyPair.generate(),
      registrationId: 1 + ((r[0] << 8 | r[1]) % 16379),
    );
  }
}

/// What the server hands out to start a session (`e2ee_get_bundle`).
class PreKeyBundle {
  const PreKeyBundle({
    required this.userId,
    required this.deviceId,
    required this.registrationId,
    required this.identityDh,
    required this.identitySign,
    required this.signedPreKeyId,
    required this.signedPreKey,
    required this.signedPreKeySignature,
    this.oneTimePreKeyId,
    this.oneTimePreKey,
  });

  final String userId;
  final String deviceId;
  final int registrationId;
  final Uint8List identityDh;
  final Uint8List identitySign;
  final int signedPreKeyId;
  final Uint8List signedPreKey;
  final Uint8List signedPreKeySignature;
  final int? oneTimePreKeyId;
  final Uint8List? oneTimePreKey;

  factory PreKeyBundle.fromJson(Map<String, dynamic> j) {
    final spk = Map<String, dynamic>.from(j['signed_prekey'] as Map);
    final otk = j['one_time_prekey'] == null
        ? null
        : Map<String, dynamic>.from(j['one_time_prekey'] as Map);
    return PreKeyBundle(
      userId: j['user_id'] as String,
      deviceId: j['device_id'] as String,
      registrationId: (j['registration_id'] as num).toInt(),
      identityDh: unb64(j['identity_dh'] as String),
      identitySign: unb64(j['identity_sign'] as String),
      signedPreKeyId: (spk['key_id'] as num).toInt(),
      signedPreKey: unb64(spk['public_key'] as String),
      signedPreKeySignature: unb64(spk['signature'] as String),
      oneTimePreKeyId: otk == null ? null : (otk['key_id'] as num).toInt(),
      oneTimePreKey: otk == null ? null : unb64(otk['public_key'] as String),
    );
  }
}

class Encrypted {
  const Encrypted(this.envelope, this.ciphertext);
  final Map<String, dynamic> envelope;
  final String ciphertext; // base64
}

/// Double Ratchet state. Immutable-by-convention: [encrypt] / [decrypt]
/// return the new state, so a failed decrypt never corrupts a session.
class Session {
  Session({
    required this.peerUserId,
    required this.peerDeviceId,
    required this.peerIdentityDh,
    required this.peerIdentitySign,
    required this.ad,
    required this.rootKey,
    required this.dhSelf,
    this.dhRemote,
    this.sendChain,
    this.recvChain,
    this.sendN = 0,
    this.recvN = 0,
    this.prevN = 0,
    Map<String, String>? skipped,
    this.pendingPreKey,
    this.establishedAt,
  }) : skipped = skipped ?? {};

  final String peerUserId;
  final String peerDeviceId;
  final Uint8List peerIdentityDh;
  final Uint8List peerIdentitySign;
  final Uint8List ad;
  Uint8List rootKey;
  DhKeyPair dhSelf;
  Uint8List? dhRemote;
  Uint8List? sendChain;
  Uint8List? recvChain;
  int sendN;
  int recvN;
  int prevN;
  final Map<String, String> skipped; // "<dh b64>|<n>" → message key b64
  /// X3DH header repeated on every message until the peer answers.
  Map<String, dynamic>? pendingPreKey;
  DateTime? establishedAt;

  /// Initiator side (Alice) from a bundle. Verifies the signed prekey.
  static Future<Session> initiate(IdentityKeys me, PreKeyBundle b) async {
    final ok = await Crypto.verify(
        b.identitySign, b.signedPreKey, b.signedPreKeySignature);
    if (!ok) throw const E2eeException('bad_signed_prekey');
    final ek = await Crypto.newDhKeyPair();
    final dh1 = await Crypto.dh(me.dh, b.signedPreKey);
    final dh2 = await Crypto.dh(ek, b.identityDh);
    final dh3 = await Crypto.dh(ek, b.signedPreKey);
    final dh4 = b.oneTimePreKey == null ? <int>[] : await Crypto.dh(ek, b.oneTimePreKey!);
    final sk = await Crypto.hkdf(concat([ProtocolInfo._f, dh1, dh2, dh3, dh4]),
        salt: Uint8List(32), info: 'MintX3DH', length: 32);
    final ad = concat([me.dh.publicKey, b.identityDh, me.sign.publicKey, b.identitySign]);

    final dhSelf = await Crypto.newDhKeyPair();
    final (rk, cks) = await _kdfRk(sk, await Crypto.dh(dhSelf, b.signedPreKey));
    return Session(
      peerUserId: b.userId,
      peerDeviceId: b.deviceId,
      peerIdentityDh: b.identityDh,
      peerIdentitySign: b.identitySign,
      ad: ad,
      rootKey: rk,
      dhSelf: dhSelf,
      dhRemote: b.signedPreKey,
      sendChain: cks,
      pendingPreKey: {
        'ik': b64(me.dh.publicKey),
        'iks': b64(me.sign.publicKey),
        'ek': b64(ek.publicKey),
        'spk': b.signedPreKeyId,
        'opk': b.oneTimePreKeyId,
        'reg': me.registrationId,
      },
    );
  }

  /// Responder side (Bob) from the X3DH header of an incoming pkmsg.
  static Future<Session> respond({
    required IdentityKeys me,
    required DhKeyPair signedPreKey,
    DhKeyPair? oneTimePreKey,
    required Map<String, dynamic> x3dh,
    required String peerUserId,
    required String peerDeviceId,
  }) async {
    final ikA = unb64(x3dh['ik'] as String);
    final iksA = unb64(x3dh['iks'] as String);
    final ekA = unb64(x3dh['ek'] as String);
    if (x3dh['opk'] != null && oneTimePreKey == null) {
      throw const E2eeException('one_time_prekey_missing');
    }
    final dh1 = await Crypto.dh(signedPreKey, ikA);
    final dh2 = await Crypto.dh(me.dh, ekA);
    final dh3 = await Crypto.dh(signedPreKey, ekA);
    final dh4 = oneTimePreKey == null ? <int>[] : await Crypto.dh(oneTimePreKey, ekA);
    final sk = await Crypto.hkdf(concat([ProtocolInfo._f, dh1, dh2, dh3, dh4]),
        salt: Uint8List(32), info: 'MintX3DH', length: 32);
    return Session(
      peerUserId: peerUserId,
      peerDeviceId: peerDeviceId,
      peerIdentityDh: ikA,
      peerIdentitySign: iksA,
      ad: concat([ikA, me.dh.publicKey, iksA, me.sign.publicKey]),
      rootKey: sk,
      dhSelf: signedPreKey,
      establishedAt: DateTime.now().toUtc(),
    );
  }

  Future<Encrypted> encrypt(List<int> plaintext) async {
    final ck = sendChain;
    if (ck == null) throw const E2eeException('session_cannot_send_yet');
    final (nextCk, mk) = await _kdfCk(ck);
    final header = {'dh': b64(dhSelf.publicKey), 'pn': prevN, 'n': sendN};
    sendChain = nextCk;
    sendN++;
    final ct = await _sealWith(mk, header, plaintext);
    return Encrypted({
      'v': ProtocolInfo.version,
      't': pendingPreKey == null ? 'msg' : 'pkmsg',
      'h': header,
      if (pendingPreKey != null) 'x3dh': pendingPreKey,
    }, b64(ct));
  }

  /// Returns the plaintext and the updated session (this object is untouched).
  Future<(Uint8List, Session)> decrypt(Map<String, dynamic> envelope, String ciphertext) async {
    final s = copy();
    final h = Map<String, dynamic>.from(envelope['h'] as Map);
    final dh = unb64(h['dh'] as String);
    final n = (h['n'] as num).toInt();
    final pn = (h['pn'] as num).toInt();
    final ct = unb64(ciphertext);

    final skippedKey = '${h['dh']}|$n';
    final stored = s.skipped.remove(skippedKey);
    if (stored != null) {
      return (await s._openWith(unb64(stored), h, ct), s);
    }
    if (s.dhRemote == null || !Crypto.constantTimeEquals(dh, s.dhRemote!)) {
      await s._skip(pn);
      await s._ratchet(dh);
    }
    await s._skip(n);
    final (nextCk, mk) = await _kdfCk(s.recvChain!);
    s.recvChain = nextCk;
    s.recvN++;
    final clear = await s._openWith(mk, h, ct);
    s.pendingPreKey = null; // the peer is talking to us: session established
    s.establishedAt ??= DateTime.now().toUtc();
    return (clear, s);
  }

  Future<void> _skip(int until) async {
    if (recvChain == null) return;
    if (until - recvN > ProtocolInfo.maxSkip) throw const E2eeException('too_many_skipped');
    while (recvN < until) {
      final (nextCk, mk) = await _kdfCk(recvChain!);
      skipped['${b64(dhRemote!)}|$recvN'] = b64(mk);
      recvChain = nextCk;
      recvN++;
    }
    while (skipped.length > ProtocolInfo.maxSkip) {
      skipped.remove(skipped.keys.first);
    }
  }

  Future<void> _ratchet(Uint8List remote) async {
    prevN = sendN;
    sendN = 0;
    recvN = 0;
    dhRemote = remote;
    final (rk1, ckr) = await _kdfRk(rootKey, await Crypto.dh(dhSelf, remote));
    recvChain = ckr;
    dhSelf = await Crypto.newDhKeyPair();
    final (rk2, cks) = await _kdfRk(rk1, await Crypto.dh(dhSelf, remote));
    rootKey = rk2;
    sendChain = cks;
  }

  Future<Uint8List> _sealWith(List<int> mk, Map<String, dynamic> header, List<int> pt) async {
    final (key, nonce) = await Crypto.messageKeys(mk);
    return Crypto.seal(key, nonce, pt, aad: concat([ad, utf8.encode(canonicalJson(header))]));
  }

  Future<Uint8List> _openWith(List<int> mk, Map<String, dynamic> header, List<int> ct) async {
    final (key, nonce) = await Crypto.messageKeys(mk);
    return Crypto.open(key, nonce, ct, aad: concat([ad, utf8.encode(canonicalJson(header))]));
  }

  static Future<(Uint8List, Uint8List)> _kdfRk(List<int> rk, List<int> dhOut) async {
    final out = await Crypto.hkdf(dhOut, salt: rk, info: 'MintRatchet', length: 64);
    return (out.sublist(0, 32), out.sublist(32));
  }

  static Future<(Uint8List, Uint8List)> _kdfCk(List<int> ck) async =>
      (await Crypto.hmac(ck, const [2]), await Crypto.hmac(ck, const [1]));

  Session copy() => Session.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'peer': peerUserId,
        'peer_device': peerDeviceId,
        'peer_ik': b64(peerIdentityDh),
        'peer_iks': b64(peerIdentitySign),
        'ad': b64(ad),
        'rk': b64(rootKey),
        'dhs': dhSelf.toJson(),
        'dhr': dhRemote == null ? null : b64(dhRemote!),
        'cks': sendChain == null ? null : b64(sendChain!),
        'ckr': recvChain == null ? null : b64(recvChain!),
        'ns': sendN,
        'nr': recvN,
        'pn': prevN,
        'skipped': skipped,
        'pending': pendingPreKey,
        'est': establishedAt?.toIso8601String(),
      };

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        peerUserId: j['peer'] as String,
        peerDeviceId: j['peer_device'] as String,
        peerIdentityDh: unb64(j['peer_ik'] as String),
        peerIdentitySign: unb64(j['peer_iks'] as String),
        ad: unb64(j['ad'] as String),
        rootKey: unb64(j['rk'] as String),
        dhSelf: DhKeyPair.fromJson(Map<String, dynamic>.from(j['dhs'] as Map)),
        dhRemote: j['dhr'] == null ? null : unb64(j['dhr'] as String),
        sendChain: j['cks'] == null ? null : unb64(j['cks'] as String),
        recvChain: j['ckr'] == null ? null : unb64(j['ckr'] as String),
        sendN: j['ns'] as int,
        recvN: j['nr'] as int,
        prevN: j['pn'] as int,
        skipped: Map<String, String>.from((j['skipped'] as Map?) ?? const {}),
        pendingPreKey: j['pending'] == null ? null : Map<String, dynamic>.from(j['pending'] as Map),
        establishedAt: j['est'] == null ? null : DateTime.parse(j['est'] as String),
      );
}
