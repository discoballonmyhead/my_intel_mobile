import 'dart:async';

import 'entities/post.dart';

/// App-wide "this post changed" channel. The Feed and the Profile each keep
/// their own list; when one likes, saves, reposts or creates a post it
/// publishes the result here and the other updates without a refresh.
class PostUpdates {
  final _controller = StreamController<Post>.broadcast();

  Stream<Post> get stream => _controller.stream;

  void publish(Post post) => _controller.add(post);
}
