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
  s.source_files     = 'Classes/**/*.swift'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.14'
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES',
    'CLANG_ENABLE_MODULES' => 'YES',
    'SWIFT_OBJC_BRIDGING_HEADER' => '$(PODS_TARGET_SRCROOT)/Classes/BridgingHeader.h'
  }
  s.swift_version = '5.9'
  
  # Frameworks required for video playback
  s.frameworks = 'Metal', 'MetalKit', 'CoreVideo', 'VideoToolbox', 'AVFoundation', 'CoreMedia'
  
  # FFmpeg libraries (users need to provide these)
  # s.vendored_libraries = 'libs/libavcodec.dylib', 'libs/libavformat.dylib', 'libs/libavutil.dylib', 'libs/libswscale.dylib', 'libs/libswresample.dylib'
end
