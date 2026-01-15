#include "provider_registry_impl.h"

namespace mango_player {

ProviderRegistryImpl& ProviderRegistryImpl::GetInstance() {
  static ProviderRegistryImpl instance;
  return instance;
}

ProviderRegistryImpl::ProviderRegistryImpl() {
  RegisterDefaultProviders();
}

void ProviderRegistryImpl::RegisterDefaultProviders() {
  // 数据源 Provider
  data_source_provider_ = std::make_shared<WindowsDataSourceProvider>();
  provider_info_map_[data_source_provider_.get()] = ProviderInfo{
      ProviderType::kDataSource,
      "WindowsDataSourceProvider",
      "1.0.0",
      0
  };
  
  // 解码器 Provider
  decoder_provider_ = std::make_shared<WindowsDecoderProvider>();
  provider_info_map_[decoder_provider_.get()] = ProviderInfo{
      ProviderType::kDecoder,
      "WindowsDecoderProvider",
      "1.0.0",
      0
  };
  
  // 渲染器 Provider
  renderer_provider_ = std::make_shared<WindowsRendererProvider>();
  provider_info_map_[renderer_provider_.get()] = ProviderInfo{
      ProviderType::kRenderer,
      "WindowsRendererProvider",
      "1.0.0",
      0
  };
}

std::shared_ptr<WindowsDataSourceProvider> 
ProviderRegistryImpl::GetDataSourceProvider() {
  std::lock_guard<std::mutex> lock(mutex_);
  return data_source_provider_;
}

std::shared_ptr<WindowsDecoderProvider> 
ProviderRegistryImpl::GetDecoderProvider() {
  std::lock_guard<std::mutex> lock(mutex_);
  return decoder_provider_;
}

std::shared_ptr<WindowsRendererProvider> 
ProviderRegistryImpl::GetRendererProvider() {
  std::lock_guard<std::mutex> lock(mutex_);
  return renderer_provider_;
}

std::vector<ProviderRegistryImpl::ProviderInfo> 
ProviderRegistryImpl::GetAllProviderInfo() const {
  std::lock_guard<std::mutex> lock(mutex_);
  
  std::vector<ProviderInfo> result;
  result.reserve(provider_info_map_.size());
  
  for (const auto& [ptr, info] : provider_info_map_) {
    result.push_back(info);
  }
  
  return result;
}

void ProviderRegistryImpl::Reset() {
  std::lock_guard<std::mutex> lock(mutex_);
  
  provider_info_map_.clear();
  data_source_provider_.reset();
  decoder_provider_.reset();
  renderer_provider_.reset();
  
  RegisterDefaultProviders();
}

}  // namespace mango_player
