/**
 * AVAudioEngineOutput Implementation
 */

#include "AVAudioEngineOutput.h"
#import <AVFoundation/AVFoundation.h>

namespace mango_player {

AVAudioEngineOutputImpl::AVAudioEngineOutputImpl()
    : audio_engine_(nil)
    , player_node_(nil)
    , audio_format_(nil)
    , volume_(1.0f)
    , is_muted_(false)
    , is_playing_(false)
    , sample_rate_(0)
    , channels_(0)
    , total_samples_played_(0)
    , is_initialized_(false) {
}

AVAudioEngineOutputImpl::~AVAudioEngineOutputImpl() {
    Release();
}

bool AVAudioEngineOutputImpl::Initialize(int sample_rate, int channels, int bits_per_sample) {
    sample_rate_ = sample_rate;
    channels_ = channels;

    audio_engine_ = [[AVAudioEngine alloc] init];
    player_node_ = [[AVAudioPlayerNode alloc] init];

    [audio_engine_ attachNode:player_node_];

    audio_format_ = [[AVAudioFormat alloc] 
        initStandardFormatWithSampleRate:sample_rate
        channels:channels];

    if (!audio_format_) {
        NSLog(@"Failed to create audio format");
        return false;
    }

    [audio_engine_ connect:player_node_ 
                        to:audio_engine_.mainMixerNode 
                    format:audio_format_];

    NSError* error = nil;
    if (![audio_engine_ startAndReturnError:&error]) {
        NSLog(@"Failed to start audio engine: %@", error);
        return false;
    }

    is_initialized_ = true;
    return true;
}

int AVAudioEngineOutputImpl::Write(const uint8_t* data, int size, int64_t pts_ms) {
    if (!is_initialized_ || !player_node_ || !audio_format_) {
        return -1;
    }

    // Calculate frame count
    int bytes_per_frame = channels_ * sizeof(float);
    int frame_count = size / bytes_per_frame;

    if (frame_count <= 0) {
        return 0;
    }

    AVAudioPCMBuffer* buffer = [[AVAudioPCMBuffer alloc] 
        initWithPCMFormat:audio_format_
        frameCapacity:frame_count];

    if (!buffer) {
        return -1;
    }

    buffer.frameLength = frame_count;

    // Copy audio data
    float* channelData = buffer.floatChannelData[0];
    const float* sourceData = (const float*)data;
    
    for (int i = 0; i < frame_count * channels_; i++) {
        channelData[i] = sourceData[i];
    }

    // Apply volume and mute
    if (is_muted_ || volume_ < 1.0f) {
        float actualVolume = is_muted_ ? 0.0f : volume_;
        for (int i = 0; i < frame_count * channels_; i++) {
            channelData[i] *= actualVolume;
        }
    }

    [player_node_ scheduleBuffer:buffer 
                completionHandler:nil];

    total_samples_played_ += frame_count;

    return size;
}

void AVAudioEngineOutputImpl::Start() {
    if (player_node_ && !is_playing_) {
        [player_node_ play];
        is_playing_ = true;
    }
}

void AVAudioEngineOutputImpl::Pause() {
    if (player_node_ && is_playing_) {
        [player_node_ pause];
        is_playing_ = false;
    }
}

void AVAudioEngineOutputImpl::Resume() {
    Start();
}

void AVAudioEngineOutputImpl::Stop() {
    if (player_node_) {
        [player_node_ stop];
        is_playing_ = false;
        total_samples_played_ = 0;
    }
}

void AVAudioEngineOutputImpl::Flush() {
    if (player_node_) {
        [player_node_ stop];
        if (is_playing_) {
            [player_node_ play];
        }
    }
}

void AVAudioEngineOutputImpl::SetVolume(float volume) {
    volume_ = std::max(0.0f, std::min(1.0f, volume));
    if (audio_engine_ && audio_engine_.mainMixerNode) {
        audio_engine_.mainMixerNode.outputVolume = volume_;
    }
}

float AVAudioEngineOutputImpl::GetVolume() const {
    return volume_;
}

void AVAudioEngineOutputImpl::SetMute(bool mute) {
    is_muted_ = mute;
    if (audio_engine_ && audio_engine_.mainMixerNode) {
        audio_engine_.mainMixerNode.outputVolume = mute ? 0.0f : volume_;
    }
}

bool AVAudioEngineOutputImpl::IsMuted() const {
    return is_muted_;
}

int64_t AVAudioEngineOutputImpl::GetCurrentPositionMs() const {
    if (sample_rate_ <= 0) {
        return 0;
    }
    return (total_samples_played_ * 1000) / sample_rate_;
}

int64_t AVAudioEngineOutputImpl::GetBufferedDurationMs() const {
    // AVAudioEngine doesn't expose buffer info directly
    return 0;
}

void AVAudioEngineOutputImpl::Release() {
    if (player_node_) {
        [player_node_ stop];
        player_node_ = nil;
    }

    if (audio_engine_) {
        [audio_engine_ stop];
        audio_engine_ = nil;
    }

    audio_format_ = nil;
    is_initialized_ = false;
}

} // namespace mango_player

// C interface implementation
extern "C" {

void* mango_create_avaudioengine_output(void) {
    return new mango_player::AVAudioEngineOutputImpl();
}

void mango_destroy_avaudioengine_output(void* output) {
    if (output) {
        delete static_cast<mango_player::AVAudioEngineOutputImpl*>(output);
    }
}

} // extern "C"
