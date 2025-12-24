class PlayerConfig {
  final bool autoPlay;
  final bool looping;
  final bool preferHardwareDecoding;
  final Duration eventUpdateInterval;
  final int bufferSize;
  final bool enableLogging;

  const PlayerConfig({
    this.autoPlay = false,
    this.looping = false,
    this.preferHardwareDecoding = true,
    this.eventUpdateInterval = const Duration(milliseconds: 500),
    this.bufferSize = 10,
    this.enableLogging = false,
  });
}
