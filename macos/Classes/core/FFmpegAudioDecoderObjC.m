//
//  FFmpegAudioDecoderObjC.m
//  MangoPlayer
//
//  FFmpeg audio decoder implementation using libavcodec + libswresample
//

#import "FFmpegAudioDecoderObjC.h"
#import <libavcodec/avcodec.h>
#import <libavutil/opt.h>
#import <libavutil/channel_layout.h>
#import <libswresample/swresample.h>

@interface FFmpegAudioDecoderObjC () {
    AVCodecContext *_codecContext;
    SwrContext *_swrContext;
    AVFrame *_decodedFrame;
    AVPacket *_packet;
    
    // Output buffer
    uint8_t *_outputBuffer;
    int _outputBufferSize;
    
    // Callback
    FFmpegAudioFrameCallback _callback;
    
    // Configuration
    int _inputSampleRate;
    int _inputChannels;
    int32_t _codecId;
}
@end

@implementation FFmpegAudioDecoderObjC

- (instancetype)init {
    self = [super init];
    if (self) {
        _codecContext = NULL;
        _swrContext = NULL;
        _decodedFrame = NULL;
        _packet = NULL;
        _outputBuffer = NULL;
        _outputBufferSize = 0;
        _isConfigured = NO;
        
        // Fixed output format for AVAudioEngine
        _outputSampleRate = 44100;
        _outputChannels = 2;
        _outputBytesPerSample = 4; // Float32
    }
    return self;
}

- (void)dealloc {
    [self close];
}

- (BOOL)configureWithCodecId:(int32_t)codecId
                  sampleRate:(int)sampleRate
                    channels:(int)channels
                   extradata:(nullable NSData *)extradata {
    // Clean up any existing decoder
    [self close];
    
    _codecId = codecId;
    _inputSampleRate = sampleRate;
    _inputChannels = channels;
    
    // Find decoder
    const AVCodec *codec = avcodec_find_decoder((enum AVCodecID)codecId);
    if (!codec) {
        NSLog(@"[FFmpegAudioDecoder] ❌ Codec not found for ID: %d", codecId);
        return NO;
    }
    
    NSLog(@"[FFmpegAudioDecoder] 🔊 Found codec: %s", codec->name);
    
    // Allocate codec context
    _codecContext = avcodec_alloc_context3(codec);
    if (!_codecContext) {
        NSLog(@"[FFmpegAudioDecoder] ❌ Failed to allocate codec context");
        return NO;
    }
    
    // Set codec parameters
    _codecContext->sample_rate = sampleRate;
    
    // Set channel layout for FFmpeg 5.0+
    AVChannelLayout layout;
    if (channels == 1) {
        layout = (AVChannelLayout)AV_CHANNEL_LAYOUT_MONO;
    } else {
        layout = (AVChannelLayout)AV_CHANNEL_LAYOUT_STEREO;
    }
    av_channel_layout_copy(&_codecContext->ch_layout, &layout);
    
    // Set extradata if provided (e.g., AAC AudioSpecificConfig)
    if (extradata && extradata.length > 0) {
        _codecContext->extradata = av_mallocz(extradata.length + AV_INPUT_BUFFER_PADDING_SIZE);
        if (_codecContext->extradata) {
            memcpy(_codecContext->extradata, extradata.bytes, extradata.length);
            _codecContext->extradata_size = (int)extradata.length;
            NSLog(@"[FFmpegAudioDecoder] 📦 Set extradata: %d bytes", _codecContext->extradata_size);
        }
    }
    
    // Open codec
    int ret = avcodec_open2(_codecContext, codec, NULL);
    if (ret < 0) {
        char errBuf[256];
        av_strerror(ret, errBuf, sizeof(errBuf));
        NSLog(@"[FFmpegAudioDecoder] ❌ Failed to open codec: %s", errBuf);
        avcodec_free_context(&_codecContext);
        return NO;
    }
    
    // Allocate frame for decoded audio
    _decodedFrame = av_frame_alloc();
    if (!_decodedFrame) {
        NSLog(@"[FFmpegAudioDecoder] ❌ Failed to allocate frame");
        avcodec_free_context(&_codecContext);
        return NO;
    }
    
    // Allocate packet
    _packet = av_packet_alloc();
    if (!_packet) {
        NSLog(@"[FFmpegAudioDecoder] ❌ Failed to allocate packet");
        av_frame_free(&_decodedFrame);
        avcodec_free_context(&_codecContext);
        return NO;
    }
    
    // Create resampler (input format -> Float32 stereo 44100Hz)
    _swrContext = swr_alloc();
    if (!_swrContext) {
        NSLog(@"[FFmpegAudioDecoder] ❌ Failed to allocate SwrContext");
        av_packet_free(&_packet);
        av_frame_free(&_decodedFrame);
        avcodec_free_context(&_codecContext);
        return NO;
    }
    
    // Set resampler options
    AVChannelLayout outLayout = (AVChannelLayout)AV_CHANNEL_LAYOUT_STEREO;
    av_opt_set_chlayout(_swrContext, "in_chlayout", &layout, 0);
    av_opt_set_chlayout(_swrContext, "out_chlayout", &outLayout, 0);
    av_opt_set_int(_swrContext, "in_sample_rate", sampleRate, 0);
    av_opt_set_int(_swrContext, "out_sample_rate", _outputSampleRate, 0);
    av_opt_set_sample_fmt(_swrContext, "in_sample_fmt", AV_SAMPLE_FMT_FLTP, 0);  // Most codecs output planar float
    av_opt_set_sample_fmt(_swrContext, "out_sample_fmt", AV_SAMPLE_FMT_FLT, 0);  // Interleaved float for AVAudioEngine
    
    ret = swr_init(_swrContext);
    if (ret < 0) {
        char errBuf[256];
        av_strerror(ret, errBuf, sizeof(errBuf));
        NSLog(@"[FFmpegAudioDecoder] ❌ Failed to init resampler: %s", errBuf);
        swr_free(&_swrContext);
        av_packet_free(&_packet);
        av_frame_free(&_decodedFrame);
        avcodec_free_context(&_codecContext);
        return NO;
    }
    
    // Allocate output buffer (enough for 1 second of audio)
    _outputBufferSize = _outputSampleRate * _outputChannels * _outputBytesPerSample;
    _outputBuffer = (uint8_t *)av_malloc(_outputBufferSize);
    
    _isConfigured = YES;
    NSLog(@"[FFmpegAudioDecoder] ✅ Configured: %s, %dHz %dch -> Float32 %dHz stereo",
          codec->name, sampleRate, channels, _outputSampleRate);
    
    return YES;
}

