import 'dart:async';
import 'dart:convert';

import '../crypto/extras.dart';
import '../crypto/primitives.dart';
import '../crypto/sender_keys.dart';
import '../crypto/session.dart';
import '../domain/message_crypto.dart';
import 'e2ee_api.dart';
import 'e2ee_store.dart';

enum E2eeSetup {
  /// Not signed in / not prepared yet.
  idle,

  /// Keys are on this phone and registered.
  ready,

  /// This phone has no keys but the account has a PIN backup: ask for the
  /// PIN (or start fresh).
  needsRestore,
}

class RestoreResult {
  const RestoreResult.ok() : ok = true, attemptsLeft = null, wiped = false, noBackup = false;
  const RestoreResult.wrongPin(this.attemptsLeft) : ok = false, wiped = false, noBackup = false;
  const RestoreResult.wiped() : ok = false, attemptsLeft = 0, wiped = true, noBackup = false;
  const RestoreResult.noBackup() : ok = false, attemptsLeft = null, wiped = false, noBackup = true;
  final bool ok;
  final int? attemptsLeft;
  final bool wiped;
  final bool noBackup;
}

/// Signal-style end-to-end encryption for messaging, one device per account.
///
/// Every operation runs through one queue so session state is never touched
/// by two messages at once.
class E2eeService implements MessageCrypto, MessageEvidenceSource {
  E2eeService(this._api, this._store);

  final E2eeRemoteDataSource _api;
  final E2eeStore _store;

  static const int _oneTimePreKeyBatch = 100;
  static const int _oneTimePreKeyMinimum = 25;
  static const Duration _signedPreKeyLifetime = Duration(days: 7);
  static const Duration _identityCacheTtl = Duration(minutes: 2);
  static const int _sessionsPerPeer = 3;
  static const int _backupMessageLimit = 3000;

  Future<void> _tail = Future.value();
  final _keysArrived = StreamController<String>.broadcast();
  final Map<String, (DateTime, Map<String, dynamic>?)> _identityCache = {};
  final Map<int, Future<OpenedMessage>> _opening = {};

  String? _userId;
  IdentityKeys? _identity;
  E2eeSetup _setup = E2eeSetup.idle;

  E2eeSetup get setup => _setup;
  String? get userId => _userId;

  @override
  bool get isReady => _setup == E2eeSetup.ready;

  @override
  Stream<String> get keysArrived => _keysArrived.stream;

  Future<T> _serial<T>(Future<T> Function() body) {
    final run = _tail.then((_) => body());
    _tail = run.then((_) {}, onError: (_) {});
    return run;
  }

  // ── Setup ──────────────────────────────────────────────────────────────

  /// Call on sign-in. Creates keys automatically unless a PIN backup exists.
  Future<E2eeSetup> prepare(String userId) => _serial(() async {
        if (_userId != userId) {
          await _store.open(userId);
          _userId = userId;
          _identityCache.clear();
        }
        final saved = await _store.get('identity');
        if (saved != null) {
          _identity = IdentityKeys.fromJson(saved);
          await _ensureRegistered();
          await _maintain();
          return _setup = E2eeSetup.ready;
        }
        final backup = await _api.backupInfo();
        if (backup['exists'] == true) return _setup = E2eeSetup.needsRestore;
        await _createFresh();
        return _setup = E2eeSetup.ready;
      });

  Future<void> signOut() => _serial(() async {
        await _store.close();
        _userId = null;
        _identity = null;
        _setup = E2eeSetup.idle;
        _identityCache.clear();
      });

  /// Skip the backup: new keys. People you talk to see "security code changed"
  /// and messages from before can't be read on this phone.
  Future<void> startFresh() => _serial(() async {
        await _store.wipe();
        await _createFresh();
        _setup = E2eeSetup.ready;
      });

  Future<void> _createFresh() async {
    _identity = await IdentityKeys.generate();
    await _store.put('identity', _identity!.toJson());
    await _store.put('device', {'id': _newDeviceId()});
    await _register(fresh: true);
  }

