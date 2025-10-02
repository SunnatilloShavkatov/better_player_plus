import Foundation
import Flutter
import AVFoundation
import AVKit
import GLKit
import UIKit

public class BetterPlayer: NSObject, FlutterPlatformView, FlutterStreamHandler, AVPictureInPictureControllerDelegate {
    // Core state
    @objc public private(set) var player: AVPlayer = AVPlayer()
    @objc public private(set) var loaderDelegate: BetterPlayerEzDrmAssetsLoaderDelegate?
    @objc public var eventChannel: FlutterEventChannel?
    @objc public var eventSink: FlutterEventSink?

    @objc public var preferredTransform: CGAffineTransform = .identity
    @objc public private(set) var disposed: Bool = false
    @objc public private(set) var isPlaying: Bool = false
    @objc public var isLooping: Bool = false
    @objc public private(set) var isInitialized: Bool = false
    @objc public private(set) var key: String?
    @objc public private(set) var failedCount: Int = 0

    @objc public var _playerLayer: AVPlayerLayer?
    @objc public var _pictureInPicture: Bool = false
    @objc public var _observersAdded: Bool = false
    @objc public var stalledCount: Int = 0
    @objc public var isStalledCheckStarted: Bool = false
    @objc public var playerRate: Float = 1.0
    @objc public var overriddenDuration: Int = 0
    @objc public var lastAvPlayerTimeControlStatus: AVPlayer.TimeControlStatus?

    // PiP
    @available(iOS 9.0, *)
    private var pipController: AVPictureInPictureController?
    private var restoreUserInterfaceForPIPStopCompletionHandler: ((Bool) -> Void)?

    // KVO contexts
    private var timeRangeContext = 0
    private var statusContext = 0
    private var playbackLikelyToKeepUpContext = 0
    private var playbackBufferEmptyContext = 0
    private var playbackBufferFullContext = 0
    private var presentationSizeContext = 0

