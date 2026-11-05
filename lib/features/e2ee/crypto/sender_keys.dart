import 'dart:convert';
import 'dart:typed_data';

import 'primitives.dart';
import 'session.dart';

/// Signal "Sender Keys" for groups: each member has one hash chain per group
/// (and per membership epoch). A message is encrypted once for everyone and
/// signed with the member's per-group Ed25519 key. The chain key is handed
/// to every member through their pairwise Double Ratchet session (SKDM).
///
/// Envelope: { "v":1, "t":"skmsg", "e":<epoch>, "i":<iteration>, "sig":<b64> }
class SenderKeyState {
  SenderKeyState({
    required this.conversationId,
    required this.senderId,
    required this.epoch,
    required this.chainKey,
    required this.iteration,
    required this.signPublic,
    this.signSeed,
    this.initialChainKey,
    Map<String, String>? skipped,
    Set<String>? distributedTo,
  })  : skipped = skipped ?? {},
        distributedTo = distributedTo ?? {};

  final String conversationId;
  final String senderId;
  final int epoch;
  Uint8List chainKey;
  int iteration;
  final Uint8List signPublic;

  /// Only present for our own key.
  final Uint8List? signSeed;

  /// Own key only: chain key at iteration 0 of this epoch, so a member whose
  /// phone was restored can be re-sent the key and read this epoch again.
  final Uint8List? initialChainKey;
  final Map<String, String> skipped; // iteration → message key
  /// Members who already received our key (own key only).
  final Set<String> distributedTo;

  static const int maxForward = 2000;

  static Future<SenderKeyState> createOwn(String conversationId, String me, int epoch) async {
    final sign = await SigningKeyPair.generate();
    final ck = Crypto.randomBytes(32);
    return SenderKeyState(
      conversationId: conversationId,
      senderId: me,
      epoch: epoch,
      chainKey: ck,
      iteration: 0,
      signPublic: sign.publicKey,
      signSeed: sign.seed,
      initialChainKey: Uint8List.fromList(ck),
    );
  }

  /// The distribution message, sent pairwise to one member.
  /// [fromStart]: hand out the chain from iteration 0 (answer to a key
  /// request from a member who lost it); otherwise from where we are now.
  Map<String, dynamic> distribution({bool fromStart = false}) => {
        't': 'skdm',
        'conv': conversationId,
        'epoch': epoch,
        'ck': b64(fromStart && initialChainKey != null ? initialChainKey! : chainKey),
        'i': fromStart && initialChainKey != null ? 0 : iteration,
        'spub': b64(signPublic),
      };

  factory SenderKeyState.fromDistribution(String senderId, Map<String, dynamic> d) =>
      SenderKeyState(
        conversationId: d['conv'] as String,
        senderId: senderId,
        epoch: (d['epoch'] as num).toInt(),
        chainKey: unb64(d['ck'] as String),
        iteration: (d['i'] as num).toInt(),
        signPublic: unb64(d['spub'] as String),
      );

  Uint8List _aad(Map<String, dynamic> header) =>
      concat([utf8.encode(conversationId), utf8.encode(senderId), utf8.encode(canonicalJson(header))]);

  Future<Encrypted> encrypt(List<int> plaintext) async {
    final seed = signSeed;
    if (seed == null) throw const E2eeException('not_own_sender_key');
    final mk = await Crypto.hmac(chainKey, const [1]);
    final header = {'e': epoch, 'i': iteration};
    chainKey = await Crypto.hmac(chainKey, const [2]);
    iteration++;
    final (key, nonce) = await Crypto.messageKeys(mk);
    final ct = await Crypto.seal(key, nonce, plaintext, aad: _aad(header));
    final sig = await Crypto.sign(await SigningKeyPair.fromSeed(seed), concat([ct, _aad(header)]));
    return Encrypted({'v': 1, 't': 'skmsg', ...header, 'sig': b64(sig)}, b64(ct));
  }

  Future<Uint8List> decrypt(Map<String, dynamic> envelope, String ciphertext) async {
    final header = {'e': (envelope['e'] as num).toInt(), 'i': (envelope['i'] as num).toInt()};
    if (header['e'] != epoch) throw const E2eeException('sender_key_epoch_mismatch');
    final ct = unb64(ciphertext);
    final ok = await Crypto.verify(signPublic, concat([ct, _aad(header)]),
        unb64(envelope['sig'] as String));
    if (!ok) throw const E2eeException('bad_sender_signature');

    final target = header['i']!;
    Uint8List mk;
    final stored = skipped.remove('$target');
    if (stored != null) {
      mk = unb64(stored);
    } else {
      if (target < iteration) throw const E2eeException('duplicate_or_old_message');
      if (target - iteration > maxForward) throw const E2eeException('too_far_ahead');
      while (iteration < target) {
        skipped['$iteration'] = b64(await Crypto.hmac(chainKey, const [1]));
        chainKey = await Crypto.hmac(chainKey, const [2]);
        iteration++;
      }
      mk = await Crypto.hmac(chainKey, const [1]);
      chainKey = await Crypto.hmac(chainKey, const [2]);
      iteration++;
      while (skipped.length > maxForward) {
        skipped.remove(skipped.keys.first);
      }
    }
    final (key, nonce) = await Crypto.messageKeys(mk);
    return Crypto.open(key, nonce, ct, aad: _aad(header));
  }

  Map<String, dynamic> toJson() => {
        'conv': conversationId,
        'sender': senderId,
        'epoch': epoch,
        'ck': b64(chainKey),
        'i': iteration,
        'spub': b64(signPublic),
        if (signSeed != null) 'sseed': b64(signSeed!),
        if (initialChainKey != null) 'ck0': b64(initialChainKey!),
        'skipped': skipped,
        'dist': distributedTo.toList(),
      };

  factory SenderKeyState.fromJson(Map<String, dynamic> j) => SenderKeyState(
        conversationId: j['conv'] as String,
        senderId: j['sender'] as String,
        epoch: j['epoch'] as int,
        chainKey: unb64(j['ck'] as String),
        iteration: j['i'] as int,
        signPublic: unb64(j['spub'] as String),
        signSeed: j['sseed'] == null ? null : unb64(j['sseed'] as String),
        initialChainKey: j['ck0'] == null ? null : unb64(j['ck0'] as String),
        skipped: Map<String, String>.from((j['skipped'] as Map?) ?? const {}),
        distributedTo: {...((j['dist'] as List?) ?? const []).cast<String>()},
      );

  SenderKeyState copy() => SenderKeyState.fromJson(toJson());
}
