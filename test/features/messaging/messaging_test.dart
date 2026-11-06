import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint/core/constants/user_role.dart';
import 'package:mint/core/theme/app_theme.dart';
import 'package:mint/core/error/failures.dart';
import 'package:mint/core/utils/result.dart';
import 'package:mint/features/messaging/data/models/messaging_models.dart';
import 'package:mint/features/messaging/domain/entities/conversation.dart';
import 'package:mint/features/messaging/domain/entities/message.dart';
import 'package:mint/features/messaging/domain/repositories/messaging_repository.dart';
import 'package:mint/features/messaging/domain/usecases/messaging_usecases.dart';
import 'package:mint/features/messaging/presentation/cubits/chat_cubit.dart';
import 'package:mint/features/feed/presentation/widgets/composer_emoji_panel.dart';
import 'package:mint/features/messaging/presentation/pages/chat_page.dart';
import 'package:mint/features/messaging/presentation/pages/conversation_info_page.dart';
import 'package:mint/features/messaging/presentation/widgets/message_bubble.dart';
import 'package:mint/features/profile/domain/entities/profile.dart';

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
        url: 'https://x/$fileName',
        type: type,
        name: fileName,
        size: bytes.length));
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
  group('message previews', () {
    const photo = MessageAttachment(url: 'u', type: 'image');
    test('text wins; otherwise photo, photos, video or the file name', () {
      expect(_msg(1, body: 'Hi', attachments: const [photo]).preview, 'Hi');
      expect(_msg(1, attachments: const [photo]).preview, 'Photo');
      expect(_msg(1, attachments: const [photo, photo]).preview, '2 photos');
      expect(
          _msg(1, attachments: const [
            MessageAttachment(url: 'u', type: 'video')
          ]).preview,
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
      const a =
          MessageAttachment(url: 'u', type: 'file', name: 'a.pdf', size: 1200);
      expect(a.toJson(),
          {'url': 'u', 'type': 'file', 'name': 'a.pdf', 'size': 1200});
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
      expect(
          messageFooter(_msg(1, editedAt: DateTime(2026))), 'Edited · 10:42');
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
      expect(
          repo.sentAttachments.single.map((a) => a.name), ['a.jpg', 'b.pdf']);
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
      expect(
          repo.sentAttachments.single.map((a) => a.name), ['a.jpg', 'b.jpg']);
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

  group('locked messages', () {
    Message m(int id,
            {MessageEncryption enc = MessageEncryption.encrypted,
            int day = 14}) =>
        Message(
          id: id,
          conversationId: 'c1',
          createdAt: DateTime(2026, 10, day, 10),
          senderId: 'them',
          body: 'hi',
          encryption: enc,
        );
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    const off = MessageEncryption.unavailable;

    test(
        'a run of locked messages folds into one entry; readable ones stay single',
        () {
      final entries = groupLockedMessages([
        m(6),
        m(5, enc: off),
        m(4, enc: MessageEncryption.failed),
        m(3, enc: off),
        m(2),
        m(1, enc: off),
      ], sameDay: sameDay);
      expect(entries.map((e) => e.map((x) => x.id).toList()).toList(), [
        [6],
        [5, 4, 3],
        [2],
        [1],
      ]);
    });

    test('runs split at a new day, and waiting-for-key messages are not locked',
        () {
      final entries = groupLockedMessages([
        m(3, enc: off, day: 15),
        m(2, enc: off, day: 14),
        m(1, enc: MessageEncryption.waitingForKey),
      ], sameDay: sameDay);
      expect(entries.length, 3);
      expect(isLocked(m(1, enc: MessageEncryption.waitingForKey)), isFalse);
    });

    test('pill wording before and after a restore', () {
      expect(
          LockedRunPill.label(24, beforeRestore: true), '24 locked messages');
      expect(LockedRunPill.label(1, beforeRestore: true), '1 locked message');
      expect(LockedRunPill.label(3, beforeRestore: false),
          '3 messages can’t be read on this phone');
      expect(LockedRunPill.label(1, beforeRestore: false),
          '1 message can’t be read on this phone');
    });
  });

  group('group pictures', () {
    Participant person(String id, String name) => Participant(
        userId: id,
        profile: Profile(id: id, username: name, role: UserRole.public));
    final conversation = Conversation(
      id: 'c1',
      kind: ConversationKind.group,
      title: 'Home',
      participants: [
        person('me', 'elsa'),
        person('e', 'Elsa'),
        person('s', 'shresth'),
      ],
    );
    Message from(int id, String sender) => Message(
        id: id,
        conversationId: 'c1',
        createdAt: DateTime(2026, 10, 14),
        senderId: sender,
        body: 'x');

    test('chat and group info: the group plus the latest sender who isn’t you',
        () {
      final state = ChatState(
          conversationId: 'c1',
          myUserId: 'me',
          conversation: conversation,
          messages: [from(3, 'me'), from(2, 's'), from(1, 'e')]);
      expect(state.groupAvatarNames, ['Home', 'shresth']);
    });

    test('before anyone else writes, any other member', () {
      final state = ChatState(
          conversationId: 'c1', myUserId: 'me', conversation: conversation);
      expect(state.groupAvatarNames, ['Home', 'Elsa']);
    });

    test('inbox: the last sender, or just the group when you sent it', () {
      InboxEntry row(String sender, String name) => InboxEntry(
            conversationId: 'c1',
            kind: ConversationKind.group,
            lastActivityAt: DateTime(2026),
            title: 'Home',
            lastMessageId: 1,
            lastMessageSenderId: sender,
            lastSenderName: name,
          );
      expect(row('s', 'shresth').groupAvatarNames('me'), ['Home', 'shresth']);
      expect(row('me', 'elsa').groupAvatarNames('me'), ['Home']);
    });
  });

  group('recently used emoji', () {
    test('the newest pick goes first, without duplicates, capped', () {
      expect(recentAfterPick(['😀', '👍'], '👍'), ['👍', '😀']);
      expect(recentAfterPick(['a', 'b', 'c'], 'd', max: 3), ['d', 'a', 'b']);
    });
  });

  group('swipe to reply', () {
    Future<int> swipe(WidgetTester tester, Offset start, double dx) async {
      var replies = 0;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SwipeToReply(
            onReply: () => replies++,
            child: const SizedBox(
                width: 300, height: 60, child: Text('Did you see it?')),
          ),
        ),
      ));
      final g = await tester.startGesture(start);
      for (var i = 0; i < 10; i++) {
        await g.moveBy(Offset(dx / 10, 0));
        await tester.pump();
      }
      await g.up();
      await tester.pumpAndSettle();
      return replies;
    }

    testWidgets('swiping far enough to the right replies', (tester) async {
      expect(await swipe(tester, const Offset(100, 30), 100), 1);
    });

    testWidgets('a short swipe springs back without replying', (tester) async {
      expect(await swipe(tester, const Offset(100, 30), 30), 0);
    });

    testWidgets('a swipe from the screen edge is left to the back gesture',
        (tester) async {
      expect(await swipe(tester, const Offset(5, 30), 100), 0);
    });
  });

  group('jump to latest', () {
    test('label counts new messages', () {
      expect(JumpToLatest.label(0), 'Latest');
      expect(JumpToLatest.label(1), '1 new message');
      expect(JumpToLatest.label(3), '3 new messages');
    });

    Widget thread(ScrollController scroll,
            {int? newest, bool fromOthers = true}) =>
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Stack(children: [
              ListView.builder(
                controller: scroll,
                reverse: true,
                itemCount: 200,
                itemBuilder: (_, i) =>
                    SizedBox(height: 60, child: Text('Message $i')),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                child: Center(
                  child: JumpToLatest(
                      controller: scroll,
                      newestKey: newest,
                      newestFromOthers: fromOthers),
                ),
              ),
            ]),
          ),
        );

    double opacity(WidgetTester tester) => tester
        .widget<AnimatedOpacity>(find.ancestor(
            of: find.byIcon(Icons.arrow_downward_rounded),
            matching: find.byType(AnimatedOpacity)))
        .opacity;

    testWidgets('hidden at the newest message, shown after scrolling up',
        (tester) async {
      final scroll = ScrollController();
      await tester.pumpWidget(thread(scroll, newest: 1));
      expect(opacity(tester), 0);
      scroll.jumpTo(2000);
      await tester.pumpAndSettle();
      expect(opacity(tester), 1);
      expect(find.text('Latest'), findsOneWidget);
    });

    testWidgets('tapping it goes back to the newest message', (tester) async {
      final scroll = ScrollController();
      await tester.pumpWidget(thread(scroll, newest: 1));
      scroll.jumpTo(8000);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Latest'));
      await tester.pumpAndSettle();
      expect(scroll.offset, 0);
      expect(opacity(tester), 0);
    });

    testWidgets('counts messages from others while scrolled up',
        (tester) async {
      final scroll = ScrollController();
      await tester.pumpWidget(thread(scroll, newest: 1));
      scroll.jumpTo(2000);
      await tester.pumpAndSettle();
      await tester.pumpWidget(thread(scroll, newest: 2));
      await tester.pumpWidget(thread(scroll, newest: 3));
      await tester.pumpWidget(thread(scroll, newest: 4, fromOthers: false));
      await tester.pumpAndSettle();
      expect(find.text('2 new messages'), findsOneWidget);
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('Latest'), findsOneWidget);
    });
  });
}
