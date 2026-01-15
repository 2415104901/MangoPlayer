//
//  FFmpegDemuxerObjC.h
//  MangoPlayer
//
//  Objective-C wrapper for FFmpeg C API demuxer
//  Provides Swift-safe interface for libavformat
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Stream information returned to Swift
@interface FFmpegStreamInfo : NSObject
@property (nonatomic, assign) int64_t duration;      // Duration in milliseconds
@property (nonatomic, assign) int videoStreamIndex;
@property (nonatomic, assign) int audioStreamIndex;
@property (nonatomic, assign) int videoWidth;
@property (nonatomic, assign) int videoHeight;
@property (nonatomic, assign) double videoFrameRate;
@property (nonatomic, assign) int32_t videoCodecId;
@property (nonatomic, strong) NSString *videoCodecName;
@property (nonatomic, strong, nullable) NSData *videoExtradata;  // SPS/PPS for H.264/HEVC
@property (nonatomic, assign) int32_t audioCodecId;
@property (nonatomic, strong) NSString *audioCodecName;
@property (nonatomic, assign) int audioChannels;
@property (nonatomic, assign) int audioSampleRate;
@end

/// Packet data returned to Swift
@interface FFmpegPacketData : NSObject
@property (nonatomic, assign) int streamIndex;
@property (nonatomic, assign) int64_t pts;
@property (nonatomic, assign) int64_t dts;
@property (nonatomic, assign) int64_t duration;
@property (nonatomic, assign) BOOL isKeyframe;
@property (nonatomic, assign) BOOL isVideo;
@property (nonatomic, assign) BOOL isAudio;
@property (nonatomic, strong) NSData *data;
@end

/// FFmpeg Demuxer Objective-C Wrapper
/// Wraps libavformat C API for Swift compatibility
@interface FFmpegDemuxerObjC : NSObject

/// Open media file and initialize demuxer
/// @param uri File path or URL
/// @param headers Optional HTTP headers (for network streams)
/// @return YES if successful, NO if failed
- (BOOL)openWithURI:(NSString *)uri 
            headers:(nullable NSDictionary<NSString *, NSString *> *)headers;

/// Get stream information (duration, codec, etc.)
/// @return Stream info object, or nil if not opened
- (nullable FFmpegStreamInfo *)getStreamInfo;

/// Read next packet from demuxer
/// @return Packet data, or nil if EOF or error
- (nullable FFmpegPacketData *)readPacket;

/// Seek to specific timestamp
/// @param timestampMs Timestamp in milliseconds
/// @return YES if successful, NO if failed
- (BOOL)seekToTimestamp:(int64_t)timestampMs;

/// Close demuxer and release resources
- (void)close;

/// Check if demuxer is opened
@property (nonatomic, assign, readonly) BOOL isOpened;

@end

NS_ASSUME_NONNULL_END