  Future<void> _ensureRegistered() async {
    final status = await _api.status();
    final device = await _store.get('device');
    if (status['registered'] != true || status['device_id'] != device?['id']) {
      await _register(fresh: false);
    }
  }

  /// Uploads identity + a signed prekey + a batch of one-time prekeys.
  Future<void> _register({required bool fresh}) async {
    final id = _identity!;
    final deviceId = (await _store.get('device'))!['id'] as String;
    final spk = await _newSignedPreKey();
    final otks = await _newOneTimePreKeys(_oneTimePreKeyBatch);
    await _api.registerDevice(
      deviceId: deviceId,
      registrationId: id.registrationId,
      identityDh: b64(id.dh.publicKey),
      identitySign: b64(id.sign.publicKey),
      signedPreKey: spk,
      oneTimePreKeys: otks,
    );
  }

  Future<Map<String, dynamic>> _newSignedPreKey() async {
    final current = await _store.get('spk_current');
    final keyId = ((current?['id'] as int?) ?? 0) + 1;
    final kp = await Crypto.newDhKeyPair();
    final sig = await Crypto.sign(_identity!.sign, kp.publicKey);
    await _store.put('spk:$keyId', kp.toJson());
    await _store.put('spk_current', {'id': keyId, 'at': DateTime.now().toUtc().toIso8601String()});
    // keep the previous one for messages already on their way
    for (final k in await _store.keys('spk:')) {
      final n = int.tryParse(k.substring(4)) ?? 0;
      if (n < keyId - 1) await _store.delete(k);
    }
    return {'key_id': keyId, 'public_key': b64(kp.publicKey), 'signature': b64(sig)};
  }

