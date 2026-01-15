//
//  FFmpegAudioDecoderObjC.h
//  MangoPlayer
//
//  Objective-C wrapper for FFmpeg audio decoder
//  Decodes compressed audio packets (AAC, MP3, etc.) to PCM data
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Audio frame callback - called for each decoded audio frame
typedef void (^FFmpegAudioFrameCallback)(NSData *pcmData, int64_t pts, int sampleCount);

/// FFmpeg Audio Decoder Objective-C Wrapper
/// Uses libavcodec for software audio decoding with libswresample for format conversion
@interface FFmpegAudioDecoderObjC : NSObject

/// Configure the audio decoder
/// @param codecId FFmpeg codec ID (e.g., AV_CODEC_ID_AAC = 86018)
/// @param sampleRate Input sample rate
/// @param channels Input channel count
/// @param extradata Codec-specific extradata (e.g., AAC AudioSpecificConfig)
/// @return YES if successful
- (BOOL)configureWithCodecId:(int32_t)codecId
                  sampleRate:(int)sampleRate
                    channels:(int)channels
                   extradata:(nullable NSData *)extradata;

/// Set callback for decoded audio frames
/// @param callback Block called with decoded PCM data
- (void)setAudioFrameCallback:(nullable FFmpegAudioFrameCallback)callback;

/// Decode an audio packet
/// @param data Compressed audio data
/// @param pts Presentation timestamp in milliseconds
/// @param dts Decode timestamp in milliseconds
/// @param duration Packet duration in milliseconds
/// @return YES if decoding succeeded
- (BOOL)decodePacketWithData:(NSData *)data
                         pts:(int64_t)pts
                         dts:(int64_t)dts
                    duration:(int64_t)duration;

/// Flush decoder buffers (call after seek)
- (void)flush;

/// Close decoder and release resources
- (void)close;

/// Output format info (fixed for AVAudioEngine compatibility)
@property (nonatomic, readonly) int outputSampleRate;     // Always 44100 or 48000
@property (nonatomic, readonly) int outputChannels;       // Always 2 (stereo)
@property (nonatomic, readonly) int outputBytesPerSample; // Always 4 (Float32)

/// State
@property (nonatomic, readonly) BOOL isConfigured;

@end

NS_ASSUME_NONNULL_END
