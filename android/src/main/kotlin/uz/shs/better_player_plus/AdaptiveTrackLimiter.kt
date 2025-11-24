package uz.shs.better_player_plus

import androidx.media3.common.Format

class AdaptiveTrackLimiter(var videoTrackConstraint: Map<String, Int?>? = null) {

    fun isTrackLimited(width: Int, height: Int): Boolean {
        if (videoTrackConstraint == null) {
            return false
        }
        if (width == Format.NO_VALUE || height == Format.NO_VALUE) return false
        val maxWidth = videoTrackConstraint!!["width"] ?: 0
        val maxHeight = videoTrackConstraint!!["height"] ?: 0
        return width >= maxWidth || height >= maxHeight
    }
}