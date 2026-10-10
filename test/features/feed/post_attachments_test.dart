import 'package:flutter_test/flutter_test.dart';
import 'package:mint/features/feed/domain/entities/post_extras.dart';
import 'package:mint/features/feed/presentation/widgets/photo_viewer.dart';
import 'package:mint/features/feed/presentation/widgets/post_attachments.dart';

PostAttachment _a(AttachmentKind kind,
        {String? name, String? mime, String url = 'https://x/f'}) =>
    PostAttachment(
        id: 1,
        position: 0,
        kind: kind,
        url: url,
        fileName: name,
        mimeType: mime);

void main() {
  group('attachmentShowsAsImage', () {
    test('photos show as images', () {
      expect(attachmentShowsAsImage(_a(AttachmentKind.image)), isTrue);
    });

    test('a JPG attached as a file shows as an image', () {
      expect(
          attachmentShowsAsImage(_a(AttachmentKind.file, name: 'IMG_0412.JPG')),
          isTrue);
      expect(attachmentShowsAsImage(_a(AttachmentKind.file, mime: 'image/png')),
          isTrue);
      expect(
          attachmentShowsAsImage(
              _a(AttachmentKind.file, url: 'https://x/u/1_0.webp?token=a')),
          isTrue);
    });

    test('other files, videos and audio do not', () {
      expect(
          attachmentShowsAsImage(_a(AttachmentKind.file,
              name: 'report.pdf', mime: 'application/pdf')),
          isFalse);
      expect(attachmentShowsAsImage(_a(AttachmentKind.video, name: 'clip.mov')),
          isFalse);
      expect(attachmentShowsAsImage(_a(AttachmentKind.audio, name: 'note.m4a')),
          isFalse);
    });
  });

  test('photos keep their shape between 3:4 and 1.91:1', () {
    expect(AdaptivePhoto.clampRatio(800 / 1200), closeTo(3 / 4, 1e-9));
    expect(AdaptivePhoto.clampRatio(4 / 5), closeTo(0.8, 1e-9));
    expect(AdaptivePhoto.clampRatio(16 / 9), closeTo(16 / 9, 1e-9));
    expect(AdaptivePhoto.clampRatio(3), closeTo(1.91, 1e-9));
  });
}