  Future<List<Map<String, dynamic>>> _newOneTimePreKeys(int count) async {
    final next = ((await _store.get('otk_next'))?['n'] as int?) ?? 1;
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < count; i++) {
      final kp = await Crypto.newDhKeyPair();
      await _store.put('otk:${next + i}', kp.toJson());
      out.add({'key_id': next + i, 'public_key': b64(kp.publicKey)});
    }
    await _store.put('otk_next', {'n': next + count});
    return out;
  }

  /// Top up one-time prekeys and rotate the signed prekey weekly.
  Future<void> maintain() => _serial(_maintain);

  Future<void> _maintain() async {
    if (_identity == null) return;
    final status = await _api.status();
    final left = (status['one_time_prekeys_left'] as num?)?.toInt() ?? 0;
    if (left < _oneTimePreKeyMinimum) {
      await _api.uploadPreKeys(await _newOneTimePreKeys(_oneTimePreKeyBatch));
    }
    final current = await _store.get('spk_current');
    final at = DateTime.tryParse(current?['at'] as String? ?? '');
    if (at == null || DateTime.now().toUtc().difference(at) > _signedPreKeyLifetime) {
      await _api.setSignedPreKey(await _newSignedPreKey());
    }
  }

  String _newDeviceId() {
    final b = Crypto.randomBytes(16);
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }

  // ── Identities ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _identityOf(String userId, {bool fresh = false}) async {
    final hit = _identityCache[userId];
    if (!fresh && hit != null && DateTime.now().difference(hit.$1) < _identityCacheTtl) {
      return hit.$2;
    }
    final rows = await _api.identities([userId]);
    final row = rows.where((r) => r['user_id'] == userId).firstOrNull;
    // only cache hits: someone without keys may set them up any minute
    if (row != null) _identityCache[userId] = (DateTime.now(), row);
    return row;
  }

  /// Someone set up a new phone or new keys (system message
  /// `e2ee:device_changed` / `e2ee:identity_changed`): look them up again
  /// before the next message so a new session is started.
  @override
  void forgetIdentity(String userId) => _identityCache.remove(userId);

  /// Trust on first use; a later change is recorded so the UI can warn.
  Future<void> _observeIdentity(String userId, String identitySign) async {
    final known = await _store.get('trust:$userId');
    if (known == null) {
      await _store.put('trust:$userId', {'iks': identitySign, 'verified': false});
    } else if (known['iks'] != identitySign) {
      await _store.put('trust:$userId', {
        'iks': identitySign,
        'verified': false,
        'changed_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
  }

  /// 60-digit code to compare in person with [userId].
  Future<String?> safetyNumber(String userId) => _serial(() async {
        final their = await _identityOf(userId, fresh: true);
        if (their == null || _identity == null || _userId == null) return null;
        return SafetyNumber.compute(
          myUserId: _userId!,
          myIdentitySign: _identity!.sign.publicKey,
          theirUserId: userId,
          theirIdentitySign: unb64(their['identity_sign'] as String),
        );
      });

  Future<void> markVerified(String userId) => _serial(() async {
        final known = await _store.get('trust:$userId');
        if (known != null) await _store.put('trust:$userId', {...known, 'verified': true});
      });

  Future<({bool verified, bool changed})> trustOf(String userId) => _serial(() async {
        final known = await _store.get('trust:$userId');
        return (verified: known?['verified'] == true, changed: known?['changed_at'] != null);
      });

  // ── Pairwise sessions (Double Ratchet) ─────────────────────────────────

  Future<List<Session>> _sessions(String peer) async {
    final raw = await _store.get('session:$peer');
    return [
      for (final s in (raw?['list'] as List?) ?? const [])
        Session.fromJson(Map<String, dynamic>.from(s as Map)),
    ];
  }

  Future<void> _saveSession(Session s) async {
    final list = (await _sessions(s.peerUserId))
        .where((x) => !(x.peerDeviceId == s.peerDeviceId && Crypto.constantTimeEquals(x.ad, s.ad)))
        .toList();
    final next = [s, ...list].take(_sessionsPerPeer).map((x) => x.toJson()).toList();
    await _store.put('session:${s.peerUserId}', {'list': next});
  }

  Future<Encrypted> _pairwiseEncrypt(String peer, List<int> plaintext) async {
    final identity = await _identityOf(peer);
    if (identity == null) throw RecipientNotReady([peer]);
    final deviceId = identity['device_id'] as String;
    final iks = identity['identity_sign'] as String;
    var session = (await _sessions(peer)).where((s) =>
        s.peerDeviceId == deviceId && b64(s.peerIdentitySign) == iks).firstOrNull;
    if (session == null) {
      final raw = await _api.bundle(peer);
      if (raw == null) throw RecipientNotReady([peer]);
      final bundle = PreKeyBundle.fromJson(raw);
      session = await Session.initiate(_identity!, bundle);
      await _observeIdentity(peer, b64(bundle.identitySign));
      _identityCache.remove(peer);
    }
    final out = await session.encrypt(plaintext);
    await _saveSession(session);
    return out;
  }

  Future<List<int>> _pairwiseDecrypt(String sender, Map<String, dynamic> env, String ct) async {
    for (final s in await _sessions(sender)) {
      try {
        final (clear, next) = await s.decrypt(env, ct);
        await _saveSession(next);
        return clear;
      } catch (_) {
        // try the next session (or a fresh one below)
      }
    }
    if (env['t'] != 'pkmsg') throw const E2eeException('no_session');
    final x3dh = Map<String, dynamic>.from(env['x3dh'] as Map);

    // The X3DH identity must be the one the server has for that account.
    final server = await _identityOf(sender, fresh: true);
    if (server == null ||
        server['identity_sign'] != x3dh['iks'] ||
        server['identity_dh'] != x3dh['ik']) {
      throw const E2eeException('identity_mismatch');
    }
    final spkJson = await _store.get('spk:${x3dh['spk']}');
    if (spkJson == null) throw const E2eeException('signed_prekey_gone');
    final otkId = x3dh['opk'];
    final otkJson = otkId == null ? null : await _store.get('otk:$otkId');
    final session = await Session.respond(
      me: _identity!,
      signedPreKey: DhKeyPair.fromJson(spkJson),
      oneTimePreKey: otkJson == null ? null : DhKeyPair.fromJson(otkJson),
      x3dh: x3dh,
      peerUserId: sender,
      peerDeviceId: server['device_id'] as String,
    );
    final (clear, next) = await session.decrypt(env, ct);
    await _saveSession(next);
    if (otkId != null) await _store.delete('otk:$otkId'); // one-time means one time
    await _observeIdentity(sender, x3dh['iks'] as String);
    return clear;
  }

  // ── Sealing ────────────────────────────────────────────────────────────

  @override
  Future<SealedMessage> seal(ConversationKeys c, MessagePayload payload) => _serial(() async {
        if (!isReady) throw const E2eeException('not_ready');
        final franking = await Franking.create(payload.body);
        final clear = utf8.encode(jsonEncode({...payload.toJson(), 'fk': franking.key, 'v': 1}));
        final Encrypted out;
        if (!c.isGroup) {
          if (c.memberIds.isEmpty) throw const E2eeException('no_recipient');
          out = await _pairwiseEncrypt(c.memberIds.first, clear);
        } else {
          final own = await _ownSenderKey(c);
          out = await own.encrypt(clear);
          await _store.put('skown:${c.conversationId}', own.toJson());
        }
        return SealedMessage(
          ciphertext: out.ciphertext,
          envelope: out.envelope,
          frankingTag: franking.tag,
          frankingKey: franking.key,
        );
      });

  /// Our sender key for this group and epoch, handed to every member who
  /// doesn't have it yet.
  Future<SenderKeyState> _ownSenderKey(ConversationKeys c) async {
    final raw = await _store.get('skown:${c.conversationId}');
    var own = raw == null ? null : SenderKeyState.fromJson(raw);
    if (own == null || own.epoch != c.keyEpoch) {
      own = await SenderKeyState.createOwn(c.conversationId, _userId!, c.keyEpoch);
    }
    final missing = c.memberIds.where((m) => !own!.distributedTo.contains(m)).toList();
    if (missing.isNotEmpty) {
      final items = <Map<String, dynamic>>[];
      final dist = utf8.encode(jsonEncode(own.distribution()));
      for (final member in missing) {
        try {
          final e = await _pairwiseEncrypt(member, dist);
          items.add({'recipient_id': member, 'envelope': e.envelope, 'ciphertext': e.ciphertext});
          own.distributedTo.add(member);
        } on RecipientNotReady {
          // on an old app: they'll get it once they set up encryption
        }
      }
      if (items.isNotEmpty) await _api.putSenderKeys(c.conversationId, items);
    }
    await _store.put('skown:${c.conversationId}', own.toJson());
    return own;
  }

  @override
  Future<void> remember(int messageId, String conversationId, MessagePayload payload, String frankingKey) =>
      _store.putPlain(messageId, conversationId, {...payload.toJson(), 'fk': frankingKey, 'mine': true});

  // ── Opening ────────────────────────────────────────────────────────────

  @override
  Future<MessagePayload?> peek(int messageId) async {
    final hit = await _store.getPlain(messageId);
    return hit == null ? null : MessagePayload.fromJson(hit);
  }

  @override
  Future<OpenedMessage> open(SealedRow row) {
    // The same message can be asked for by the inbox and the chat at once.
    return _opening[row.messageId] ??= _serial(() => _open(row)).whenComplete(() {
      // (a block, not `=>`: returning the removed Future would make
      // whenComplete wait for itself)
      _opening.remove(row.messageId);
    });
  }

  Future<OpenedMessage> _open(SealedRow row) async {
    final hit = await _store.getPlain(row.messageId);
    if (hit != null) return OpenedMessage(OpenStatus.ok, payload: MessagePayload.fromJson(hit));
    if (!isReady || row.senderId == null) return const OpenedMessage(OpenStatus.unavailable);
    if (row.senderId == _userId) {
      // our own message from before a restore / reinstall
      return const OpenedMessage(OpenStatus.unavailable);
    }
    try {
      final List<int> clear;
      if (row.envelope['t'] == 'skmsg') {
        final key = 'sk:${row.conversationId}:${row.senderId}:${row.envelope['e']}';
        var raw = await _store.get(key);
        if (raw == null) {
          await _processSenderKeys(row.conversationId);
          raw = await _store.get(key);
        }
        if (raw == null) {
          await _requestSenderKey(row.conversationId, row.senderId!, (row.envelope['e'] as num).toInt());
          return const OpenedMessage(OpenStatus.waitingForKey);
        }
        final state = SenderKeyState.fromJson(raw).copy();
        clear = await state.decrypt(row.envelope, row.ciphertext);
        await _store.put(key, state.toJson());
      } else {
        clear = await _pairwiseDecrypt(row.senderId!, row.envelope, row.ciphertext);
      }
      final json = Map<String, dynamic>.from(jsonDecode(utf8.decode(clear)) as Map);
      await _store.putPlain(row.messageId, row.conversationId, json);
      return OpenedMessage(OpenStatus.ok, payload: MessagePayload.fromJson(json));
    } catch (_) {
      return const OpenedMessage(OpenStatus.failed);
    }
  }

  /// Picks up sender keys (and key requests) addressed to us.
  Future<void> processSenderKeys({String? conversationId}) =>
      _serial(() => _processSenderKeys(conversationId));

  Future<void> _processSenderKeys(String? conversationId) async {
    if (!isReady) return;
    final items = await _api.senderKeys(conversationId: conversationId);
    if (items.isEmpty) return;
    final done = <int>[];
    final convs = <String>{};
    for (final item in items) {
      final id = (item['id'] as num).toInt();
      final sender = item['sender_id'] as String;
      final conv = item['conversation_id'] as String;
      final env = Map<String, dynamic>.from(item['envelope'] as Map);
      try {
        if (env['t'] == 'skreq') {
          final raw = await _store.get('skown:$conv');
          final own = raw == null ? null : SenderKeyState.fromJson(raw);
          // only for the epoch we're on, and only to current members (the
          // server refuses to store items for people who left)
          if (own != null && own.epoch == (env['e'] as num?)?.toInt()) {
            final e = await _pairwiseEncrypt(
                sender, utf8.encode(jsonEncode(own.distribution(fromStart: true))));
            await _api.putSenderKeys(conv, [
              {'recipient_id': sender, 'envelope': e.envelope, 'ciphertext': e.ciphertext},
            ]);
          }
        } else {
          final clear = await _pairwiseDecrypt(sender, env, item['ciphertext'] as String);
          final d = Map<String, dynamic>.from(jsonDecode(utf8.decode(clear)) as Map);
          if (d['t'] == 'skdm' && d['conv'] == conv) {
            final state = SenderKeyState.fromDistribution(sender, d);
            final key = 'sk:$conv:$sender:${state.epoch}';
            final existing = await _store.get(key);
            // keep the chain we already follow (it holds skipped keys); take a
            // new one only if the sender started a different key
            if (existing == null || existing['spub'] != b64(state.signPublic)) {
              await _store.put(key, state.toJson());
            }
            convs.add(conv);
          }
        }
      } catch (_) {
        // unreadable item: drop it so it doesn't block the queue
      }
      done.add(id);
    }
    await _api.ackSenderKeys(done);
    for (final c in convs) {
      _keysArrived.add(c);
    }
  }

  Future<void> _requestSenderKey(String conv, String sender, int epoch) async {
    final flag = 'skreq:$conv:$sender:$epoch';
    final last = await _store.get(flag);
    final at = DateTime.tryParse(last?['at'] as String? ?? '');
    if (at != null && DateTime.now().toUtc().difference(at) < const Duration(minutes: 10)) return;
    await _api.putSenderKeys(conv, [
      {'recipient_id': sender, 'envelope': {'t': 'skreq', 'e': epoch}, 'ciphertext': '-'},
    ]);
    await _store.put(flag, {'at': DateTime.now().toUtc().toIso8601String()});
  }

  // ── Reports ────────────────────────────────────────────────────────────

  @override
  Future<({String plaintext, String frankingKey})?> evidenceFor(int messageId) async {
    final hit = await _store.getPlain(messageId);
    final fk = hit?['fk'] as String?;
    if (hit == null || fk == null) return null;
    return (plaintext: (hit['b'] as String?) ?? '', frankingKey: fk);
  }

  // ── PIN backup ─────────────────────────────────────────────────────────

  Future<bool> hasBackup() async => (await _api.backupInfo())['exists'] == true;

  /// Saves identity keys + recent message history, encrypted with the PIN.
  Future<void> createBackup(String pin) => _serial(() async {
        if (_identity == null) throw const E2eeException('not_ready');
        final secret = unb64(await _api.backupBegin());
        final salt = Crypto.randomBytes(16);
        final stretched = await BackupCrypto.stretch(pin, salt, BackupCrypto.kdf);
        final messages = await _store.recentPlain(_backupMessageLimit);
        final payload = {
          'v': 1,
          'identity': _identity!.toJson(),
          'trust': {
            for (final k in await _store.keys('trust:')) k.substring(6): await _store.get(k),
          },
          'messages': [
            for (final (id, conv, value) in messages) {'id': id, 'c': conv, 'p': value},
          ],
        };
        final enc = await BackupCrypto.encrypt(await BackupCrypto.backupKey(stretched, secret), payload);
        await _api.backupPut(
          ciphertext: enc.ciphertext,
          nonce: enc.nonce,
          salt: b64(salt),
          kdf: BackupCrypto.kdf,
          verifier: await BackupCrypto.verifier(stretched),
        );
      });

  Future<RestoreResult> restore(String pin) => _serial(() async {
        final info = await _api.backupInfo();
        if (info['exists'] != true) return const RestoreResult.noBackup();
        final kdf = Map<String, dynamic>.from((info['kdf'] as Map?) ?? BackupCrypto.kdf);
        final stretched = await BackupCrypto.stretch(pin, unb64(info['salt'] as String), kdf);
        final res = await _api.backupRestore(await BackupCrypto.verifier(stretched));
        if (res['ok'] != true) {
          return switch (res['reason']) {
            'backup_wiped' => const RestoreResult.wiped(),
            'no_backup' => const RestoreResult.noBackup(),
            _ => RestoreResult.wrongPin((res['attempts_left'] as num?)?.toInt()),
          };
        }
        final key = await BackupCrypto.backupKey(stretched, unb64(res['server_secret'] as String));
        final payload = await BackupCrypto.decrypt(key, res['ciphertext'] as String, res['nonce'] as String);
        await _store.wipe();
        _identity = IdentityKeys.fromJson(Map<String, dynamic>.from(payload['identity'] as Map));
        await _store.put('identity', _identity!.toJson());
        await _store.put('device', {'id': _newDeviceId()}); // new device → peers start new sessions
        for (final e in ((payload['trust'] as Map?) ?? const {}).entries) {
          if (e.value is Map) await _store.put('trust:${e.key}', Map<String, dynamic>.from(e.value as Map));
        }
        for (final m in (payload['messages'] as List?) ?? const []) {
          final row = Map<String, dynamic>.from(m as Map);
          await _store.putPlain((row['id'] as num).toInt(), row['c'] as String,
              Map<String, dynamic>.from(row['p'] as Map));
        }
        await _register(fresh: false);
        _setup = E2eeSetup.ready;
        return const RestoreResult.ok();
      });

  Future<void> deleteBackup() => _api.backupDelete();

  Future<void> dispose() async {
    await _keysArrived.close();
    await _store.close();
  }
}
