import Foundation
import FlutterMacOS

/// Provider 注册表实现
///
/// 管理和注册各种 Provider（DataSource、Decoder、Renderer），
/// 支持运行时替换和扩展。
public class ProviderRegistryImpl {
    
    // MARK: - Types
    
    /// Provider 类型
    public enum ProviderType: String {
        case dataSource = "data_source"
        case decoder = "decoder"
        case renderer = "renderer"
    }
    
    /// Provider 信息
    public struct ProviderInfo {
        let type: ProviderType
        let name: String
        let version: String
        let priority: Int
        
        public init(
            type: ProviderType,
            name: String,
            version: String,
            priority: Int = 0
        ) {
            self.type = type
            self.name = name
            self.version = version
            self.priority = priority
        }
    }
    
    // MARK: - Singleton
    
    public static let shared = ProviderRegistryImpl()
    
    // MARK: - Properties
    
    private var registrar: FlutterPluginRegistrar?
    
    // 默认 Provider
    private var _dataSourceProvider: MacOSDataSourceProvider?
    private var _decoderProvider: MacOSDecoderProvider?
    private var _rendererProvider: MacOSRendererProvider?
    
    // 已注册的 Provider
    private var registeredProviders: [ProviderType: [AnyObject]] = [:]
    private var providerInfoMap: [ObjectIdentifier: ProviderInfo] = [:]
    
    private let lock = NSLock()
    
    // MARK: - Initialization
    
    private init() {
        registerDefaultProviders()
    }
    
    // MARK: - Configuration
    
    /// 配置注册表
    public func configure(with registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
        
        // 重新创建需要 registrar 的 Provider
        _dataSourceProvider = MacOSDataSourceProvider(registrar: registrar)
    }
    
    // MARK: - Default Providers
    
    private func registerDefaultProviders() {
        // DataSource Provider
        let dataSourceProvider = MacOSDataSourceProvider()
        _dataSourceProvider = dataSourceProvider
        registerProvider(
            dataSourceProvider,
            info: ProviderInfo(
                type: .dataSource,
                name: "MacOSDataSourceProvider",
                version: "1.0.0",
                priority: 0
            )
        )
        
        // Decoder Provider
        let decoderProvider = MacOSDecoderProvider()
        _decoderProvider = decoderProvider
        registerProvider(
            decoderProvider,
            info: ProviderInfo(
                type: .decoder,
                name: "MacOSDecoderProvider",
                version: "1.0.0",
                priority: 0
            )
        )
        
        // Renderer Provider
        let rendererProvider = MacOSRendererProvider()
        _rendererProvider = rendererProvider
        registerProvider(
            rendererProvider,
            info: ProviderInfo(
                type: .renderer,
                name: "MacOSRendererProvider",
                version: "1.0.0",
                priority: 0
            )
        )
    }
    
    // MARK: - Public Methods
    
    /// 注册 Provider
    public func registerProvider(_ provider: AnyObject, info: ProviderInfo) {
        lock.lock()
        defer { lock.unlock() }
        
        if registeredProviders[info.type] == nil {
            registeredProviders[info.type] = []
        }
        registeredProviders[info.type]?.append(provider)
        providerInfoMap[ObjectIdentifier(provider)] = info
        
        // 按优先级排序
        registeredProviders[info.type]?.sort { lhs, rhs in
            let lhsPriority = providerInfoMap[ObjectIdentifier(lhs)]?.priority ?? 0
            let rhsPriority = providerInfoMap[ObjectIdentifier(rhs)]?.priority ?? 0
            return lhsPriority > rhsPriority
        }
    }
    
    /// 注销 Provider
    public func unregisterProvider(_ provider: AnyObject) {
        lock.lock()
        defer { lock.unlock() }
        
        guard let info = providerInfoMap.removeValue(forKey: ObjectIdentifier(provider)) else {
            return
        }
        
        registeredProviders[info.type]?.removeAll { $0 === provider }
    }
    
    /// 获取数据源 Provider
    public func getDataSourceProvider() -> MacOSDataSourceProvider {
        return getProvider(.dataSource) ?? _dataSourceProvider ?? MacOSDataSourceProvider()
    }
    
    /// 获取解码器 Provider
    public func getDecoderProvider() -> MacOSDecoderProvider {
        return getProvider(.decoder) ?? _decoderProvider ?? MacOSDecoderProvider()
    }
    
    /// 获取渲染器 Provider
    public func getRendererProvider() -> MacOSRendererProvider {
        return getProvider(.renderer) ?? _rendererProvider ?? MacOSRendererProvider()
    }
    
    /// 获取指定类型的 Provider（优先级最高的）
    private func getProvider<T: AnyObject>(_ type: ProviderType) -> T? {
        lock.lock()
        defer { lock.unlock() }
        
        return registeredProviders[type]?.first as? T
    }
    
    /// 获取指定类型的所有 Provider
    public func getProviders(_ type: ProviderType) -> [AnyObject] {
        lock.lock()
        defer { lock.unlock() }
        
        return registeredProviders[type] ?? []
    }
    
    /// 获取 Provider 信息
    public func getProviderInfo(_ provider: AnyObject) -> ProviderInfo? {
        lock.lock()
        defer { lock.unlock() }
        
        return providerInfoMap[ObjectIdentifier(provider)]
    }
    
    /// 获取所有已注册的 Provider 信息
    public func getAllProviderInfo() -> [ProviderInfo] {
        lock.lock()
        defer { lock.unlock() }
        
        return Array(providerInfoMap.values)
    }
    
    /// 重置为默认 Provider
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        
        registeredProviders.removeAll()
        providerInfoMap.removeAll()
        
        lock.unlock()
        registerDefaultProviders()
        lock.lock()
    }
}
