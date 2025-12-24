import 'package:flutter/material.dart';
import 'package:mango_player/mango_player.dart';

/// 自定义 Provider 演示页面
/// 
/// 展示如何使用 MangoPlayer 的模块化扩展架构，
/// 包括 Provider 注册、配置和监控功能。
class CustomProviderPage extends StatefulWidget {
  const CustomProviderPage({Key? key}) : super(key: key);

  @override
  State<CustomProviderPage> createState() => _CustomProviderPageState();
}

class _CustomProviderPageState extends State<CustomProviderPage> {
  late MangoPlayerController _controller;
  bool _isInitialized = false;
  
  // Provider 状态
  List<ProviderInfo> _registeredProviders = [];
  DecoderInfo? _decoderInfo;
  RendererInfo? _rendererInfo;

  // 默认测试视频
  static const String _defaultVideoUrl =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

  @override
  void initState() {
    super.initState();
    _controller = MangoPlayerController();
    _loadProviderInfo();
    _initializePlayer();
  }

  void _loadProviderInfo() {
    // 获取已注册的 Provider 信息
    _registeredProviders = ProviderRegistry.instance.getAllProviders();
    setState(() {});
  }

  Future<void> _initializePlayer() async {
    try {
      await _controller.initialize(
        MediaSource.network(_defaultVideoUrl),
      );
      setState(() {
        _isInitialized = true;
      });
      _updateDecoderInfo();
      _updateRendererInfo();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('初始化失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updateDecoderInfo() {
    // 模拟获取解码器信息
    // 实际实现中需要通过 Platform Channel 获取
    _decoderInfo = DecoderInfo(
      type: DecoderType.hardware,
      codecName: 'h264',
      isHardwareAccelerated: true,
    );
    setState(() {});
  }

  void _updateRendererInfo() {
    // 模拟获取渲染器信息
    _rendererInfo = RendererInfo(
      type: RendererType.externalTexture,
      textureId: _controller.textureId,
      isActive: true,
    );
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('模块化扩展演示'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 视频预览区域
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: Colors.black,
                child: _isInitialized
                    ? MangoPlayerView(controller: _controller)
                    : const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Provider 注册表
            _buildSection(
              title: '已注册的 Providers',
              child: _buildProviderList(),
            ),
            
            const SizedBox(height: 24),
            
            // 解码器信息
            _buildSection(
              title: '解码器状态',
              child: _buildDecoderInfo(),
            ),
            
            const SizedBox(height: 24),
            
            // 渲染器信息
            _buildSection(
              title: '渲染器状态',
              child: _buildRendererInfo(),
            ),
            
            const SizedBox(height: 24),
            
            // 自定义 Provider 说明
            _buildSection(
              title: '如何注册自定义 Provider',
              child: _buildCustomProviderGuide(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildProviderList() {
    if (_registeredProviders.isEmpty) {
      return const Text('加载中...');
    }
    
    return Column(
      children: _registeredProviders.map((provider) {
        return ListTile(
          leading: _getProviderIcon(provider.type),
          title: Text(provider.name),
          subtitle: Text('版本: ${provider.version} | 优先级: ${provider.priority}'),
          trailing: Chip(
            label: Text(_getProviderTypeName(provider.type)),
            size: ChipSize.small,
          ),
        );
      }).toList(),
    );
  }

  Widget _getProviderIcon(ProviderType type) {
    switch (type) {
      case ProviderType.dataSource:
        return const Icon(Icons.folder_open, color: Colors.blue);
      case ProviderType.decoder:
        return const Icon(Icons.memory, color: Colors.green);
      case ProviderType.renderer:
        return const Icon(Icons.videocam, color: Colors.orange);
    }
  }

  String _getProviderTypeName(ProviderType type) {
    switch (type) {
      case ProviderType.dataSource:
        return '数据源';
      case ProviderType.decoder:
        return '解码器';
      case ProviderType.renderer:
        return '渲染器';
    }
  }

  Widget _buildDecoderInfo() {
    if (_decoderInfo == null) {
      return const Text('未初始化');
    }
    
    return Column(
      children: [
        _buildInfoRow('类型', _decoderInfo!.type.name),
        _buildInfoRow('编解码器', _decoderInfo!.codecName ?? 'N/A'),
        _buildInfoRow(
          '硬件加速',
          _decoderInfo!.isHardwareAccelerated ? '✅ 是' : '❌ 否',
        ),
        if (_decoderInfo!.fallbackReason != null)
          _buildInfoRow('降级原因', _decoderInfo!.fallbackReason!),
      ],
    );
  }

  Widget _buildRendererInfo() {
    if (_rendererInfo == null) {
      return const Text('未初始化');
    }
    
    return Column(
      children: [
        _buildInfoRow('类型', _rendererInfo!.type.name),
        _buildInfoRow('Texture ID', _rendererInfo!.textureId?.toString() ?? 'N/A'),
        _buildInfoRow('状态', _rendererInfo!.isActive ? '✅ 活跃' : '❌ 未激活'),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomProviderGuide() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '1. 实现 Provider 接口',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 4),
        Text(
          '创建自定义类实现 DataSourceProvider、DecoderProvider 或 RendererProvider 抽象类。',
          style: TextStyle(color: Colors.grey),
        ),
        SizedBox(height: 12),
        Text(
          '2. 注册到 ProviderRegistry',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 4),
        Text(
          '使用 ProviderRegistry.instance.register() 注册您的自定义实现。',
          style: TextStyle(color: Colors.grey),
        ),
        SizedBox(height: 12),
        Text(
          '3. 设置优先级',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 4),
        Text(
          '通过优先级参数控制 Provider 的选择顺序，高优先级的 Provider 会优先使用。',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}

// 模型类（用于示例）
enum ProviderType { dataSource, decoder, renderer }
enum DecoderType { hardware, software, auto }
enum RendererType { externalTexture, surfaceView }
enum ChipSize { small, medium }

class ProviderInfo {
  final ProviderType type;
  final String name;
  final String version;
  final int priority;

  ProviderInfo({
    required this.type,
    required this.name,
    required this.version,
    this.priority = 0,
  });
}

class DecoderInfo {
  final DecoderType type;
  final String? codecName;
  final bool isHardwareAccelerated;
  final String? fallbackReason;

  DecoderInfo({
    required this.type,
    this.codecName,
    this.isHardwareAccelerated = false,
    this.fallbackReason,
  });
}

class RendererInfo {
  final RendererType type;
  final int? textureId;
  final bool isActive;

  RendererInfo({
    required this.type,
    this.textureId,
    this.isActive = false,
  });
}

// 模拟 ProviderRegistry（实际实现在 Dart providers 层）
class ProviderRegistry {
  static final ProviderRegistry instance = ProviderRegistry._();
  
  ProviderRegistry._();
  
  List<ProviderInfo> getAllProviders() {
    // 返回模拟数据
    return [
      ProviderInfo(
        type: ProviderType.dataSource,
        name: 'DefaultDataSourceProvider',
        version: '1.0.0',
        priority: 0,
      ),
      ProviderInfo(
        type: ProviderType.decoder,
        name: 'HardwareDecoderProvider',
        version: '1.0.0',
        priority: 10,
      ),
      ProviderInfo(
        type: ProviderType.decoder,
        name: 'SoftwareDecoderProvider',
        version: '1.0.0',
        priority: 0,
      ),
      ProviderInfo(
        type: ProviderType.renderer,
        name: 'ExternalTextureRenderer',
        version: '1.0.0',
        priority: 10,
      ),
    ];
  }
}

// Chip 扩展以支持 size
extension ChipExtension on Chip {
  Chip copyWith({ChipSize? size}) {
    return this;
  }
}
