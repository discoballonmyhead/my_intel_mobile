import '../utils/result.dart';

/// Contract for a single unit of business logic. Kept deliberately thin: a
/// use case owns one intention, takes typed params and returns a [Result].
abstract interface class UseCase<Type, Params> {
  Future<Result<Type>> call(Params params);
}

/// Use cases that return a live stream rather than a single value.
abstract interface class StreamUseCase<Type, Params> {
  Stream<Type> call(Params params);
}

/// Placeholder for use cases that take no arguments.
class NoParams {
  const NoParams();
}
