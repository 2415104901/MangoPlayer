# MangoPlayer
a cross platfrom player by flutter plugin.
## 项目愿景

MangoPlayer 旨在降低 Flutter 应用开发音视频播放的技术难度，同时确保达到 Native 相当的性能。

### 核心特性
- **跨平台支持**: 统一的 API 支持 iOS 和 Android
- **Native 性能**: 基于 ijkplayer + ffmpeg + WebRTC 渲染，性能媲美原生播放器
- **易于集成**: 简洁的 Flutter API，降低开发难度
- **高度可扩展**: 模块化设计，支持自定义扩展

### 技术架构
- **播放引擎**: ijkplayer（成熟稳定的播放框架）
- **解码库**: ffmpeg（支持广泛的音视频格式）
- **渲染模块**: WebRTC 渲染模块（高性能跨平台渲染）

## 开发指南

### 核心原则概览
1. **跨平台一致性**: API 在所有平台上行为一致
2. **Native 性能优先**: 性能达到原生播放器水平
3. **模块化架构**: 职责清晰，易于测试和扩展
4. **测试优先开发**: 完整的自动化测试覆盖
5. **文档完整性**: 清晰完整的文档支持
6. **API 稳定性**: 向后兼容，稳定可靠