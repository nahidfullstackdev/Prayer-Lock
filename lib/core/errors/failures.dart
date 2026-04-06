/// Base class for all failures in the application
abstract class Failure {
  final String message;

  const Failure(this.message);

  @override
  String toString() => message;
}

/// Failure when server returns an error
class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

/// Failure when there's a network/connectivity issue
class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

/// Failure when local cache/database operation fails
class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

/// Failure when database operation fails
class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message);
}

/// Failure for unknown/unexpected errors
class UnknownFailure extends Failure {
  const UnknownFailure(super.message);
}

/// Failure when user denies permission (location, notifications, etc.)
class PermissionFailure extends Failure {
  const PermissionFailure(super.message);
}
