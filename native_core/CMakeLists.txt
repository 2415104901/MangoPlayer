# MangoPlayer Native Core - Cross-Platform C++ Library
# 跨平台 C++ 核心库，Windows/macOS 共享

cmake_minimum_required(VERSION 3.16)
project(mango_player_native_core VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# =============================================================================
# FFmpeg 依赖查找
# =============================================================================
if(APPLE)
    # macOS: 使用 Homebrew FFmpeg
    set(FFMPEG_ROOT "/opt/homebrew" CACHE PATH "FFmpeg installation root")
    set(FFMPEG_INCLUDE_DIRS "${FFMPEG_ROOT}/include")
    set(FFMPEG_LIBRARY_DIRS "${FFMPEG_ROOT}/lib")
elseif(WIN32)
    # Windows: 使用本地 FFmpeg 或 vcpkg
    find_package(PkgConfig QUIET)
    if(PkgConfig_FOUND)
        pkg_check_modules(FFMPEG REQUIRED libavformat libavcodec libavutil libswresample libswscale)
    else()
        set(FFMPEG_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../windows/libs/ffmpeg" CACHE PATH "FFmpeg installation root")
        set(FFMPEG_INCLUDE_DIRS "${FFMPEG_ROOT}/include")
        set(FFMPEG_LIBRARY_DIRS "${FFMPEG_ROOT}/lib")
    endif()
endif()

# =============================================================================
# 核心库源文件 - 100% 跨平台
# =============================================================================
set(NATIVE_CORE_SOURCES
    src/demuxer.cpp
    src/soft_decoder.cpp
    src/clock_sync.cpp
    src/event_bridge.cpp
    src/player_core.cpp
)

set(NATIVE_CORE_HEADERS
    include/mango_player/demuxer.h
    include/mango_player/soft_decoder.h
    include/mango_player/clock_sync.h
    include/mango_player/event_bridge.h
    include/mango_player/player_core.h
    include/mango_player/types.h
    include/mango_player/interfaces/hw_decoder.h
    include/mango_player/interfaces/texture_output.h
    include/mango_player/interfaces/audio_output.h
)

# =============================================================================
# 构建静态库
# =============================================================================
add_library(mango_player_native_core STATIC
    ${NATIVE_CORE_SOURCES}
    ${NATIVE_CORE_HEADERS}
)

target_include_directories(mango_player_native_core
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
    PRIVATE
        ${FFMPEG_INCLUDE_DIRS}
)

target_link_directories(mango_player_native_core
    PRIVATE
        ${FFMPEG_LIBRARY_DIRS}
)

# FFmpeg 库链接
if(APPLE)
    target_link_libraries(mango_player_native_core
        PRIVATE
            avformat avcodec avutil swresample swscale
    )
elseif(WIN32)
    target_link_libraries(mango_player_native_core
        PRIVATE
            avformat avcodec avutil swresample swscale
    )
endif()

# =============================================================================
# C 桥接层 (供 Swift/ObjC 调用)
# =============================================================================
set(C_BRIDGE_SOURCES
    src/c_bridge/mango_player_c.cpp
)

add_library(mango_player_c_bridge STATIC
    ${C_BRIDGE_SOURCES}
    include/mango_player/c_bridge/mango_player_c.h
)

target_link_libraries(mango_player_c_bridge
    PUBLIC mango_player_native_core
)

target_include_directories(mango_player_c_bridge
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
    PRIVATE
        ${FFMPEG_INCLUDE_DIRS}
)

# =============================================================================
# 安装规则
# =============================================================================
install(TARGETS mango_player_native_core mango_player_c_bridge
    ARCHIVE DESTINATION lib
    LIBRARY DESTINATION lib
)

install(DIRECTORY include/mango_player
    DESTINATION include
)

# =============================================================================
# 测试 (可选)
# =============================================================================
option(BUILD_TESTS "Build unit tests" OFF)
if(BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()
