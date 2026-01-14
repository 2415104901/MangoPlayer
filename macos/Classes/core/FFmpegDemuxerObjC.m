//
//  FFmpegDemuxerObjC.m
//  MangoPlayer
//
//  Objective-C implementation of FFmpeg demuxer wrapper
//

#import "FFmpegDemuxerObjC.h"
#import <libavformat/avformat.h>
#import <libavcodec/avcodec.h>
#import <libavutil/avutil.h>

// Error domain
static NSString *const FFmpegDemuxerErrorDomain = @"com.mangoplayer.ffmpeg.demuxer";

// MARK: - FFmpegStreamInfo Implementation

@implementation FFmpegStreamInfo
@end

// MARK: - FFmpegPacketData Implementation

@implementation FFmpegPacketData
@end

// MARK: - FFmpegDemuxerObjC Implementation

@interface FFmpegDemuxerObjC()
@property (nonatomic, assign) AVFormatContext *formatContext;
@property (nonatomic, assign) BOOL isOpened;
@end

@implementation FFmpegDemuxerObjC

- (instancetype)init {
    self = [super init];
    if (self) {
        _formatContext = NULL;
        _isOpened = NO;
    }
    return self;
}

- (void)dealloc {
    [self close];
}

- (BOOL)openWithURI:(NSString *)uri 
            headers:(NSDictionary<NSString *, NSString *> *)headers {
    NSLog(@"[FFmpegDemuxerObjC] Opening URI: %@", uri);
    
    if (_isOpened) {
        NSLog(@"[FFmpegDemuxerObjC] Already opened, closing first");
        [self close];
    }
    
    // Convert NSString to C string
    const char *url = [uri UTF8String];
    
    // Allocate format context
    AVFormatContext *ctx = NULL;
    
    // Open input file
    int ret = avformat_open_input(&ctx, url, NULL, NULL);
    if (ret < 0) {
        char errBuf[256];
        av_strerror(ret, errBuf, sizeof(errBuf));
        NSLog(@"[FFmpegDemuxerObjC] ❌ avformat_open_input failed: %s (code: %d)", errBuf, ret);
        return NO;
    }
    
    _formatContext = ctx;
    NSLog(@"[FFmpegDemuxerObjC] ✅ Format context opened");
    
    // Find stream info
    ret = avformat_find_stream_info(_formatContext, NULL);
    if (ret < 0) {
        char errBuf[256];
        av_strerror(ret, errBuf, sizeof(errBuf));
        NSLog(@"[FFmpegDemuxerObjC] ❌ avformat_find_stream_info failed: %s", errBuf);
        avformat_close_input(&_formatContext);
        return NO;
    }
    
    NSLog(@"[FFmpegDemuxerObjC] ✅ Stream info found");
    _isOpened = YES;
    
    return YES;
}

- (FFmpegStreamInfo *)getStreamInfo {
    if (!_isOpened || !_formatContext) {
        NSLog(@"[FFmpegDemuxerObjC] ⚠️ Demuxer not opened");
        return nil;
    }
    
    FFmpegStreamInfo *info = [[FFmpegStreamInfo alloc] init];
    
    // Extract duration
    if (_formatContext->duration != AV_NOPTS_VALUE) {
        // Convert from AV_TIME_BASE units to milliseconds
        info.duration = (int64_t)(_formatContext->duration) * 1000 / AV_TIME_BASE;
        NSLog(@"[FFmpegDemuxerObjC] ⏱️ Duration: %lld ms (%.2f s)", info.duration, (double)info.duration / 1000.0);
    } else {
        NSLog(@"[FFmpegDemuxerObjC] ⚠️ Duration is AV_NOPTS_VALUE, trying to estimate from streams");
        int64_t maxDuration = 0;
        for (unsigned int i = 0; i < _formatContext->nb_streams; i++) {
            AVStream *st = _formatContext->streams[i];
            if (st->duration != AV_NOPTS_VALUE) {
                int64_t dur = av_rescale_q(st->duration, st->time_base, (AVRational){1, 1000});
                if (dur > maxDuration) maxDuration = dur;
            }
        }
        info.duration = maxDuration;
        NSLog(@"[FFmpegDemuxerObjC] ⏱️ Estimated Duration: %lld ms", info.duration);
    }
    
    // Initialize stream indices
    info.videoStreamIndex = -1;
    info.audioStreamIndex = -1;
    
    // Find video and audio streams
    unsigned int nbStreams = _formatContext->nb_streams;
    NSLog(@"[FFmpegDemuxerObjC] 📺 Found %u streams", nbStreams);
    
    for (unsigned int i = 0; i < nbStreams; i++) {
        AVStream *stream = _formatContext->streams[i];
        AVCodecParameters *codecpar = stream->codecpar;
        
        if (codecpar->codec_type == AVMEDIA_TYPE_VIDEO && info.videoStreamIndex == -1) {
            info.videoStreamIndex = i;
            info.videoWidth = codecpar->width;
            info.videoHeight = codecpar->height;
            info.videoCodecId = codecpar->codec_id;
            
            // Get codec name
            const AVCodec *codec = avcodec_find_decoder(codecpar->codec_id);
            if (codec) {
                info.videoCodecName = [NSString stringWithUTF8String:codec->name];
            } else {
                info.videoCodecName = @"unknown";
            }
            
            // Calculate frame rate
            AVRational frameRate = stream->avg_frame_rate;
            if (frameRate.den > 0) {
                info.videoFrameRate = (double)frameRate.num / (double)frameRate.den;
            } else {
                info.videoFrameRate = 30.0; // Default
            }
            
            // Extract extradata (SPS/PPS for H.264/HEVC)
            if (codecpar->extradata && codecpar->extradata_size > 0) {
                info.videoExtradata = [NSData dataWithBytes:codecpar->extradata length:codecpar->extradata_size];
                NSLog(@"[FFmpegDemuxerObjC] 📦 Extracted extradata: %d bytes", codecpar->extradata_size);
            }
            
            NSLog(@"[FFmpegDemuxerObjC] 🎥 Video stream %d: %dx%d, %.2f fps, codec: %@",
                  i, info.videoWidth, info.videoHeight, info.videoFrameRate, info.videoCodecName);
        }
        else if (codecpar->codec_type == AVMEDIA_TYPE_AUDIO && info.audioStreamIndex == -1) {
            info.audioStreamIndex = i;
            info.audioCodecId = codecpar->codec_id;
            info.audioChannels = codecpar->ch_layout.nb_channels;
            info.audioSampleRate = codecpar->sample_rate;
            
            // Get codec name
            const AVCodec *codec = avcodec_find_decoder(codecpar->codec_id);
            if (codec) {
                info.audioCodecName = [NSString stringWithUTF8String:codec->name];
            } else {
                info.audioCodecName = @"unknown";
            }
            
            NSLog(@"[FFmpegDemuxerObjC] 🔊 Audio stream %d: %d Hz, %d channels, codec: %@",
                  i, info.audioSampleRate, info.audioChannels, info.audioCodecName);
        }
    }
    
    return info;
}

