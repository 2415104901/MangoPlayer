package com.example.mango_player.ijkplayer

import android.content.Context
import android.net.Uri
import android.view.Surface
import tv.danmaku.ijk.media.player.IjkMediaPlayer

class IJKPlayerWrapper(private val context: Context) {
    private var mediaPlayer: IjkMediaPlayer? = null

    fun initialize() {
        mediaPlayer = IjkMediaPlayer()
        // Configure options
        mediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec", 1)
        mediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-auto-rotate", 1)
        mediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "opensles", 1)
        mediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "overlay-format", IjkMediaPlayer.SDL_FCC_RV32)
        mediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "framedrop", 1)
        mediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "start-on-prepared", 0)
        mediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "http-detect-range-support", 0)
        mediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_CODEC, "skip_loop_filter", 48)
    }

    fun setDataSource(uri: String, headers: Map<String, String>?) {
        mediaPlayer?.setDataSource(context, Uri.parse(uri), headers)
    }
    
    fun setSurface(surface: Surface) {
        mediaPlayer?.setSurface(surface)
    }

    fun prepareAsync() {
        mediaPlayer?.prepareAsync()
    }

    fun start() {
        mediaPlayer?.start()
    }

    fun pause() {
        mediaPlayer?.pause()
    }

    fun stop() {
        mediaPlayer?.stop()
    }

    fun seekTo(msec: Long) {
        mediaPlayer?.seekTo(msec)
    }

    fun release() {
        mediaPlayer?.release()
        mediaPlayer = null
    }

    fun getDuration(): Long {
        return mediaPlayer?.duration ?: 0
    }

    fun getCurrentPosition(): Long {
        return mediaPlayer?.currentPosition ?: 0
    }
    
    fun setVolume(volume: Float) {
        mediaPlayer?.setVolume(volume, volume)
    }
    
    fun setSpeed(speed: Float) {
        mediaPlayer?.setSpeed(speed)
    }
    
    fun getMediaPlayer(): IjkMediaPlayer? {
        return mediaPlayer
    }
}
