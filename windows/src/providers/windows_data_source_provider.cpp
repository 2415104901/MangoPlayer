#include "windows_data_source_provider.h"

#include <algorithm>
#include <cctype>
#include <regex>

namespace mango_player {

namespace {

const std::vector<std::string> kSupportedSchemes = {
    "http", "https", "rtmp", "rtmps", "rtsp", "file", "asset"
};

const std::map<std::string, std::string> kMimeTypes = {
    {"mp4", "video/mp4"},
    {"m4v", "video/mp4"},
    {"mkv", "video/x-matroska"},
    {"avi", "video/x-msvideo"},
    {"mov", "video/quicktime"},
    {"webm", "video/webm"},
    {"flv", "video/x-flv"},
    {"ts", "video/mp2t"},
    {"m2ts", "video/mp2t"},
    {"3gp", "video/3gpp"},
    {"m3u8", "application/x-mpegURL"},
    {"mp3", "audio/mpeg"},
    {"aac", "audio/aac"},
    {"m4a", "audio/aac"},
    {"flac", "audio/flac"},
    {"wav", "audio/wav"},
    {"ogg", "audio/ogg"}
};

}  // namespace

WindowsDataSourceProvider::WindowsDataSourceProvider() = default;
WindowsDataSourceProvider::~WindowsDataSourceProvider() = default;

bool WindowsDataSourceProvider::IsSupported(const std::string& uri) const {
  // 提取 scheme
  std::regex scheme_regex("^([a-zA-Z][a-zA-Z0-9+.-]*):.*");
  std::smatch match;
  
  if (std::regex_match(uri, match, scheme_regex)) {
    std::string scheme = ToLower(match[1].str());
    return std::find(kSupportedSchemes.begin(), kSupportedSchemes.end(), scheme) 
           != kSupportedSchemes.end();
  }
  
  // 没有 scheme，假设是本地文件
  return true;
}

WindowsDataSourceProvider::SourceType 
WindowsDataSourceProvider::ParseSourceType(const std::string& uri) const {
  std::regex scheme_regex("^([a-zA-Z][a-zA-Z0-9+.-]*):.*");
  std::smatch match;
  
  if (std::regex_match(uri, match, scheme_regex)) {
    std::string scheme = ToLower(match[1].str());
    
    if (scheme == "http" || scheme == "https" || 
        scheme == "rtmp" || scheme == "rtmps" || scheme == "rtsp") {
      return SourceType::kNetwork;
    } else if (scheme == "asset") {
      return SourceType::kAsset;
    }
  }
  
  return SourceType::kFile;
}

std::string WindowsDataSourceProvider::ResolvePath(const DataSourceInfo& info) const {
  switch (info.type) {
    case SourceType::kNetwork:
      return info.uri;
      
    case SourceType::kFile: {
      std::string path = info.uri;
      // 移除 file:// 前缀
      if (path.find("file://") == 0) {
        path = path.substr(7);
      }
      // Windows 路径处理
      // file:///C:/path -> C:/path
      if (!path.empty() && path[0] == '/') {
        path = path.substr(1);
      }
      return path;
    }
      
    case SourceType::kAsset: {
      std::string asset_path = info.uri;
      // 移除 asset:// 前缀
      if (asset_path.find("asset://") == 0) {
        asset_path = asset_path.substr(8);
      }
      // 拼接 asset 根路径
      if (!asset_root_.empty()) {
        return asset_root_ + "/" + asset_path;
      }
      return asset_path;
    }
  }
  
  return info.uri;
}

std::optional<std::string> 
WindowsDataSourceProvider::GetMimeType(const std::string& uri) const {
  std::string ext = ToLower(GetFileExtension(uri));
  
  auto it = kMimeTypes.find(ext);
  if (it != kMimeTypes.end()) {
    return it->second;
  }
  
  return std::nullopt;
}

void WindowsDataSourceProvider::SetAssetRoot(const std::string& root) {
  asset_root_ = root;
}

std::string WindowsDataSourceProvider::GetFileExtension(const std::string& path) const {
  size_t dot_pos = path.rfind('.');
  if (dot_pos != std::string::npos && dot_pos < path.length() - 1) {
    return path.substr(dot_pos + 1);
  }
  return "";
}

std::string WindowsDataSourceProvider::ToLower(const std::string& str) const {
  std::string result = str;
  std::transform(result.begin(), result.end(), result.begin(),
                 [](unsigned char c) { return std::tolower(c); });
  return result;
}

}  // namespace mango_player
