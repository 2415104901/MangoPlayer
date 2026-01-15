#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint mango_player.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'mango_player'
  s.version          = '0.0.1'
  s.summary          = 'A cross-platform video player plugin for Flutter.'
  s.description      = <<-DESC
MangoPlayer is a cross-platform video player plugin for Flutter,
supporting Windows, macOS, iOS, and Android with consistent API.
Uses FFmpeg + VideoToolbox for hardware-accelerated decoding.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'MangoPlayer' => 'email@example.com' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*.{swift,h,m,mm}', 'Classes/**/*.{swift,h,m,mm}'
  s.exclude_files    = 'Classes/**/*.template'
  s.public_header_files = 'Classes/core/FFmpegDemuxerObjC.h', 'Classes/core/FFmpegAudioDecoderObjC.h', 'Classes/NativeCore/*.h'
  s.preserve_paths = 'Classes/BridgingHeader.h', 'Classes/FFmpegWrapper.h', 'Classes/core/FFmpegDemuxerObjC.h', 'Classes/core/FFmpegAudioDecoderObjC.h', 'Classes/NativeCore/*.h'
  s.dependency 'FlutterMacOS'
  
  # Link native_core static library
  s.vendored_libraries = '../native_core/build/libmango_player_native_core.a', '../native_core/build/libmango_player_c_bridge.a'

  s.platform = :osx, '10.14'
  s.swift_version = '5.9'

  # Frameworks required for video playback
  s.frameworks = 'Metal', 'MetalKit', 'CoreVideo', 'VideoToolbox', 'AVFoundation', 'CoreMedia'

  # FFmpeg configuration using system-installed libraries via Homebrew
  s.xcconfig = {
    'OTHER_CFLAGS' => '$(inherited) -I/opt/homebrew/Cellar/ffmpeg/8.0.1/include -I$(PODS_TARGET_SRCROOT)/../native_core/include',
    'OTHER_LDFLAGS' => '$(inherited) -L/opt/homebrew/Cellar/ffmpeg/8.0.1/lib -lavformat -lavcodec -lavutil -lswscale -lswresample',
    'HEADER_SEARCH_PATHS' => '$(inherited) $(PODS_TARGET_SRCROOT)/../native_core/include',
  }

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'CLANG_ENABLE_MODULES' => 'YES',
    'OTHER_CFLAGS' => '$(inherited) -I/opt/homebrew/Cellar/ffmpeg/8.0.1/include -I$(PODS_TARGET_SRCROOT)/../native_core/include -fmodules',
    'OTHER_LDFLAGS' => '$(inherited) -L/opt/homebrew/Cellar/ffmpeg/8.0.1/lib -lavformat -lavcodec -lavutil -lswscale -lswresample -Wl,-rpath,/opt/homebrew/Cellar/ffmpeg/8.0.1/lib',
    'HEADER_SEARCH_PATHS' => '$(inherited) $(PODS_TARGET_SRCROOT)/../native_core/include',
  }
end
