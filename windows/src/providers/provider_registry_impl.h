#ifndef PROVIDER_REGISTRY_IMPL_H_
#define PROVIDER_REGISTRY_IMPL_H_

#include <memory>
#include <map>
#include <vector>
#include <string>
#include <mutex>

#include "windows_data_source_provider.h"
#include "windows_decoder_provider.h"
#include "windows_renderer_provider.h"

namespace mango_player {

/**
 * Provider 注册表实现
 * 
 * 管理和注册各种 Provider（DataSource、Decoder、Renderer），
 * 支持运行时替换和扩展。
 */
class ProviderRegistryImpl {
 public:
  /**
   * Provider 类型
   */
  enum class ProviderType {
    kDataSource,
    kDecoder,
    kRenderer
  };

  /**
   * Provider 信息
   */
  struct ProviderInfo {
    ProviderType type;
    std::string name;
    std::string version;
    int priority = 0;
  };

  /**
   * 获取单例实例
   */
  static ProviderRegistryImpl& GetInstance();

  // 禁止拷贝和移动
  ProviderRegistryImpl(const ProviderRegistryImpl&) = delete;
  ProviderRegistryImpl& operator=(const ProviderRegistryImpl&) = delete;

  /**
   * 获取数据源 Provider
   */
  std::shared_ptr<WindowsDataSourceProvider> GetDataSourceProvider();

  /**
   * 获取解码器 Provider
   */
  std::shared_ptr<WindowsDecoderProvider> GetDecoderProvider();

  /**
   * 获取渲染器 Provider
   */
  std::shared_ptr<WindowsRendererProvider> GetRendererProvider();

  /**
   * 注册自定义 Provider
   */
  template <typename T>
  void RegisterProvider(std::shared_ptr<T> provider, const ProviderInfo& info);

  /**
   * 获取所有 Provider 信息
   */
  std::vector<ProviderInfo> GetAllProviderInfo() const;

  /**
   * 重置为默认 Provider
   */
  void Reset();

 private:
  ProviderRegistryImpl();
  ~ProviderRegistryImpl() = default;

  void RegisterDefaultProviders();

  std::shared_ptr<WindowsDataSourceProvider> data_source_provider_;
  std::shared_ptr<WindowsDecoderProvider> decoder_provider_;
  std::shared_ptr<WindowsRendererProvider> renderer_provider_;
  
  std::map<void*, ProviderInfo> provider_info_map_;
  mutable std::mutex mutex_;
};

// 模板实现
template <typename T>
void ProviderRegistryImpl::RegisterProvider(
    std::shared_ptr<T> provider, const ProviderInfo& info) {
  std::lock_guard<std::mutex> lock(mutex_);
  
  provider_info_map_[provider.get()] = info;
  
  // 根据类型更新对应的 Provider
  if constexpr (std::is_same_v<T, WindowsDataSourceProvider>) {
    if (info.priority > provider_info_map_[data_source_provider_.get()].priority) {
      data_source_provider_ = provider;
    }
  } else if constexpr (std::is_same_v<T, WindowsDecoderProvider>) {
    if (info.priority > provider_info_map_[decoder_provider_.get()].priority) {
      decoder_provider_ = provider;
    }
  } else if constexpr (std::is_same_v<T, WindowsRendererProvider>) {
    if (info.priority > provider_info_map_[renderer_provider_.get()].priority) {
      renderer_provider_ = provider;
    }
  }
}

}  // namespace mango_player

#endif  // PROVIDER_REGISTRY_IMPL_H_
