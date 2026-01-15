#ifndef WINDOWS_DATA_SOURCE_PROVIDER_H_
#define WINDOWS_DATA_SOURCE_PROVIDER_H_

#include <string>
#include <map>
#include <optional>

namespace mango_player {

/**
 * Windows 数据源提供者实现
 * 
 * 实现 DataSourceProvider 接口，负责管理媒体数据源的加载和配置。
 * 支持网络资源、本地文件和 Flutter Asset。
 */
class WindowsDataSourceProvider {
 public:
  /**
   * 数据源类型
   */
  enum class SourceType {
    kNetwork,  // 网络资源
    kFile,     // 本地文件
    kAsset     // Flutter Asset
  };

  /**
   * 数据源信息
   */
  struct DataSourceInfo {
    std::string uri;
    SourceType type;
    std::map<std::string, std::string> headers;
    std::optional<std::string> mime_type;
  };

  WindowsDataSourceProvider();
  ~WindowsDataSourceProvider();

  /**
   * 检查 URI 是否受支持
   */
  bool IsSupported(const std::string& uri) const;

  /**
   * 解析数据源类型
   */
  SourceType ParseSourceType(const std::string& uri) const;

  /**
   * 解析完整的文件路径
   */
  std::string ResolvePath(const DataSourceInfo& info) const;

  /**
   * 获取数据源的 MIME 类型
   */
  std::optional<std::string> GetMimeType(const std::string& uri) const;

  /**
   * 设置 Flutter Asset 根路径
   */
  void SetAssetRoot(const std::string& root);

 private:
  std::string asset_root_;

  std::string GetFileExtension(const std::string& path) const;
  std::string ToLower(const std::string& str) const;
};

}  // namespace mango_player

#endif  // WINDOWS_DATA_SOURCE_PROVIDER_H_
