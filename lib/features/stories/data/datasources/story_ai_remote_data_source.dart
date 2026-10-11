import '../../../../core/network/supabase_service.dart';

/// Calls the `anthropic-proxy` Supabase edge function, exactly as the web
/// composer does. The signed-in user's JWT is attached by the client.
abstract interface class StoryAiRemoteDataSource {
  /// The model's text reply, or null if it returned none.
  Future<String?> complete({
    required String model,
    required String prompt,
    required int maxTokens,
  });
}

class StoryAiRemoteDataSourceImpl implements StoryAiRemoteDataSource {
  StoryAiRemoteDataSourceImpl(this._service);
  final SupabaseService _service;

  static const String functionName = 'anthropic-proxy';

  @override
  Future<String?> complete({
    required String model,
    required String prompt,
    required int maxTokens,
  }) async {
    if (!_service.isSignedIn) return null;
    final res = await _service.client.functions.invoke(
      functionName,
      body: {
        'model': model,
        'max_tokens': maxTokens,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      },
    );
    final data = res.data;
    if (data is! Map) return null;
    final content = data['content'];
    if (content is! List || content.isEmpty) return null;
    final first = content.first;
    final text = first is Map ? first['text'] : null;
    final trimmed = text is String ? text.trim() : '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