- (void)setAudioFrameCallback:(nullable FFmpegAudioFrameCallback)callback {
    _callback = callback;
}

- (BOOL)decodePacketWithData:(NSData *)data
                         pts:(int64_t)pts
                         dts:(int64_t)dts
                    duration:(int64_t)duration {
    if (!_isConfigured || !_codecContext || !_packet || !_decodedFrame) {
        return NO;
    }
    
    // Fill packet
    av_packet_unref(_packet);
    _packet->data = (uint8_t *)data.bytes;
    _packet->size = (int)data.length;
    _packet->pts = pts;
    _packet->dts = dts;
    _packet->duration = duration;
    
    // Send packet to decoder
    int ret = avcodec_send_packet(_codecContext, _packet);
    if (ret < 0) {
        if (ret != AVERROR(EAGAIN) && ret != AVERROR_EOF) {
            char errBuf[256];
            av_strerror(ret, errBuf, sizeof(errBuf));
            NSLog(@"[FFmpegAudioDecoder] ⚠️ Send packet error: %s", errBuf);
        }
        return NO;
    }
    
    // Receive decoded frames
    while (ret >= 0) {
        ret = avcodec_receive_frame(_codecContext, _decodedFrame);
        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
            break;
        } else if (ret < 0) {
            char errBuf[256];
            av_strerror(ret, errBuf, sizeof(errBuf));
            NSLog(@"[FFmpegAudioDecoder] ⚠️ Receive frame error: %s", errBuf);
            break;
        }
        
        // Lazy init SwrContext with actual input format
        if (!swr_is_initialized(_swrContext)) {
            // Update input format based on decoded frame
            av_opt_set_chlayout(_swrContext, "in_chlayout", &_decodedFrame->ch_layout, 0);
            av_opt_set_int(_swrContext, "in_sample_rate", _decodedFrame->sample_rate, 0);
            av_opt_set_sample_fmt(_swrContext, "in_sample_fmt", (enum AVSampleFormat)_decodedFrame->format, 0);
            
            int initRet = swr_init(_swrContext);
            if (initRet < 0) {
                char errBuf[256];
                av_strerror(initRet, errBuf, sizeof(errBuf));
                NSLog(@"[FFmpegAudioDecoder] ❌ Resampler reinit failed: %s", errBuf);
                av_frame_unref(_decodedFrame);
                continue;
            }
            NSLog(@"[FFmpegAudioDecoder] 🔄 Resampler reinitialized for format: %d, rate: %d",
                  _decodedFrame->format, _decodedFrame->sample_rate);
        }
        
        // Calculate output sample count
        int outSamples = (int)av_rescale_rnd(_decodedFrame->nb_samples,
                                              _outputSampleRate,
                                              _decodedFrame->sample_rate,
                                              AV_ROUND_UP);
        
        // Ensure buffer is large enough
        int requiredSize = outSamples * _outputChannels * _outputBytesPerSample;
        if (requiredSize > _outputBufferSize) {
            av_free(_outputBuffer);
            _outputBufferSize = requiredSize * 2;
            _outputBuffer = (uint8_t *)av_malloc(_outputBufferSize);
        }
        
        // Resample
        uint8_t *outPtr = _outputBuffer;
        int convertedSamples = swr_convert(_swrContext,
                                           &outPtr, outSamples,
                                           (const uint8_t **)_decodedFrame->extended_data,
                                           _decodedFrame->nb_samples);
        
        if (convertedSamples > 0 && _callback) {
            int dataSize = convertedSamples * _outputChannels * _outputBytesPerSample;
            NSData *pcmData = [NSData dataWithBytes:_outputBuffer length:dataSize];
            
            // Calculate actual PTS for this frame
            int64_t framePts = _decodedFrame->pts;
            if (framePts == AV_NOPTS_VALUE) {
                framePts = pts;
            }
            
            _callback(pcmData, framePts, convertedSamples);
        }
        
        av_frame_unref(_decodedFrame);
    }
    
    return YES;
}

- (void)flush {
    if (_codecContext) {
        avcodec_flush_buffers(_codecContext);
    }
    NSLog(@"[FFmpegAudioDecoder] 🔄 Flushed");
}

- (void)close {
    if (_outputBuffer) {
        av_free(_outputBuffer);
        _outputBuffer = NULL;
    }
    
    if (_swrContext) {
        swr_free(&_swrContext);
        _swrContext = NULL;
    }
    
    if (_packet) {
        av_packet_free(&_packet);
        _packet = NULL;
    }
    
    if (_decodedFrame) {
        av_frame_free(&_decodedFrame);
        _decodedFrame = NULL;
    }
    
    if (_codecContext) {
        avcodec_free_context(&_codecContext);
        _codecContext = NULL;
    }
    
    _isConfigured = NO;
    _callback = nil;
    NSLog(@"[FFmpegAudioDecoder] 🔒 Closed");
}

@end
