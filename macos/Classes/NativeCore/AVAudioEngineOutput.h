/**
 * AVAudioEngineOutput - macOS AVAudioEngine Audio Output
 * 
 * Implements IAudioOutput interface using AVFoundation's AVAudioEngine
 */

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#ifdef __cplusplus
#include "mango_player/interfaces/audio_output.h"

namespace mango_player {

class AVAudioEngineOutputImpl : public IAudioOutput {
public:
    AVAudioEngineOutputImpl();
    ~AVAudioEngineOutputImpl() override;

    bool Initialize(int sample_rate, int channels, int bits_per_sample) override;
    int Write(const uint8_t* data, int size, int64_t pts_ms) override;
    void Start() override;
    void Pause() override;
    void Resume() override;
    void Stop() override;
    void Flush() override;
    void SetVolume(float volume) override;
    float GetVolume() const override;
    void SetMute(bool mute) override;
    bool IsMuted() const override;
    int64_t GetCurrentPositionMs() const override;
    int64_t GetBufferedDurationMs() const override;
    void Release() override;

private:
    AVAudioEngine* audio_engine_;
    AVAudioPlayerNode* player_node_;
    AVAudioFormat* audio_format_;
    float volume_;
    bool is_muted_;
    bool is_playing_;
    int sample_rate_;
    int channels_;
    int64_t total_samples_played_;
    bool is_initialized_;
};

} // namespace mango_player

#endif // __cplusplus

// C interface for Swift/ObjC
#ifdef __cplusplus
extern "C" {
#endif

void* mango_create_avaudioengine_output(void);
void mango_destroy_avaudioengine_output(void* output);

#ifdef __cplusplus
}
#endif
