enum MediaSourceType {
  network,
  file,
  asset,
}

class MediaSource {
  final Uri uri;
  final MediaSourceType type;
  final Map<String, String>? headers;
  final String? mimeType;

  const MediaSource({
    required this.uri,
    required this.type,
    this.headers,
    this.mimeType,
  });

  factory MediaSource.network(String url, {Map<String, String>? headers}) {
    return MediaSource(
      uri: Uri.parse(url),
      type: MediaSourceType.network,
      headers: headers,
    );
  }

  factory MediaSource.file(String path) {
    return MediaSource(
      uri: Uri.file(path),
      type: MediaSourceType.file,
    );
  }

  factory MediaSource.asset(String assetPath) {
    return MediaSource(
      uri: Uri.parse('asset://$assetPath'),
      type: MediaSourceType.asset,
    );
  }
}
