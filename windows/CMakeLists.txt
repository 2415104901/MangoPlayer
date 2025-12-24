# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "mango_player")
project(${PROJECT_NAME} LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "mango_player_plugin")

# FFmpeg configuration
# Users must set FFMPEG_ROOT to their FFmpeg installation
if(DEFINED ENV{FFMPEG_ROOT})
  set(FFMPEG_ROOT $ENV{FFMPEG_ROOT})
else()
  set(FFMPEG_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/libs/ffmpeg")
endif()

# FFmpeg include and library paths
if(EXISTS "${FFMPEG_ROOT}/include")
  set(FFMPEG_INCLUDE_DIR "${FFMPEG_ROOT}/include")
  set(FFMPEG_LIB_DIR "${FFMPEG_ROOT}/lib")
  set(FFMPEG_BIN_DIR "${FFMPEG_ROOT}/bin")
  set(FFMPEG_AVAILABLE TRUE)
  message(STATUS "FFmpeg found at: ${FFMPEG_ROOT}")
else()
  set(FFMPEG_AVAILABLE FALSE)
  message(WARNING "FFmpeg not found. Set FFMPEG_ROOT environment variable or place FFmpeg in ${FFMPEG_ROOT}")
endif()

# Any new source files that you add to the plugin should be added here.
list(APPEND PLUGIN_SOURCES
  "mango_player_plugin.cpp"
  "mango_player_plugin.h"
  # Platform Channel handlers
  "src/platform/method_channel_handler.cpp"
  "src/platform/method_channel_handler.h"
  "src/platform/event_channel_handler.cpp"
  "src/platform/event_channel_handler.h"
  "src/platform/texture_registry_handler.cpp"
  "src/platform/texture_registry_handler.h"
  # Core player
  "src/core/ffmpeg_player_manager.cpp"
  "src/core/ffmpeg_player_manager.h"
  "src/core/dxva_decoder.cpp"
  "src/core/dxva_decoder.h"
  # Native core (shared with macOS)
  "src/core/native_core/ffmpeg_demuxer.cpp"
  "src/core/native_core/ffmpeg_demuxer.h"
  "src/core/native_core/ffmpeg_soft_decoder.cpp"
  "src/core/native_core/ffmpeg_soft_decoder.h"
  "src/core/native_core/clock_sync.cpp"
  "src/core/native_core/clock_sync.h"
  "src/core/native_core/core_event_bridge.cpp"
  "src/core/native_core/core_event_bridge.h"
  # Renderer
  "src/renderer/d3d11_texture_renderer.cpp"
  "src/renderer/d3d11_texture_renderer.h"
)

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  "include/mango_player/mango_player_plugin_c_api.h"
  "mango_player_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
apply_standard_settings(${PLUGIN_NAME})

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_include_directories(${PLUGIN_NAME} PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${CMAKE_CURRENT_SOURCE_DIR}/src")

# FFmpeg includes and libraries
if(FFMPEG_AVAILABLE)
  target_include_directories(${PLUGIN_NAME} PRIVATE "${FFMPEG_INCLUDE_DIR}")
  target_link_directories(${PLUGIN_NAME} PRIVATE "${FFMPEG_LIB_DIR}")
  target_link_libraries(${PLUGIN_NAME} PRIVATE
    avformat
    avcodec
    avutil
    swscale
    swresample
  )
endif()

# Windows system libraries
target_link_libraries(${PLUGIN_NAME} PRIVATE 
  flutter 
  flutter_wrapper_plugin
  d3d11
  dxva2
)

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
if(FFMPEG_AVAILABLE AND EXISTS "${FFMPEG_BIN_DIR}")
  file(GLOB FFMPEG_DLLS "${FFMPEG_BIN_DIR}/*.dll")
  set(mango_player_bundled_libraries
    ${FFMPEG_DLLS}
    PARENT_SCOPE
  )
else()
  set(mango_player_bundled_libraries
    ""
    PARENT_SCOPE
  )
endif()

# === Tests ===
# These unit tests can be run from a terminal after building the example, or
# from Visual Studio after opening the generated solution file.

# Only enable test builds when building the example (which sets this variable)
# so that plugin clients aren't building the tests.
if (${include_${PROJECT_NAME}_tests})
set(TEST_RUNNER "${PROJECT_NAME}_test")
enable_testing()

# Add the Google Test dependency.
include(FetchContent)
FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/archive/release-1.11.0.zip
)
# Prevent overriding the parent project's compiler/linker settings
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
# Disable install commands for gtest so it doesn't end up in the bundle.
set(INSTALL_GTEST OFF CACHE BOOL "Disable installation of googletest" FORCE)
FetchContent_MakeAvailable(googletest)

# The plugin's C API is not very useful for unit testing, so build the sources
# directly into the test binary rather than using the DLL.
add_executable(${TEST_RUNNER}
  test/mango_player_plugin_test.cpp
  ${PLUGIN_SOURCES}
)
apply_standard_settings(${TEST_RUNNER})
target_include_directories(${TEST_RUNNER} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(${TEST_RUNNER} PRIVATE flutter_wrapper_plugin)
target_link_libraries(${TEST_RUNNER} PRIVATE gtest_main gmock)
# flutter_wrapper_plugin has link dependencies on the Flutter DLL.
add_custom_command(TARGET ${TEST_RUNNER} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
  "${FLUTTER_LIBRARY}" $<TARGET_FILE_DIR:${TEST_RUNNER}>
)

# Enable automatic test discovery.
include(GoogleTest)
gtest_discover_tests(${TEST_RUNNER})
endif()
