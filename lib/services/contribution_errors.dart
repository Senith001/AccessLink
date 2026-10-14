import 'package:firebase_core/firebase_core.dart';

/// Categories of failure that the community contribution & moderation UI
/// needs to distinguish so it can show an honest, actionable message.
enum ContributionErrorKind {
  validation,
  notSignedIn,
  permissionDenied,
  notFound,
  conflict,
  duplicate,
  network,
  partialFailure,
  unknown,
}

/// A user-presentable failure raised by contribution/moderation services.
///
/// Services never swallow Firebase errors; they translate them into this type
/// so widgets can show a specific message and decide whether retry makes sense.
class ContributionException implements Exception {
  final ContributionErrorKind kind;
  final String message;
  final Object? cause;

  const ContributionException(this.kind, this.message, {this.cause});

  bool get isRetryable =>
      kind == ContributionErrorKind.network ||
      kind == ContributionErrorKind.conflict ||
      kind == ContributionErrorKind.unknown ||
      kind == ContributionErrorKind.partialFailure;

  @override
  String toString() => message;
}

/// Converts any thrown object into a [ContributionException].
///
/// [action] is a short human phrase such as "save your rating" that is
/// embedded in generic messages.
ContributionException toContributionException(
  Object error, {
  String action = 'complete this action',
}) {
  if (error is ContributionException) return error;

  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
      case 'unauthorized':
      case 'unauthenticated':
        return ContributionException(
          ContributionErrorKind.permissionDenied,
          'You do not have permission to $action. If you were recently '
          'signed out or your role changed, sign in again.',
          cause: error,
        );
      case 'not-found':
      case 'object-not-found':
        return ContributionException(
          ContributionErrorKind.notFound,
          'The record needed to $action no longer exists.',
          cause: error,
        );
      case 'aborted':
      case 'failed-precondition':
        return ContributionException(
          ContributionErrorKind.conflict,
          'Someone else changed this record at the same time. Refresh and '
          'try again.',
          cause: error,
        );
      case 'unavailable':
      case 'deadline-exceeded':
      case 'network-request-failed':
      case 'retry-limit-exceeded':
        return ContributionException(
          ContributionErrorKind.network,
          'Could not reach the server to $action. Check your connection and '
          'try again.',
          cause: error,
        );
      case 'quota-exceeded':
      case 'resource-exhausted':
        return ContributionException(
          ContributionErrorKind.network,
          'The service is temporarily busy. Please try again shortly.',
          cause: error,
        );
      case 'canceled':
      case 'cancelled':
        return ContributionException(
          ContributionErrorKind.unknown,
          'The request was cancelled before it could $action.',
          cause: error,
        );
    }
    return ContributionException(
      ContributionErrorKind.unknown,
      'Could not $action (${error.code}). Please try again.',
      cause: error,
    );
  }

  if (error is ArgumentError) {
    return ContributionException(
      ContributionErrorKind.validation,
      '${error.message ?? error}',
      cause: error,
    );
  }

  return ContributionException(
    ContributionErrorKind.unknown,
    'Could not $action. Please try again.',
    cause: error,
  );
}

/// True when a Firestore query failed only because a composite index has not
/// been deployed yet. Callers may fall back to an index-free query in that
/// case, but must surface every other failure.
bool isMissingIndexError(Object error) {
  return error is FirebaseException &&
      error.code == 'failed-precondition' &&
      (error.message?.toLowerCase().contains('index') ?? false);
}
