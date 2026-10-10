import 'package:flutter_test/flutter_test.dart';
import 'package:mint/features/feed/data/models/post_extras_model.dart';
import 'package:mint/features/feed/data/models/post_model.dart';
import 'package:mint/features/feed/domain/entities/post_extras.dart';

void main() {
  group('PostExtrasModel', () {
    test('parses attachments in position order', () {
      final list = PostExtrasModel.attachmentsFromJson([
        {'id': 2, 'position': 1, 'kind': 'video', 'url': 'https://x/v.mp4', 'size_bytes': 2048},
        {'id': 1, 'position': 0, 'kind': 'image', 'url': 'https://x/a.jpg', 'width': 800},
      ]);
      expect(list.map((a) => a.id), [1, 2]);
      expect(list.first.kind, AttachmentKind.image);
      expect(list.first.width, 800);
      expect(list.last.sizeBytes, 2048);
    });

    test('treats a missing or malformed payload as no attachments', () {
      expect(PostExtrasModel.attachmentsFromJson(null), isEmpty);
      expect(PostExtrasModel.attachmentsFromJson('nope'), isEmpty);
    });

    test('parses a poll with the viewer vote', () {
      final poll = PostExtrasModel.pollFromJson({
        'post_id': 9,
        'ends_at': '2030-01-01T00:00:00Z',
        'is_closed': false,
        'total_votes': 3,
        'my_option_id': 5,
        'options': [
          {'id': 6, 'position': 1, 'label': 'No', 'votes': 1},
          {'id': 5, 'position': 0, 'label': 'Yes', 'votes': 2},
        ],
      })!;
      expect(poll.postId, 9);
      expect(poll.hasVoted, isTrue);
      expect(poll.options.map((o) => o.label), ['Yes', 'No']);
      expect(poll.closedAt(DateTime.utc(2029)), isFalse);
      expect(poll.closedAt(DateTime.utc(2031)), isTrue);
    });

    test('social_create_post rows carry attachments and poll inline', () {
      final post = PostModel.fromJson(const {
        'id': 1,
        'body': 'hi',
        'created_at': '2026-10-09T00:00:00Z',
        'attachments': [
          {'id': 1, 'position': 0, 'kind': 'file', 'url': 'https://x/r.pdf'},
        ],
        'poll': null,
      });
      expect(post.hasAttachments, isTrue);
      expect(post.poll, isNull);
    });
  });

  group('PollDraft', () {
    test('needs 2 to 4 non-empty options', () {
      expect(const PollDraft(options: ['Yes', '  ']).isValid, isFalse);
      expect(const PollDraft(options: ['Yes', 'No']).isValid, isTrue);
      expect(const PollDraft(options: ['a', 'b', 'c', 'd', 'e']).isValid, isFalse);
    });

    test('rejects long options and out-of-range lengths', () {
      expect(PollDraft(options: ['a' * 81, 'b']).isValid, isFalse);
      expect(const PollDraft(options: ['a', 'b'], durationHours: 0).isValid, isFalse);
      expect(const PollDraft(options: ['a', 'b'], durationHours: 169).isValid, isFalse);
    });

    test('sends trimmed options', () {
      expect(const PollDraft(options: [' Yes ', 'No', ''], durationHours: 6).toJson(),
          {'options': ['Yes', 'No'], 'duration_hours': 6});
    });
  });
}
