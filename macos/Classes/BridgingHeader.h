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

#endif /* MangoPlayer_BridgingHeader_h */
