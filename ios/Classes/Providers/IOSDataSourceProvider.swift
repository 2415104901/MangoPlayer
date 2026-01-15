import Foundation
import Flutter

/// iOS 数据源提供者实现
///
/// 实现 DataSourceProvider 接口，负责管理媒体数据源的加载和配置。
/// 支持网络资源、本地文件和 Flutter Asset。
public class IOSDataSourceProvider {
    
    // MARK: - Types
    
    /// 数据源类型
    public enum SourceType {
        case network
        case file
        case asset
    }
    
    /// 数据源信息
    public struct DataSourceInfo {
        let uri: String
        let type: SourceType
        let headers: [String: String]?
        let mimeType: String?
        
        public init(uri: String, type: SourceType, headers: [String: String]? = nil, mimeType: String? = nil) {
            self.uri = uri
            self.type = type
            self.headers = headers
            self.mimeType = mimeType
        }
    }
    
    // MARK: - Properties
    
    private static let supportedSchemes: Set<String> = [
        "http", "https", "rtmp", "rtmps", "rtsp", "file", "asset"
    ]
    
    private let registrar: FlutterPluginRegistrar?
    
    // MARK: - Initialization
    
    public init(registrar: FlutterPluginRegistrar? = nil) {
        self.registrar = registrar
    }
    
    // MARK: - Public Methods
    
    /// 检查 URI 是否受支持
    public func isSupported(_ uri: String) -> Bool {
        guard let url = URL(string: uri) else { return false }
        let scheme = url.scheme?.lowercased() ?? "file"
        return IOSDataSourceProvider.supportedSchemes.contains(scheme)
    }
    
    /// 解析数据源类型
    public func parseSourceType(_ uri: String) -> SourceType {
        guard let url = URL(string: uri) else { return .file }
        
        switch url.scheme?.lowercased() {
        case "http", "https", "rtmp", "rtmps", "rtsp":
            return .network
        case "asset":
            return .asset
        default:
            return .file
        }
    }
    
    /// 获取完整的文件路径
    /// 
    /// - Parameter info: 数据源信息
    /// - Returns: 完整的文件 URL
    public func resolveUrl(for info: DataSourceInfo) -> URL? {
        switch info.type {
        case .network:
            return URL(string: info.uri)
            
        case .file:
            let path = info.uri.hasPrefix("file://") 
                ? String(info.uri.dropFirst(7)) 
                : info.uri
            return URL(fileURLWithPath: path)
            
        case .asset:
            return resolveAssetUrl(info.uri)
        }
    }
    
    /// 解析 Flutter Asset 路径
    private func resolveAssetUrl(_ uri: String) -> URL? {
        // 移除 asset:// 前缀
        let assetPath = uri.hasPrefix("asset://") 
            ? String(uri.dropFirst(8)) 
            : uri
        
        // 使用 FlutterPluginRegistrar 查找 asset
        if let registrar = registrar {
            let key = registrar.lookupKey(forAsset: assetPath)
            if let path = Bundle.main.path(forResource: key, ofType: nil) {
                return URL(fileURLWithPath: path)
            }
        }
        
        // 回退到直接在 Bundle 中查找
        if let path = Bundle.main.path(forResource: assetPath, ofType: nil) {
            return URL(fileURLWithPath: path)
        }
        
        return nil
    }
    
    /// 获取数据源的 MIME 类型
    public func getMimeType(_ uri: String) -> String? {
        let ext = (uri as NSString).pathExtension.lowercased()
        
        switch ext {
        case "mp4", "m4v":
            return "video/mp4"
        case "mkv":
            return "video/x-matroska"
        case "avi":
            return "video/x-msvideo"
        case "mov":
            return "video/quicktime"
        case "webm":
            return "video/webm"
        case "flv":
            return "video/x-flv"
        case "ts", "m2ts":
            return "video/mp2t"
        case "3gp":
            return "video/3gpp"
        case "m3u8":
            return "application/x-mpegURL"
        case "mp3":
            return "audio/mpeg"
        case "aac", "m4a":
            return "audio/aac"
        case "flac":
            return "audio/flac"
        case "wav":
            return "audio/wav"
        case "ogg":
            return "audio/ogg"
        default:
            return nil
        }
    }
    
    /// 构建带 headers 的 URLRequest
    public func createRequest(for info: DataSourceInfo) -> URLRequest? {
        guard let url = resolveUrl(for: info) else { return nil }
        
        var request = URLRequest(url: url)
        
        if let headers = info.headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        return request
    }
}
