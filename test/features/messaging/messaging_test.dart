import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint/core/error/failures.dart';
import 'package:mint/core/utils/result.dart';
import 'package:mint/features/messaging/data/models/messaging_models.dart';
import 'package:mint/features/messaging/domain/entities/conversation.dart';
import 'package:mint/features/messaging/domain/entities/message.dart';
import 'package:mint/features/messaging/domain/repositories/messaging_repository.dart';
import 'package:mint/features/messaging/domain/usecases/messaging_usecases.dart';
import 'package:mint/features/messaging/presentation/cubits/chat_cubit.dart';
import 'package:mint/features/messaging/presentation/pages/conversation_info_page.dart';
import 'package:mint/features/messaging/presentation/pages/inbox_page.dart';
import 'package:mint/features/messaging/presentation/widgets/message_bubble.dart';

/// Records uploads and sends; [failUploadAt] makes the n-th upload fail.
class _FakeRepo implements MessagingRepository {
  int uploads = 0;
  int? failUploadAt;
  bool failSend = false;
  final sentAttachments = <List<MessageAttachment>>[];
  final progressSeen = <double>[];

  @override
  Future<Result<MessageAttachment>> uploadAttachment({
    required List<int> bytes,
    required String type,
    required String fileName,
    String? contentType,
    void Function(double sent)? onProgress,
  }) async {
    uploads++;
    if (failUploadAt == uploads) {
      return const Err(NetworkFailure(
          'No internet connection. Tap Retry when you’re back online.'));
    }
    for (final p in [0.25, 0.5, 1.0]) {
      progressSeen.add(p);
      onProgress?.call(p);
    }
    return Ok(MessageAttachment(
        url: 'https://x/$fileName', type: type, name: fileName, size: bytes.length));
  }

