package uz.shs.better_player_plus

import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackException.ERROR_CODE_REMOTE_ERROR
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.analytics.AnalyticsListener
import androidx.media3.exoplayer.source.LoadEventInfo
import androidx.media3.exoplayer.source.MediaLoadData


@UnstableApi
class AnalyticsListener(private val eventSink: QueuingEventSink) : AnalyticsListener {
    override fun onPlayerError(eventTime: AnalyticsListener.EventTime, error: PlaybackException) {
        val eventData: MutableMap<String, Any> = HashMap()
        eventData["event"] = "analytics" // Custom event type for Dart
        eventData["collector"] = "error"
        eventData["type"] = getErrorType(error.errorCode)
        eventData["code"] = error.errorCodeName
        eventData["message"] = error.message.toString()
        eventData["description"] = error.cause.toString()
        eventData["stack_trace"] = error.stackTraceToString()
        eventSink.success(eventData)
        super.onPlayerError(eventTime, error)
    }



    override fun onLoadCompleted(
        eventTime: AnalyticsListener.EventTime,
        loadEventInfo: LoadEventInfo,
        mediaLoadData: MediaLoadData
    ) {
        // Extract data:
        val fragmentSn = mediaLoadData.trackType
        val fragmentUrl = loadEventInfo.uri.toString()
        val bytesLoaded = loadEventInfo.bytesLoaded
        val loadDuration = loadEventInfo.loadDurationMs / 1000
        // Prepare data for Flutter
        val eventData: MutableMap<String, Any> = HashMap()
        eventData["event"] = "analytics" // Custom event type for Dart
        eventData["collector"] = "bandwidth"
        eventData["fragment_url"] = fragmentUrl
        eventData["bytes_size"] = bytesLoaded
        eventData["fragment_duration"] = loadDuration
        eventSink.success(eventData)
        super.onLoadCompleted(eventTime, loadEventInfo, mediaLoadData)
    }

    private fun getErrorType(errorCode: Int): String {
        return when (errorCode) {
            ERROR_CODE_REMOTE_ERROR, PlaybackException.ERROR_CODE_TIMEOUT, PlaybackException.ERROR_CODE_IO_UNSPECIFIED, PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_FAILED, PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_TIMEOUT, PlaybackException.ERROR_CODE_IO_INVALID_HTTP_CONTENT_TYPE, PlaybackException.ERROR_CODE_IO_BAD_HTTP_STATUS, PlaybackException.ERROR_CODE_IO_FILE_NOT_FOUND, PlaybackException.ERROR_CODE_IO_NO_PERMISSION, PlaybackException.ERROR_CODE_IO_CLEARTEXT_NOT_PERMITTED, PlaybackException.ERROR_CODE_IO_READ_POSITION_OUT_OF_RANGE -> "networkError"
            PlaybackException.ERROR_CODE_PARSING_CONTAINER_MALFORMED, PlaybackException.ERROR_CODE_PARSING_MANIFEST_MALFORMED, PlaybackException.ERROR_CODE_PARSING_CONTAINER_UNSUPPORTED, PlaybackException.ERROR_CODE_PARSING_MANIFEST_UNSUPPORTED -> "parsingError"
            PlaybackException.ERROR_CODE_DECODER_INIT_FAILED, PlaybackException.ERROR_CODE_DECODER_QUERY_FAILED, PlaybackException.ERROR_CODE_DECODING_FAILED, PlaybackException.ERROR_CODE_DECODING_FORMAT_EXCEEDS_CAPABILITIES, PlaybackException.ERROR_CODE_DECODING_FORMAT_UNSUPPORTED, PlaybackException.ERROR_CODE_DECODING_RESOURCES_RECLAIMED, PlaybackException.ERROR_CODE_AUDIO_TRACK_INIT_FAILED, PlaybackException.ERROR_CODE_AUDIO_TRACK_WRITE_FAILED, PlaybackException.ERROR_CODE_AUDIO_TRACK_OFFLOAD_WRITE_FAILED, PlaybackException.ERROR_CODE_AUDIO_TRACK_OFFLOAD_INIT_FAILED -> "mediaError"
            PlaybackException.ERROR_CODE_DRM_UNSPECIFIED, PlaybackException.ERROR_CODE_DRM_SCHEME_UNSUPPORTED, PlaybackException.ERROR_CODE_DRM_PROVISIONING_FAILED, PlaybackException.ERROR_CODE_DRM_CONTENT_ERROR, PlaybackException.ERROR_CODE_DRM_LICENSE_ACQUISITION_FAILED, PlaybackException.ERROR_CODE_DRM_DISALLOWED_OPERATION, PlaybackException.ERROR_CODE_DRM_SYSTEM_ERROR, PlaybackException.ERROR_CODE_DRM_DEVICE_REVOKED, PlaybackException.ERROR_CODE_DRM_LICENSE_EXPIRED -> "keySystemError"
            PlaybackException.ERROR_CODE_VIDEO_FRAME_PROCESSOR_INIT_FAILED, PlaybackException.ERROR_CODE_VIDEO_FRAME_PROCESSING_FAILED -> "mediaError"
            else -> "otherError"
        }
    }
}