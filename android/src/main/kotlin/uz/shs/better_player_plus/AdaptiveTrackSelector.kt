import androidx.media3.common.Format
import androidx.media3.common.TrackGroup
import androidx.media3.common.util.Clock
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.trackselection.AdaptiveTrackSelection
import androidx.media3.exoplayer.upstream.BandwidthMeter
import com.google.common.collect.ImmutableList
import uz.shs.better_player_plus.AdaptiveTrackLimiter

@UnstableApi
class AdaptiveTrackSelector(
    private val adaptiveTrackLimiter: AdaptiveTrackLimiter,
    group: TrackGroup,
    tracks: IntArray,
    type: Int,
    bandwidthMeter: BandwidthMeter,
    minDurationForQualityIncreaseMs: Long,
    maxDurationForQualityDecreaseMs: Long,
    minDurationToRetainAfterDiscardMs: Long,
    maxWidthToDiscard: Int,
    maxHeightToDiscard: Int,
    bandwidthFraction: Float,
    bufferedFractionToLiveEdgeForQualityIncrease: Float,
    adaptationCheckpoints: MutableList<AdaptationCheckpoint>,
    clock: Clock
) : AdaptiveTrackSelection(
    group,
    tracks,
    type,
    bandwidthMeter,
    minDurationForQualityIncreaseMs,
    maxDurationForQualityDecreaseMs,
    minDurationToRetainAfterDiscardMs,
    maxWidthToDiscard,
    maxHeightToDiscard,
    bandwidthFraction,
    bufferedFractionToLiveEdgeForQualityIncrease,
    adaptationCheckpoints,
    clock
) {

    class Factory @JvmOverloads constructor(
        private val minDurationForQualityIncreaseMs: Int = DEFAULT_MIN_DURATION_FOR_QUALITY_INCREASE_MS,
        private val maxDurationForQualityDecreaseMs: Int = DEFAULT_MAX_DURATION_FOR_QUALITY_DECREASE_MS,
        private val minDurationToRetainAfterDiscardMs: Int = DEFAULT_MIN_DURATION_TO_RETAIN_AFTER_DISCARD_MS,
        private val bandwidthFraction: Float = DEFAULT_BANDWIDTH_FRACTION,
        private val bufferedFractionToLiveEdgeForQualityIncrease: Float = DEFAULT_BUFFERED_FRACTION_TO_LIVE_EDGE_FOR_QUALITY_INCREASE,
        private val clock: Clock = Clock.DEFAULT,
        private val trackLimiter: AdaptiveTrackLimiter
    ) : AdaptiveTrackSelection.Factory(
        minDurationForQualityIncreaseMs,
        maxDurationForQualityDecreaseMs,
        minDurationToRetainAfterDiscardMs,
        bandwidthFraction,
        bufferedFractionToLiveEdgeForQualityIncrease,
        clock
    ) {

        override fun createAdaptiveTrackSelection(
            group: TrackGroup,
            tracks: IntArray,
            type: Int,
            bandwidthMeter: BandwidthMeter,
            adaptationCheckpoints: ImmutableList<AdaptationCheckpoint>
        ): AdaptiveTrackSelection {
            return AdaptiveTrackSelector(
                trackLimiter,
                group,
                tracks,
                type,
                bandwidthMeter,
                minDurationForQualityIncreaseMs.toLong(),
                maxDurationForQualityDecreaseMs.toLong(),
                minDurationToRetainAfterDiscardMs.toLong(),
                Int.MAX_VALUE,
                Int.MAX_VALUE,
                bandwidthFraction,
                bufferedFractionToLiveEdgeForQualityIncrease,
                adaptationCheckpoints,
                Clock.DEFAULT
            )
        }
    }

    override fun canSelectFormat(
        format: Format, trackBitrate: Int, effectiveBitrate: Long
    ): Boolean {

        val isLimited = adaptiveTrackLimiter.isTrackLimited(format.width, format.height)
        val isSelectable = super.canSelectFormat(format, trackBitrate, effectiveBitrate)
        return isSelectable && !isLimited
    }

}