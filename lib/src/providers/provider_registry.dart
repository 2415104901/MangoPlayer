import 'data_source_provider.dart';
import 'decoder_provider.dart';
import 'renderer_provider.dart';

class ProviderRegistry {
  static final ProviderRegistry instance = ProviderRegistry._();

  ProviderRegistry._();

  final Map<String, DataSourceProvider Function()> _dataSourceFactories = {};
  final Map<String, DecoderProvider Function()> _decoderFactories = {};
  final Map<String, RendererProvider Function()> _rendererFactories = {};

  void registerDataSource(String scheme, DataSourceProvider Function() factory) {
    _dataSourceFactories[scheme] = factory;
  }

  void registerDecoder(String codec, DecoderProvider Function() factory) {
    _decoderFactories[codec] = factory;
  }

  void registerRenderer(String type, RendererProvider Function() factory) {
    _rendererFactories[type] = factory;
  }

  DataSourceProvider getDataSource(String scheme) {
    final factory = _dataSourceFactories[scheme];
    if (factory == null) {
      throw Exception('No DataSourceProvider registered for scheme: $scheme');
    }
    return factory();
  }

  DecoderProvider getDecoder(String codec) {
    final factory = _decoderFactories[codec];
    if (factory == null) {
      throw Exception('No DecoderProvider registered for codec: $codec');
    }
    return factory();
  }

  RendererProvider getRenderer(String type) {
    final factory = _rendererFactories[type];
    if (factory == null) {
      throw Exception('No RendererProvider registered for type: $type');
    }
    return factory();
  }
}
