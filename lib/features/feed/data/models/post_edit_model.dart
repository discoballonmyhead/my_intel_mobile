import '../../../../core/network/rpc_runner.dart';
import '../../../../core/utils/date_x.dart';
import '../../domain/entities/post_edit.dart';

class PostEditModel extends PostEdit {
  const PostEditModel({
    required super.id,
    required super.postId,
    required super.previousBody,
    required super.editedAt,
    super.editorId,
  });

  factory PostEditModel.fromJson(Map<String, dynamic> json) => PostEditModel(
        id: asInt(json['id']) ?? 0,
        postId: asInt(json['post_id']) ?? 0,
        previousBody: (json['previous_content'] as String?) ?? '',
        editedAt: parseTimestamp(json['edited_at']) ?? DateTime.now().toUtc(),
        editorId: json['editor_id'] as String?,
      );
}
