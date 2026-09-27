import 'package:equatable/equatable.dart';

/// A row of `content.post_edits`: the text a post had before one edit.
class PostEdit extends Equatable {
  const PostEdit({
    required this.id,
    required this.postId,
    required this.previousBody,
    required this.editedAt,
    this.editorId,
  });

  final int id;
  final int postId;
  final String previousBody;
  final DateTime editedAt;
  final String? editorId;

  @override
  List<Object?> get props => [id, postId, editedAt];
}
