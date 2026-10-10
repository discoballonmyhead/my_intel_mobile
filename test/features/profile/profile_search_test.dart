import 'package:flutter_test/flutter_test.dart';
import 'package:mint/features/feed/domain/entities/post.dart';
import 'package:mint/features/profile/presentation/pages/profile_page.dart';

Post _p(int id, String body) =>
    Post(id: id, body: body, createdAt: DateTime(2026));

void main() {
  final posts = [
    _p(1, 'Granbury, Texas is a premier small-town destination'),
    _p(2, 'share'),
    _p(3, 'Drone strikes reported near Kharkiv'),
  ];

  test('matches every word, ignoring case', () {
    expect(searchPosts(posts, 'texas').map((p) => p.id), [1]);
    expect(searchPosts(posts, 'TEXAS small').map((p) => p.id), [1]);
    expect(searchPosts(posts, 'texas drone'), isEmpty);
  });

  test('an empty query finds nothing', () {
    expect(searchPosts(posts, '   '), isEmpty);
  });
}