    override public init() {
        super.init()
        // Default AVPlayer configuration
        player.actionAtItemEnd = .none
        if #available(iOS 10.0, *) {
            player.automaticallyWaitsToMinimizeStalling = false
        }
        _observersAdded = false
    }

    // MARK: FlutterPlatformView
    public func view() -> UIView {
        let playerView = BetterPlayerView(frame: .zero)
        playerView.player = player
        return playerView
    }

    // MARK: Observers
    private func addObservers(item: AVPlayerItem) {
        guard !_observersAdded else { return }
        player.addObserver(self, forKeyPath: "rate", options: [], context: nil)
        item.addObserver(self, forKeyPath: "loadedTimeRanges", options: [], context: &timeRangeContext)
        item.addObserver(self, forKeyPath: "status", options: [], context: &statusContext)
        item.addObserver(self, forKeyPath: "presentationSize", options: [], context: &presentationSizeContext)
        item.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: [], context: &playbackLikelyToKeepUpContext)
        item.addObserver(self, forKeyPath: "playbackBufferEmpty", options: [], context: &playbackBufferEmptyContext)
        item.addObserver(self, forKeyPath: "playbackBufferFull", options: [], context: &playbackBufferFullContext)
        NotificationCenter.default.addObserver(self, selector: #selector(itemDidPlayToEndTime(_:)), name: .AVPlayerItemDidPlayToEndTime, object: item)
        _observersAdded = true
    }

    private func removeObservers() {
        guard _observersAdded else { return }
        player.removeObserver(self, forKeyPath: "rate", context: nil)
        if let current = player.currentItem {
            current.removeObserver(self, forKeyPath: "status", context: &statusContext)
            current.removeObserver(self, forKeyPath: "presentationSize", context: &presentationSizeContext)
            current.removeObserver(self, forKeyPath: "loadedTimeRanges", context: &timeRangeContext)
            current.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp", context: &playbackLikelyToKeepUpContext)
            current.removeObserver(self, forKeyPath: "playbackBufferEmpty", context: &playbackBufferEmptyContext)
            current.removeObserver(self, forKeyPath: "playbackBufferFull", context: &playbackBufferFullContext)
        }
        NotificationCenter.default.removeObserver(self)
        _observersAdded = false
    }

    @objc private func itemDidPlayToEndTime(_ notification: Notification) {
        if isLooping, let p = notification.object as? AVPlayerItem {
            p.seek(to: .zero, completionHandler: nil)
        } else {
            eventSink?(["event": "completed", "key": key ?? NSNull()])
            removeObservers()
        }
    }

    private func radiansToDegrees(_ radians: CGFloat) -> CGFloat {
        let degrees = CGFloat(GLKMathRadiansToDegrees(Float(radians)))
        return degrees < 0 ? degrees + 360.0 : degrees
    }

    private func getVideoComposition(with transform: CGAffineTransform, asset: AVAsset, videoTrack: AVAssetTrack) -> AVMutableVideoComposition {
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRangeMake(start: .zero, duration: asset.duration)
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        layerInstruction.setTransform(preferredTransform, at: .zero)
        let videoComposition = AVMutableVideoComposition()
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        // Adjust render size for portrait videos
        var width = videoTrack.naturalSize.width
        var height = videoTrack.naturalSize.height
        let rotationDegrees = Int(round(radiansToDegrees(atan2(preferredTransform.b, preferredTransform.a))))
        if rotationDegrees == 90 || rotationDegrees == 270 {
            width = videoTrack.naturalSize.height
            height = videoTrack.naturalSize.width
        }
        videoComposition.renderSize = CGSize(width: width, height: height)

        let nominalFrameRate = videoTrack.nominalFrameRate
        let fps = nominalFrameRate > 0 ? Int(ceil(nominalFrameRate)) : 30
        videoComposition.frameDuration = CMTimeMake(value: 1, timescale: Int32(fps))
        return videoComposition
    }

    private func fixTransform(_ videoTrack: AVAssetTrack) -> CGAffineTransform {
        var transform = videoTrack.preferredTransform
        let rotationDegrees = Int(round(radiansToDegrees(atan2(transform.b, transform.a))))
        if rotationDegrees == 90 {
            transform.tx = videoTrack.naturalSize.height
            transform.ty = 0
        } else if rotationDegrees == 180 {
            transform.tx = videoTrack.naturalSize.width
            transform.ty = videoTrack.naturalSize.height
        } else if rotationDegrees == 270 {
            transform.tx = 0
            transform.ty = videoTrack.naturalSize.width
        }
        return transform
    }

    // MARK: Data Source
    @objc public func setDataSourceAsset(_ asset: String, withKey key: String?, withCertificateUrl certificateUrl: String?, withLicenseUrl licenseUrl: String?, cacheKey: String?, cacheManager: CacheManager, overriddenDuration: Int) {
        let path = Bundle.main.path(forResource: asset, ofType: nil) ?? asset
        let url = URL(fileURLWithPath: path)
        setDataSourceURL(url, withKey: key, withCertificateUrl: certificateUrl, withLicenseUrl: licenseUrl, withHeaders: [:], withCache: false, cacheKey: cacheKey, cacheManager: cacheManager, overriddenDuration: overriddenDuration, videoExtension: nil)
    }

    @objc public func setDataSourceURL(_ url: URL, withKey key: String?, withCertificateUrl certificateUrl: String?, withLicenseUrl licenseUrl: String?, withHeaders headersIn: [String: Any], withCache useCache: Bool, cacheKey: String?, cacheManager: CacheManager, overriddenDuration: Int, videoExtension: String?) {
        overriddenDuration == 0 ? () : ()
        var headers = headersIn
        if headers.isEmpty == false {
            // ok
        }
        let item: AVPlayerItem
        if useCache {
            let cacheKeyFinal = cacheKey
            let videoExtFinal = videoExtension
            if let cachedItem = cacheManager.getCachingPlayerItemForNormalPlayback(url, cacheKey: cacheKeyFinal, videoExtension: videoExtFinal, headers: headers as [NSObject : AnyObject]) {
                item = cachedItem
            } else {
                let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
                item = AVPlayerItem(asset: asset)
            }
        } else {
            let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
            if let certificateUrl, !certificateUrl.isEmpty, let certURL = URL(string: certificateUrl) {
                let licenseNSURL = licenseUrl.flatMap { URL(string: $0) }
                let loader = BetterPlayerEzDrmAssetsLoaderDelegate(certificateURL: certURL, withLicenseURL: licenseNSURL)
                loaderDelegate = loader
                let qos = DispatchQoS.QoSClass.default
                let streamQueue = DispatchQueue(label: "streamQueue", qos: DispatchQoS(qosClass: qos, relativePriority: -1))
                asset.resourceLoader.setDelegate(loader, queue: streamQueue)
            }
            item = AVPlayerItem(asset: asset)
        }

        if #available(iOS 10.0, *), overriddenDuration > 0 {
            self.overriddenDuration = overriddenDuration
        } else {
            self.overriddenDuration = 0
        }
        setDataSourcePlayerItem(item, withKey: key)
    }

    private func setDataSourcePlayerItem(_ item: AVPlayerItem, withKey key: String?) {
        self.key = key
        stalledCount = 0
        isStalledCheckStarted = false
        playerRate = 1.0
        player.replaceCurrentItem(with: item)

        let asset = item.asset
        asset.loadValuesAsynchronously(forKeys: ["tracks"]) { [weak self] in
            guard let self else { return }
            if asset.statusOfValue(forKey: "tracks", error: nil) == .loaded {
                let tracks = asset.tracks(withMediaType: .video)
                if let videoTrack = tracks.first {
                    videoTrack.loadValuesAsynchronously(forKeys: ["preferredTransform"]) { [weak self] in
                        guard let self else { return }
                        if self.disposed { return }
                        if videoTrack.statusOfValue(forKey: "preferredTransform", error: nil) == .loaded {
                            self.preferredTransform = self.fixTransform(videoTrack)
                            let videoComposition = self.getVideoComposition(with: self.preferredTransform, asset: asset, videoTrack: videoTrack)
                            item.videoComposition = videoComposition
                        }
                    }
                }
            }
        }
        addObservers(item: item)
    }

    // MARK: Stalled handling
    @objc public func handleStalled() {
        if isStalledCheckStarted { return }
        isStalledCheckStarted = true
        startStalledCheck()
    }

    @objc private func startStalledCheck() {
        if let currentItem = player.currentItem, currentItem.isPlaybackLikelyToKeepUp || (availableDuration() - CMTimeGetSeconds(currentItem.currentTime)) > 10.0 {
            play()
        } else {
            stalledCount += 1
            if stalledCount > 60 {
                eventSink?(FlutterError(code: "VideoError", message: "Failed to load video: playback stalled", details: nil))
                return
            }
            perform(#selector(startStalledCheck), with: nil, afterDelay: 1)
        }
    }

    private func availableDuration() -> TimeInterval {
        guard let range = player.currentItem?.loadedTimeRanges.first?.timeRangeValue else { return 0 }
        let startSeconds = CMTimeGetSeconds(range.start)
        let durationSeconds = CMTimeGetSeconds(range.duration)
        return startSeconds + durationSeconds
    }

    // MARK: KVO
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "rate" {
            if #available(iOS 10.0, *) {
                if pipController?.isPictureInPictureActive == true {
                    if let last = lastAvPlayerTimeControlStatus, last == player.timeControlStatus {
                        // no change
                    } else {
                        lastAvPlayerTimeControlStatus = player.timeControlStatus
                        if player.timeControlStatus == .paused {
                            eventSink?(["event": "pause"]) 
                            return
                        }
                        if player.timeControlStatus == .playing {
                            eventSink?(["event": "play"]) 
                        }
                    }
                }
            }

            if player.rate == 0,
               let currentItem = player.currentItem,
               currentItem.currentTime() > .zero,
               currentItem.currentTime() < currentItem.duration,
               isPlaying {
                handleStalled()
            }
        }

        if context == &timeRangeContext {
            if let eventSink {
                var values: [[NSNumber]] = []
                if let loaded = (object as AnyObject).loadedTimeRanges as? [NSValue] {
                    for rangeValue in loaded {
                        let range = rangeValue.timeRangeValue
                        var start = NSNumber(value: BetterPlayerTimeUtils.FLTCMTimeToMillis(range.start))
                        var end = NSNumber(value: BetterPlayerTimeUtils.FLTCMTimeToMillis(range.start) + BetterPlayerTimeUtils.FLTCMTimeToMillis(range.duration))
                        if !CMTIME_IS_INVALID(player.currentItem?.forwardPlaybackEndTime ?? CMTime.invalid) {
                            let endTime = BetterPlayerTimeUtils.FLTCMTimeToMillis(player.currentItem!.forwardPlaybackEndTime)
                            if end.int64Value > endTime { end = NSNumber(value: endTime) }
                        }
                        values.append([start, end])
                    }
                }
                eventSink(["event": "bufferingUpdate", "values": values, "key": key ?? NSNull()])
            }
        } else if context == &presentationSizeContext {
            onReadyToPlay()
        } else if context == &statusContext {
            guard let item = object as? AVPlayerItem else { return }
            switch item.status {
            case .failed:
                NSLog("Failed to load video: \(String(describing: item.error?.localizedDescription))")
                eventSink?(FlutterError(code: "VideoError", message: "Failed to load video: \(item.error?.localizedDescription ?? "unknown")", details: nil))
            case .unknown:
                break
            case .readyToPlay:
                onReadyToPlay()
            @unknown default:
                break
            }
        } else if context == &playbackLikelyToKeepUpContext {
            if player.currentItem?.isPlaybackLikelyToKeepUp == true {
                updatePlayingState()
                eventSink?(["event": "bufferingEnd", "key": key ?? NSNull()])
            }
        } else if context == &playbackBufferEmptyContext {
            eventSink?(["event": "bufferingStart", "key": key ?? NSNull()])
        } else if context == &playbackBufferFullContext {
            eventSink?(["event": "bufferingEnd", "key": key ?? NSNull()])
        }
    }

    // MARK: Playback state updates
    @objc public func updatePlayingState() {
        guard isInitialized, key != nil else { return }
        if !_observersAdded, let current = player.currentItem { addObservers(item: current) }
        if isPlaying {
            if #available(iOS 10.0, *) {
                player.playImmediately(atRate: 1.0)
                player.rate = playerRate
            } else {
                player.play()
                player.rate = playerRate
            }
        } else {
            player.pause()
        }
    }

    @objc public func onReadyToPlay() {
        guard let eventSink, !isInitialized, key != nil else { return }
        guard player.currentItem != nil else { return }
        if player.status != .readyToPlay { return }

        let size = player.currentItem!.presentationSize
        let width = size.width
        let height = size.height

        let asset = player.currentItem!.asset
        let onlyAudio = asset.tracks(withMediaType: .video).isEmpty
        if !onlyAudio && height == .zero && width == .zero { return }
        let isLive = player.currentItem!.duration.isIndefinite
        if !isLive && duration() == 0 { return }

        if let firstTrack = player.currentItem?.tracks.first?.assetTrack {
            let naturalSize = firstTrack.naturalSize
            let prefTrans = firstTrack.preferredTransform
            let realSize = naturalSize.applying(prefTrans)

            var durationMillis = BetterPlayerTimeUtils.FLTCMTimeToMillis(player.currentItem!.asset.duration)
            if overriddenDuration > 0 && durationMillis > overriddenDuration {
                player.currentItem!.forwardPlaybackEndTime = CMTimeMake(value: Int64(overriddenDuration/1000), timescale: 1)
                durationMillis = Int64(overriddenDuration)
            }

            isInitialized = true
            updatePlayingState()
            let absWidth = abs(realSize.width)
            let absHeight = abs(realSize.height)
            eventSink([
                "event": "initialized",
                "duration": NSNumber(value: duration()),
                "width": NSNumber(value: absWidth != 0 ? Double(absWidth) : Double(width)),
                "height": NSNumber(value: absHeight != 0 ? Double(absHeight) : Double(height)),
                "key": key ?? NSNull()
            ])
        }
    }

    // MARK: Controls
    @objc public func play() {
        stalledCount = 0
        isStalledCheckStarted = false
        isPlaying = true
        updatePlayingState()
    }

    @objc public func pause() {
        isPlaying = false
        updatePlayingState()
    }

    @objc public func position() -> Int64 {
        return BetterPlayerTimeUtils.FLTCMTimeToMillis(player.currentTime())
    }

    @objc public func absolutePosition() -> Int64 {
        if let date = player.currentItem?.currentDate() {
            return BetterPlayerTimeUtils.FLTNSTimeIntervalToMillis(date.timeIntervalSince1970)
        }
        return 0
    }

    @objc public func duration() -> Int64 {
        var time: CMTime
        if #available(iOS 13.0, *) {
            time = player.currentItem?.duration ?? CMTime.invalid
        } else {
            time = player.currentItem?.asset.duration ?? CMTime.invalid
        }
        if !CMTIME_IS_INVALID(player.currentItem?.forwardPlaybackEndTime ?? CMTime.invalid) {
            time = player.currentItem!.forwardPlaybackEndTime
        }
        return BetterPlayerTimeUtils.FLTCMTimeToMillis(time)
    }

    @objc public func seekTo(_ location: Int) {
        let wasPlaying = isPlaying
        if wasPlaying { player.pause() }
        player.seek(to: CMTimeMake(value: Int64(location), timescale: 1000), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            guard let self else { return }
            if wasPlaying { self.player.rate = self.playerRate }
        }
    }

    @objc public func setIsLooping(_ looping: Bool) { isLooping = looping }

    @objc public func setVolume(_ volume: Double) {
        let clamped = max(0.0, min(1.0, volume))
        player.volume = Float(clamped)
    }

    @objc public func setSpeed(_ speed: Double, result: FlutterResult) {
        if speed == 1.0 || speed == 0.0 {
            playerRate = 1.0
            result(nil)
        } else if speed < 0 || speed > 2.0 {
            result(FlutterError(code: "unsupported_speed", message: "Speed must be >= 0.0 and <= 2.0", details: nil))
        } else if ((speed > 1.0 && player.currentItem?.canPlayFastForward == true) || (speed < 1.0 && player.currentItem?.canPlaySlowForward == true)) {
            playerRate = Float(speed)
            result(nil)
        } else {
            if speed <= 1.0 {
                result(FlutterError(code: "unsupported_slow_forward", message: "This video cannot be played slow forward", details: nil))
            }
        }
        if isPlaying {
            if #available(iOS 16.0, *) { player.defaultRate = Float(speed) }
            player.rate = Float(speed)
        }
    }

    @objc public func setTrackParameters(_ width: Int, _ height: Int, _ bitrate: Int) {
        player.currentItem?.preferredPeakBitRate = bitrate > 0 ? Double(bitrate) : 0
        if #available(iOS 11.0, *) {
            if width == 0 && height == 0 {
                player.currentItem?.preferredMaximumResolution = .zero
            } else {
                player.currentItem?.preferredMaximumResolution = CGSize(width: width, height: height)
            }
        }
    }

    // MARK: PiP
    @objc public func setPictureInPicture(_ pictureInPicture: Bool) {
        _pictureInPicture = pictureInPicture
        if #available(iOS 9.0, *) {
            if let pipController, _pictureInPicture, pipController.isPictureInPictureActive == false {
                DispatchQueue.main.async { pipController.startPictureInPicture() }
            } else if let pipController, !_pictureInPicture, pipController.isPictureInPictureActive {
                DispatchQueue.main.async { pipController.stopPictureInPicture() }
            }
        }
    }

    @available(iOS 9.0, *)
    private func setupPipController() {
        try? AVAudioSession.sharedInstance().setActive(true)
        UIApplication.shared.beginReceivingRemoteControlEvents()
        if pipController == nil, let playerLayer = _playerLayer, AVPictureInPictureController.isPictureInPictureSupported() {
            pipController = AVPictureInPictureController(playerLayer: playerLayer)
            pipController?.delegate = self
        }
    }

    @objc public func enablePictureInPicture(_ frame: CGRect) {
        disablePictureInPicture()
        usePlayerLayer(frame)
    }

    private func usePlayerLayer(_ frame: CGRect) {
        // Attach a temporary layer to enable PiP
        let layer = AVPlayerLayer(player: player)
        self._playerLayer = layer
        let rootVC = UIApplication.shared.keyWindow?.rootViewController ?? UIApplication.shared.windows.first?.rootViewController
        layer.frame = frame
        layer.needsDisplayOnBoundsChange = true
        rootVC?.view.layer.addSublayer(layer)
        rootVC?.view.layer.needsDisplayOnBoundsChange = true
        if #available(iOS 9.0, *) { pipController = nil }
        setupPipController()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.setPictureInPicture(true)
        }
    }

    @objc public func disablePictureInPicture() {
        setPictureInPicture(true)
        if let layer = _playerLayer {
            layer.removeFromSuperlayer()
            _playerLayer = nil
            eventSink?(["event": "pipStop"]) 
        }
    }

    // MARK: AVPictureInPictureControllerDelegate
    @available(iOS 9.0, *)
    public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        disablePictureInPicture()
    }

    @available(iOS 9.0, *)
    public func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        eventSink?(["event": "pipStart"]) 
    }

    @available(iOS 9.0, *)
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        // noop
    }

    @available(iOS 9.0, *)
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        restoreUserInterfaceForPIPStopCompletionHandler?(true)
        restoreUserInterfaceForPIPStopCompletionHandler = nil
    }

    @objc public func setAudioTrack(_ name: String, index: Int) {
        guard let group = player.currentItem?.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else { return }
        let options = group.options
        for (trackIndex, option) in options.enumerated() {
            let metaDatas = AVMetadataItem.metadataItems(from: option.commonMetadata, withKey: "title" as (NSCopying & NSObjectProtocol), keySpace: .common)
            if let title = (metaDatas.first as? AVMetadataItem)?.stringValue {
                if title == name && trackIndex == index {
                    player.currentItem?.select(option, in: group)
                }
            }
        }
    }

    @objc public func setMixWithOthers(_ mixWithOthers: Bool) {
        if mixWithOthers {
            try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        } else {
            try? AVAudioSession.sharedInstance().setCategory(.playback)
        }
    }

    // MARK: FlutterStreamHandler
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        onReadyToPlay()
        return nil
    }

    // MARK: Lifecycle
    @objc public func clear() {
        isInitialized = false
        isPlaying = false
        disposed = false
        failedCount = 0
        key = nil
        guard player.currentItem != nil else { return }
        removeObservers()
        player.currentItem?.asset.cancelLoading()
    }

    @objc public func disposeSansEventChannel() {
        do { clear() } catch { NSLog("\(error.localizedDescription)") }
    }

    @objc public func dispose() {
        pause()
        disposeSansEventChannel()
        eventChannel?.setStreamHandler(nil)
        disablePictureInPicture()
        setPictureInPicture(false)
        disposed = true
    }
}