  @override
  Future<Result<Message>> sendMessage({
    required String conversationId,
    String? body,
    List<MessageAttachment> attachments = const [],
    int? replyToId,
  }) async {
    if (failSend) return const Err(NetworkFailure());
    sentAttachments.add(attachments);
    return Ok(Message(
      id: 100 + sentAttachments.length,
      conversationId: conversationId,
      createdAt: DateTime.utc(2026, 10, 14),
      senderId: 'me',
      body: body,
      attachments: attachments,
      replyToId: replyToId,
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ChatCubit _cubit(_FakeRepo repo) => ChatCubit(
      conversationId: 'c1',
      myUserId: 'me',
      getConversation: GetConversation(repo),
      getMessages: GetMessages(repo),
      sendMessage: SendMessage(repo),
      editMessage: EditMessage(repo),
      deleteMessage: DeleteMessage(repo),
      markRead: MarkConversationRead(repo),
      watchConversation: WatchConversation(repo),
      leaveConversation: LeaveConversation(repo),
      deleteConversation: DeleteConversation(repo),
      setMuted: SetConversationMuted(repo),
      updateGroup: UpdateGroup(repo),
      removeMember: RemoveGroupMember(repo),
      uploadAttachment: UploadMessageAttachment(repo),
    );

PickedChatFile _file(String name, {String type = 'image', int size = 1000}) =>
    PickedChatFile(bytes: Uint8List(size), type: type, name: name);

Message _msg(int id,
        {String? body,
        List<MessageAttachment> attachments = const [],
        DateTime? deletedAt,
        DateTime? editedAt}) =>
    Message(
      id: id,
      conversationId: 'c1',
      createdAt: DateTime(2026, 10, 14, 10, 42),
      senderId: 'me',
      body: body,
      attachments: attachments,
      deletedAt: deletedAt,
      editedAt: editedAt,
    );

void main() {
  group('inbox search', () {
    InboxEntry entry(String id, String name, String last, {bool group = false}) =>
        InboxEntry(
          conversationId: id,
          kind: group ? ConversationKind.group : ConversationKind.direct,
          lastActivityAt: DateTime(2026),
          title: group ? name : null,
          otherUserId: group ? null : 'u$id',
          lastMessageId: 1,
          lastMessageBody: last,
        );
    final entries = [
      entry('1', 'Mumbai Floods Desk', 'Water is rising near Andheri', group: true),
      entry('2', 'unknown', 'Did you see the flooding?'),
      entry('3', 'unknown', 'Hello'),
    ];

    test('matches the name or the last message, ignoring case', () {
      expect(searchInbox(entries, 'mumbai', 'me').map((e) => e.conversationId),
          ['1']);
      expect(searchInbox(entries, 'FLOOD', 'me').map((e) => e.conversationId),
          ['1', '2']);
    });

    test('a blank query finds nothing', () {
      expect(searchInbox(entries, '  ', 'me'), isEmpty);
    });
  });

  group('message previews', () {
    const photo = MessageAttachment(url: 'u', type: 'image');
    test('text wins; otherwise photo, photos, video or the file name', () {
      expect(_msg(1, body: 'Hi', attachments: const [photo]).preview, 'Hi');
      expect(_msg(1, attachments: const [photo]).preview, 'Photo');
      expect(_msg(1, attachments: const [photo, photo]).preview, '2 photos');
      expect(
          _msg(1, attachments: const [MessageAttachment(url: 'u', type: 'video')])
              .preview,
          'Video');
      expect(
          _msg(1, attachments: const [
            MessageAttachment(url: 'u', type: 'file', name: 'advisory.pdf')
          ]).preview,
          'advisory.pdf');
    });

    test('deleted messages say so', () {
      expect(_msg(1, body: 'x', deletedAt: DateTime(2026)).preview,
          'Message deleted');
    });
  });

  group('attachments', () {
    test('size is saved with the message and read back', () {
      const a = MessageAttachment(url: 'u', type: 'file', name: 'a.pdf', size: 1200);
      expect(a.toJson(), {'url': 'u', 'type': 'file', 'name': 'a.pdf', 'size': 1200});
      final back = MessageAttachmentModel.fromJson(a.toJson());
      expect([back.url, back.type, back.name, back.size], a.props);
    });

    test('shared media skips deleted messages', () {
      const p = MessageAttachment(url: 'p', type: 'image');
      final messages = [
        _msg(2, attachments: const [p]),
        _msg(1, attachments: const [p], deletedAt: DateTime(2026)),
      ];
      expect(sharedAttachments(messages), [p]);
    });

    test('upload limits match posts: 10 MB photos, 100 MB videos, 20 MB files',
        () async {
      final upload = UploadMessageAttachment(_FakeRepo());
      const mb = 1024 * 1024;
      expect(UploadMessageAttachment.maxBytesFor('image'), 10 * mb);
      expect(UploadMessageAttachment.maxBytesFor('video'), 100 * mb);
      expect(UploadMessageAttachment.maxBytesFor('file'), 20 * mb);
      final empty = await upload(const UploadAttachmentParams(
          bytes: [], type: 'image', fileName: 'a.jpg'));
      expect(empty.failureOrNull, isA<ValidationFailure>());
      final big = await upload(UploadAttachmentParams(
          bytes: Uint8List(10 * mb + 1), type: 'image', fileName: 'a.jpg'));
      expect(big.failureOrNull, isA<ValidationFailure>());
    });
  });

  group('message footer', () {
    test('time, with Read and Edited when they apply', () {
      expect(messageFooter(_msg(1)), '10:42');
      expect(messageFooter(_msg(1), prefix: 'Read'), 'Read · 10:42');
      expect(messageFooter(_msg(1, editedAt: DateTime(2026))), 'Edited · 10:42');
    });
  });

  group('sending photos and files', () {
    test('uploads each file, sends once, then clears the outgoing message',
        () async {
      final repo = _FakeRepo();
      final cubit = _cubit(repo);
      final ok = await cubit.sendFiles(
          [_file('a.jpg'), _file('b.pdf', type: 'file')], '  Andheri  ');
      expect(ok, isTrue);
      expect(repo.uploads, 2);
      expect(repo.sentAttachments.single.map((a) => a.name), ['a.jpg', 'b.pdf']);
      expect(cubit.state.outgoing, isEmpty);
      expect(cubit.state.messages.single.body, 'Andheri');
      await cubit.close();
    });

    test('shows progress across all the files while uploading', () async {
      final repo = _FakeRepo();
      final cubit = _cubit(repo);
      final seen = <int>[];
      final sub = cubit.stream.listen((s) {
        if (s.outgoing.isNotEmpty) seen.add(s.outgoing.single.percent);
      });
      await cubit.sendFiles(
          [_file('a.jpg', size: 3000), _file('b.jpg', size: 1000)], '');
      await Future<void>.delayed(Duration.zero); // let queued states arrive
      await sub.cancel();
      // First file is 3/4 of the bytes, so it ends at 75%; then 100%.
      expect(seen, containsAllInOrder([19, 38, 75, 81, 88, 100]));
      await cubit.close();
    });

    test('a failed upload stays with its reason; Retry carries on', () async {
      final repo = _FakeRepo()..failUploadAt = 2;
      final cubit = _cubit(repo);
      final ok = await cubit.sendFiles([_file('a.jpg'), _file('b.jpg')], 'hi');
      expect(ok, isFalse);
      final failed = cubit.state.outgoing.single;
      expect(failed.failed, isTrue);
      expect(failed.error, contains('No internet connection'));
      expect(failed.uploaded.map((a) => a.name), ['a.jpg']);
      expect(repo.sentAttachments, isEmpty);

      final retried = await cubit.retryOutgoing(failed.localId);
      expect(retried, isTrue);
      // Only the file that hadn't gone up is uploaded again.
      expect(repo.uploads, 3);
      expect(repo.sentAttachments.single.map((a) => a.name), ['a.jpg', 'b.jpg']);
      expect(cubit.state.outgoing, isEmpty);
      await cubit.close();
    });

    test('if sending fails after uploading, Retry only sends', () async {
      final repo = _FakeRepo()..failSend = true;
      final cubit = _cubit(repo);
      await cubit.sendFiles([_file('a.jpg')], '');
      final failed = cubit.state.outgoing.single;
      expect(failed.failed, isTrue);
      repo.failSend = false;
      await cubit.retryOutgoing(failed.localId);
      expect(repo.uploads, 1);
      expect(repo.sentAttachments, hasLength(1));
      await cubit.close();
    });

    test('Remove drops a failed message without sending', () async {
      final repo = _FakeRepo()..failUploadAt = 1;
      final cubit = _cubit(repo);
      await cubit.sendFiles([_file('a.jpg')], '');
      cubit.removeOutgoing(cubit.state.outgoing.single.localId);
      expect(cubit.state.outgoing, isEmpty);
      expect(repo.sentAttachments, isEmpty);
      await cubit.close();
    });
  });
}
