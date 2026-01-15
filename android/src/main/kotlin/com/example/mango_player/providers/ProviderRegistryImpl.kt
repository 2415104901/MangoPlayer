package com.example.mango_player.providers

import android.content.Context

/**
 * Provider 注册表实现
 * 
 * 管理和注册各种 Provider（DataSource、Decoder、Renderer），
 * 支持运行时替换和扩展。
 */
class ProviderRegistryImpl private constructor(private val context: Context) {
    
    companion object {
        private const val TAG = "ProviderRegistryImpl"
        
        @Volatile
        private var instance: ProviderRegistryImpl? = null
        
        fun getInstance(context: Context): ProviderRegistryImpl {
            return instance ?: synchronized(this) {
                instance ?: ProviderRegistryImpl(context.applicationContext).also {
                    instance = it
                }
            }
        }
    }
    
    /**
     * Provider 类型
     */
    enum class ProviderType {
        DATA_SOURCE,
        DECODER,
        RENDERER
    }
    
    /**
     * Provider 信息
     */
    data class ProviderInfo(
        val type: ProviderType,
        val name: String,
        val version: String,
        val priority: Int = 0
    )
    
    // 默认 Provider
    private val defaultDataSourceProvider: AndroidDataSourceProvider by lazy {
        AndroidDataSourceProvider(context)
    }
    
    private val defaultDecoderProvider: AndroidDecoderProvider by lazy {
        AndroidDecoderProvider(context)
    }
    
    private val defaultRendererProvider: AndroidRendererProvider by lazy {
        AndroidRendererProvider()
    }
    
    // 已注册的 Provider
    private val registeredProviders = mutableMapOf<ProviderType, MutableList<Any>>()
    
    // Provider 信息
    private val providerInfoMap = mutableMapOf<Any, ProviderInfo>()
    
    init {
        // 注册默认 Provider
        registerDefaultProviders()
    }
    
    private fun registerDefaultProviders() {
        registerProvider(
            defaultDataSourceProvider,
            ProviderInfo(
                type = ProviderType.DATA_SOURCE,
                name = "AndroidDataSourceProvider",
                version = "1.0.0",
                priority = 0
            )
        )
        
        registerProvider(
            defaultDecoderProvider,
            ProviderInfo(
                type = ProviderType.DECODER,
                name = "AndroidDecoderProvider",
                version = "1.0.0",
                priority = 0
            )
        )
        
        registerProvider(
            defaultRendererProvider,
            ProviderInfo(
                type = ProviderType.RENDERER,
                name = "AndroidRendererProvider",
                version = "1.0.0",
                priority = 0
            )
        )
    }
    
    /**
     * 注册 Provider
     * 
     * @param provider Provider 实例
     * @param info Provider 信息
     */
    fun registerProvider(provider: Any, info: ProviderInfo) {
        val providers = registeredProviders.getOrPut(info.type) { mutableListOf() }
        providers.add(provider)
        providerInfoMap[provider] = info
        
        // 按优先级排序
        providers.sortByDescending { providerInfoMap[it]?.priority ?: 0 }
    }
    
    /**
     * 注销 Provider
     */
    fun unregisterProvider(provider: Any) {
        val info = providerInfoMap.remove(provider) ?: return
        registeredProviders[info.type]?.remove(provider)
    }
    
    /**
     * 获取数据源 Provider
     */
    fun getDataSourceProvider(): AndroidDataSourceProvider {
        return getProvider(ProviderType.DATA_SOURCE) ?: defaultDataSourceProvider
    }
    
    /**
     * 获取解码器 Provider
     */
    fun getDecoderProvider(): AndroidDecoderProvider {
        return getProvider(ProviderType.DECODER) ?: defaultDecoderProvider
    }
    
    /**
     * 获取渲染器 Provider
     */
    fun getRendererProvider(): AndroidRendererProvider {
        return getProvider(ProviderType.RENDERER) ?: defaultRendererProvider
    }
    
    /**
     * 获取指定类型的 Provider（优先级最高的）
     */
    @Suppress("UNCHECKED_CAST")
    private fun <T> getProvider(type: ProviderType): T? {
        return registeredProviders[type]?.firstOrNull() as? T
    }
    
    /**
     * 获取指定类型的所有 Provider
     */
    fun getProviders(type: ProviderType): List<Any> {
        return registeredProviders[type]?.toList() ?: emptyList()
    }
    
    /**
     * 获取 Provider 信息
     */
    fun getProviderInfo(provider: Any): ProviderInfo? {
        return providerInfoMap[provider]
    }
    
    /**
     * 获取所有已注册的 Provider 信息
     */
    fun getAllProviderInfo(): List<ProviderInfo> {
        return providerInfoMap.values.toList()
    }
    
    /**
     * 重置为默认 Provider
     */
    fun reset() {
        registeredProviders.clear()
        providerInfoMap.clear()
        registerDefaultProviders()
    }
}
