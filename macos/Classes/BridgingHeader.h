#ifndef MangoPlayer_BridgingHeader_h
#define MangoPlayer_BridgingHeader_h

@import Foundation;
@import AVFoundation;
@import CoreVideo;
@import VideoToolbox;
@import Metal;
@import MetalKit;

// FFmpeg C API (for Objective-C wrappers)
#import <libavformat/avformat.h>
#import <libavcodec/avcodec.h>
#import <libavutil/avutil.h>
#import <libavutil/imgutils.h>
#import <libavutil/frame.h>
#import <libavutil/pixfmt.h>
#import <libswscale/swscale.h>
#import <libswresample/swresample.h>

// FFmpeg Objective-C Wrappers (safe for Swift)
#import "core/FFmpegDemuxerObjC.h"
#import "core/FFmpegAudioDecoderObjC.h"

// Native Core C Bridge
#import "mango_player/c_bridge/mango_player_c.h"

// Native Core Platform Implementations
#import "NativeCore/VideoToolboxDecoder.h"
#import "NativeCore/MetalTextureOutput.h"
#import "NativeCore/AVAudioEngineOutput.h"

#endif /* MangoPlayer_BridgingHeader_h */