- (FFmpegPacketData *)readPacket {
    if (!_isOpened || !_formatContext) {
        NSLog(@"[FFmpegDemuxerObjC] ⚠️ Demuxer not opened");
        return nil;
    }
    
    AVPacket *packet = av_packet_alloc();
    if (!packet) {
        NSLog(@"[FFmpegDemuxerObjC] ❌ Failed to allocate packet");
        return nil;
    }
    
    int ret = av_read_frame(_formatContext, packet);
    if (ret < 0) {
        av_packet_free(&packet);
        
        // EOF is not an error
        if (ret == AVERROR_EOF) {
            return nil;
        }
        
        // Other errors
        char errBuf[256];
        av_strerror(ret, errBuf, sizeof(errBuf));
        NSLog(@"[FFmpegDemuxerObjC] ❌ av_read_frame failed: %s", errBuf);
        return nil;
    }
    
    // Create packet data
    FFmpegPacketData *packetData = [[FFmpegPacketData alloc] init];
    packetData.streamIndex = packet->stream_index;
    
    AVStream *stream = _formatContext->streams[packet->stream_index];
    
    // Convert PTS/DTS/Duration from stream timebase to milliseconds
    AVRational timebase = stream->time_base;
    
    int64_t pts = packet->pts;
    int64_t dts = packet->dts;

    // Is missing PTS, use DTS if available
    if (pts == AV_NOPTS_VALUE) {
        pts = dts;
    }

    if (pts != AV_NOPTS_VALUE) {
        packetData.pts = av_rescale_q(pts, timebase, (AVRational){1, 1000});
    } else {
        packetData.pts = 0;
    }
    
    if (dts != AV_NOPTS_VALUE) {
        packetData.dts = av_rescale_q(dts, timebase, (AVRational){1, 1000});
    } else {
        packetData.dts = packetData.pts;
    }
    packetData.duration = av_rescale_q(packet->duration, timebase, (AVRational){1, 1000});
    packetData.isKeyframe = (packet->flags & AV_PKT_FLAG_KEY) != 0;
    
    packetData.isVideo = (stream->codecpar->codec_type == AVMEDIA_TYPE_VIDEO);
    packetData.isAudio = (stream->codecpar->codec_type == AVMEDIA_TYPE_AUDIO);
    
    // Copy packet data
    packetData.data = [NSData dataWithBytes:packet->data length:packet->size];
    
    av_packet_free(&packet);
    
    return packetData;
}

- (BOOL)seekToTimestamp:(int64_t)timestampMs {
    if (!_isOpened || !_formatContext) {
        NSLog(@"[FFmpegDemuxerObjC] ⚠️ Demuxer not opened");
        return NO;
    }
    
    // Convert milliseconds to AV_TIME_BASE units
    int64_t timestamp = timestampMs * AV_TIME_BASE / 1000;
    
    int ret = av_seek_frame(_formatContext, -1, timestamp, AVSEEK_FLAG_BACKWARD);
    if (ret < 0) {
        char errBuf[256];
        av_strerror(ret, errBuf, sizeof(errBuf));
        NSLog(@"[FFmpegDemuxerObjC] ❌ av_seek_frame failed: %s", errBuf);
        return NO;
    }
    
    NSLog(@"[FFmpegDemuxerObjC] ✅ Seeked to %lld ms", timestampMs);
    return YES;
}

- (void)close {
    if (_formatContext) {
        NSLog(@"[FFmpegDemuxerObjC] 🔒 Closing format context");
        avformat_close_input(&_formatContext);
        _formatContext = NULL;
    }
    _isOpened = NO;
}

@end
