enum PlayerErrorCode {
  sourceNotFound,
  sourceNotSupported,
  networkError,
  decodingError,
  renderingError,
  bufferUnderrun,
  platformNotSupported,
  permissionDenied,
  unknown,
}

class PlayerError {
  final PlayerErrorCode code;
  final String message;
  final dynamic platformDetails;
  final StackTrace? stackTrace;

  const PlayerError({
    required this.code,
    required this.message,
    this.platformDetails,
    this.stackTrace,
  });
}
