/// 播放器错误代码枚举
/// 
/// 定义所有可能的播放器错误类型。
enum PlayerErrorCode {
  /// 媒体源不存在
  sourceNotFound,
  
  /// 不支持的媒体格式（容器格式）
  sourceNotSupported,
  
  /// 不支持的编解码器
  codecNotSupported,
  
  /// 网络错误
  networkError,
  
  /// 解码错误
  decodingError,
  
  /// 渲染错误
  renderingError,
  
  /// 缓冲区不足
  bufferUnderrun,
  
  /// 平台不支持
  platformNotSupported,
  
  /// 权限被拒绝
  permissionDenied,
  
  /// 硬件解码不可用（已回退到软解）
  hardwareDecoderUnavailable,
  
  /// 未知错误
  unknown,
}

/// 播放器错误类
/// 
/// 封装错误信息，包括错误码、错误消息和平台特定详情。
class PlayerError {
  /// 错误代码
  final PlayerErrorCode code;
  
  /// 错误消息
  final String message;
  
  /// 平台特定详情（可选）
  final dynamic platformDetails;
  
  /// 堆栈追踪（Debug 模式下可用）
  final StackTrace? stackTrace;

  const PlayerError({
    required this.code,
    required this.message,
    this.platformDetails,
    this.stackTrace,
  });
  
  /// 是否为格式相关错误
  bool get isFormatError => 
      code == PlayerErrorCode.sourceNotSupported ||
      code == PlayerErrorCode.codecNotSupported;
  
  /// 是否为网络相关错误
  bool get isNetworkError => code == PlayerErrorCode.networkError;
  
  /// 是否为可恢复错误
  bool get isRecoverable => 
      code == PlayerErrorCode.bufferUnderrun ||
      code == PlayerErrorCode.hardwareDecoderUnavailable;
  
  @override
  String toString() {
    return 'PlayerError(code: $code, message: $message)';
  }
}
