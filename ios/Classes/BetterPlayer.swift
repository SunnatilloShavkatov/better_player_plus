import Foundation
import Flutter
import AVFoundation
import AVKit
import GLKit

final class BetterPlayer: NSObject, FlutterPlatformView, FlutterStreamHandler, AVPictureInPictureControllerDelegate {
    let player: AVPlayer = AVPlayer()
    var loaderDelegate: BetterPlayerEzDrmAssetsLoaderDelegate?
    var eventChannel: FlutterEventChannel?
    var eventSink: FlutterEventSink?
    var preferredTransform: CGAffineTransform = .identity
    private(set) var disposed: Bool = false
    private(set) var isPlaying: Bool = false
    var isLooping: Bool = false
    private(set) var isInitialized: Bool = false
    private(set) var key: String?
    private(set) var failedCount: Int = 0
    var playerLayer: AVPlayerLayer?
    var pictureInPicture: Bool = false
    var observersAdded: Bool = false
    var stalledCount: Int = 0
    var isStalledCheckStarted: Bool = false
    var playerRate: Float = 1.0
    var overriddenDuration: Int = 0
    var lastAvPlayerTimeControlStatus: AVPlayer.TimeControlStatus = .paused
    var textureId: Int64 { Int64(ObjectIdentifier(self).hashValue) }

    override init() {
        super.init()
        player.actionAtItemEnd = .none
        if #available(iOS 10.0, *) { player.automaticallyWaitsToMinimizeStalling = false }
        observersAdded = false
    }

    func view() -> UIView { let v = BetterPlayerView(frame: .zero); v.player = player; return v }

    private func addObservers(_ item: AVPlayerItem) {
        guard !observersAdded else { return }
        player.addObserver(self, forKeyPath: "rate", options: [], context: nil)
        item.addObserver(self, forKeyPath: "loadedTimeRanges", options: [], context: &timeRangeContext)
        item.addObserver(self, forKeyPath: "status", options: [], context: &statusContext)
        item.addObserver(self, forKeyPath: "presentationSize", options: [], context: &presentationSizeContext)
        item.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: [], context: &playbackLikelyToKeepUpContext)
        item.addObserver(self, forKeyPath: "playbackBufferEmpty", options: [], context: &playbackBufferEmptyContext)
        item.addObserver(self, forKeyPath: "playbackBufferFull", options: [], context: &playbackBufferFullContext)
        NotificationCenter.default.addObserver(self, selector: #selector(itemDidPlayToEndTime(_:)), name: .AVPlayerItemDidPlayToEndTime, object: item)
        observersAdded = true
    }

    func clear() {
        isInitialized = false
        isPlaying = false
        disposed = false
        failedCount = 0
        key = nil
        guard player.currentItem != nil else { return }
        removeObservers()
        player.currentItem?.asset.cancelLoading()
    }

    private func removeObservers() {
        guard observersAdded else { return }
        player.removeObserver(self, forKeyPath: "rate")
        player.currentItem?.removeObserver(self, forKeyPath: "status", context: &statusContext)
        player.currentItem?.removeObserver(self, forKeyPath: "presentationSize", context: &presentationSizeContext)
        player.currentItem?.removeObserver(self, forKeyPath: "loadedTimeRanges", context: &timeRangeContext)
        player.currentItem?.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp", context: &playbackLikelyToKeepUpContext)
        player.currentItem?.removeObserver(self, forKeyPath: "playbackBufferEmpty", context: &playbackBufferEmptyContext)
        player.currentItem?.removeObserver(self, forKeyPath: "playbackBufferFull", context: &playbackBufferFullContext)
        NotificationCenter.default.removeObserver(self)
        observersAdded = false
    }

    @objc private func itemDidPlayToEndTime(_ notification: Notification) {
        if isLooping {
            if let p = notification.object as? AVPlayerItem {
                p.seek(to: .zero, completionHandler: nil)
            }
        } else if let sink = eventSink {
            sink(["event": "completed", "key": key ?? ""])
            removeObservers()
        }
    }

    private func radiansToDegrees(_ radians: CGFloat) -> CGFloat { return CGFloat(GLKMathRadiansToDegrees(Float(radians))) < 0 ? CGFloat(GLKMathRadiansToDegrees(Float(radians))) + 360 : CGFloat(GLKMathRadiansToDegrees(Float(radians))) }

    private func getVideoComposition(transform: CGAffineTransform, asset: AVAsset, videoTrack: AVAssetTrack) -> AVMutableVideoComposition {
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRangeMake(start: .zero, duration: asset.duration)
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        layerInstruction.setTransform(preferredTransform, at: .zero)
        let videoComposition = AVMutableVideoComposition()
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]
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
        if rotationDegrees == 90 { transform.tx = videoTrack.naturalSize.height; transform.ty = 0 }
        else if rotationDegrees == 180 { transform.tx = videoTrack.naturalSize.width; transform.ty = videoTrack.naturalSize.height }
        else if rotationDegrees == 270 { transform.tx = 0; transform.ty = videoTrack.naturalSize.width }
        return transform
    }

    func setDataSourceAsset(_ asset: String, key: String?, certificateUrl: String?, licenseUrl: String?, cacheKey: String?, cacheManager: CacheManager, overriddenDuration: Int) {
        if let path = Bundle.main.path(forResource: asset, ofType: nil) {
            setDataSourceURL(URL(fileURLWithPath: path), key: key, certificateUrl: certificateUrl, licenseUrl: licenseUrl, headers: [:], useCache: false, cacheKey: cacheKey, cacheManager: cacheManager, overriddenDuration: overriddenDuration, videoExtension: nil)
        }
    }

    func setDataSourceURL(_ url: URL, key: String?, certificateUrl: String?, licenseUrl: String?, headers: [String: String], useCache: Bool, cacheKey: String?, cacheManager: CacheManager, overriddenDuration: Int, videoExtension: String?) {
        overriddenDuration = 0
        let headers = headers
        let item: AVPlayerItem
        if useCache {
            let ck = cacheKey
            let ve = videoExtension
            item = cacheManager.getCachingPlayerItemForNormalPlayback(url, cacheKey: ck, videoExtension: ve, headers: headers as [NSObject : AnyObject]) ?? AVPlayerItem(url: url)
        } else {
            let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
            if let certificateUrl = certificateUrl, !certificateUrl.isEmpty {
                let certificateNSURL = URL(string: certificateUrl)!
                let licenseNSURL = URL(string: licenseUrl ?? "")!
                loaderDelegate = BetterPlayerEzDrmAssetsLoaderDelegate(certificateURL: certificateNSURL, withLicenseURL: licenseNSURL)
                let qos = DispatchQoS.QoSClass.default
                let streamQueue = DispatchQueue(label: "streamQueue", qos: qos)
                asset.resourceLoader.setDelegate(loaderDelegate, queue: streamQueue)
            }
            item = AVPlayerItem(asset: asset)
        }
        if #available(iOS 10.0, *), overriddenDuration > 0 { self.overriddenDuration = overriddenDuration }
        setDataSourcePlayerItem(item, key: key)
    }

    private func setDataSourcePlayerItem(_ item: AVPlayerItem, key: String?) {
        self.key = key
        stalledCount = 0
        isStalledCheckStarted = false
        playerRate = 1
        player.replaceCurrentItem(with: item)
        let asset = item.asset
        asset.loadValuesAsynchronously(forKeys: ["tracks"]) { [weak self] in
            guard let self = self else { return }
            if asset.statusOfValue(forKey: "tracks", error: nil) == .loaded {
                let tracks = asset.tracks(withMediaType: .video)
                if let videoTrack = tracks.first {
                    videoTrack.loadValuesAsynchronously(forKeys: ["preferredTransform"]) {
                        guard !self.disposed else { return }
                        if videoTrack.statusOfValue(forKey: "preferredTransform", error: nil) == .loaded {
                            self.preferredTransform = self.fixTransform(videoTrack)
                            let composition = self.getVideoComposition(transform: self.preferredTransform, asset: asset, videoTrack: videoTrack)
                            item.videoComposition = composition
                        }
                    }
                }
            }
        }
        addObservers(item)
    }

    private func handleStalled() {
        if isStalledCheckStarted { return }
        isStalledCheckStarted = true
        startStalledCheck()
    }

    @objc private func startStalledCheck() {
        if player.currentItem?.isPlaybackLikelyToKeepUp == true || (availableDuration() - CMTimeGetSeconds(player.currentItem?.currentTime() ?? .zero) > 10.0) {
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

    override func observeValue(forKeyPath path: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if path == "rate" {
            if #available(iOS 10.0, *), let pip = pipController, pip.isPictureInPictureActive {
                if lastAvPlayerTimeControlStatus == player.timeControlStatus { return }
                if player.timeControlStatus == .paused { lastAvPlayerTimeControlStatus = player.timeControlStatus; eventSink?(["event": "pause"]); return }
                if player.timeControlStatus == .playing { lastAvPlayerTimeControlStatus = player.timeControlStatus; eventSink?(["event": "play"]) }
            }
            if player.rate == 0 && player.currentItem?.currentTime() ?? .zero > .zero && player.currentItem?.currentTime() ?? .zero < (player.currentItem?.duration ?? .zero) && isPlaying {
                handleStalled()
            }
        } else if context == &timeRangeContext {
            if let sink = eventSink, let item = object as? AVPlayerItem {
                var values: [[NSNumber]] = []
                for v in item.loadedTimeRanges {
                    let range = v.timeRangeValue
                    var start = NSNumber(value: BetterPlayerTimeUtils.FLTCMTimeToMillis(range.start))
                    var end = NSNumber(value: BetterPlayerTimeUtils.FLTCMTimeToMillis(range.duration) + BetterPlayerTimeUtils.FLTCMTimeToMillis(range.start))
                    if !CMTIME_IS_INVALID(player.currentItem?.forwardPlaybackEndTime ?? .invalid) {
                        let endTime = BetterPlayerTimeUtils.FLTCMTimeToMillis(player.currentItem!.forwardPlaybackEndTime)
                        if end.int64Value > endTime { end = NSNumber(value: endTime) }
                    }
                    values.append([start, end])
                }
                sink(["event": "bufferingUpdate", "values": values, "key": key ?? ""])            }
        } else if context == &presentationSizeContext {
            onReadyToPlay()
        } else if context == &statusContext {
            if let item = object as? AVPlayerItem {
                switch item.status {
                case .failed:
                    print("Failed to load video:")
                    if let sink = eventSink { sink(FlutterError(code: "VideoError", message: "Failed to load video: \(item.error?.localizedDescription ?? "")", details: nil)) }
                case .unknown:
                    break
                case .readyToPlay:
                    onReadyToPlay()
                @unknown default:
                    break
                }
            }
        } else if context == &playbackLikelyToKeepUpContext {
            if player.currentItem?.isPlaybackLikelyToKeepUp == true { updatePlayingState(); eventSink?(["event": "bufferingEnd", "key": key ?? ""]) }
        } else if context == &playbackBufferEmptyContext {
            eventSink?(["event": "bufferingStart", "key": key ?? ""])        
        } else if context == &playbackBufferFullContext {
            eventSink?(["event": "bufferingEnd", "key": key ?? ""])        
        }
    }

    private func updatePlayingState() {
        guard isInitialized, key != nil else { return }
        if !observersAdded { if let item = player.currentItem { addObservers(item) } }
        if isPlaying {
            if #available(iOS 10.0, *) { player.playImmediately(atRate: 1.0); player.rate = playerRate } else { player.play(); player.rate = playerRate }
        } else { player.pause() }
    }

    private func onReadyToPlay() {
        if let sink = eventSink, !isInitialized, key != nil {
            guard let currentItem = player.currentItem else { return }
            if player.status != .readyToPlay { return }
            let size = currentItem.presentationSize
            let width = size.width
            let height = size.height
            let asset = currentItem.asset
            let onlyAudio = asset.tracks(withMediaType: .video).isEmpty
            if !onlyAudio && height == .zero && width == .zero { return }
            let isLive = CMTIME_IS_INDEFINITE(currentItem.duration)
            if !isLive && duration() == 0 { return }
            if let track = player.currentItem?.tracks.first, let assetTrack = track.assetTrack {
                let naturalSize = assetTrack.naturalSize
                let prefTrans = assetTrack.preferredTransform
                _ = CGSizeApplyAffineTransform(naturalSize, prefTrans)
            }
            let d = BetterPlayerTimeUtils.FLTCMTimeToMillis(player.currentItem?.asset.duration ?? .zero)
            if overriddenDuration > 0 && d > overriddenDuration { player.currentItem?.forwardPlaybackEndTime = CMTimeMake(value: Int64(overriddenDuration/1000), timescale: 1) }
            isInitialized = true
            updatePlayingState()
            sink(["event": "initialized", "duration": duration(), "width": fabs(size.width) == 0 ? width : fabs(size.width), "height": fabs(size.height) == 0 ? height : fabs(size.height), "key": key ?? ""])        }
    }

    func play() { stalledCount = 0; isStalledCheckStarted = false; isPlaying = true; updatePlayingState() }
    func pause() { isPlaying = false; updatePlayingState() }
    func position() -> Int64 { BetterPlayerTimeUtils.FLTCMTimeToMillis(player.currentTime()) }
    func absolutePosition() -> Int64 { BetterPlayerTimeUtils.FLTNSTimeIntervalToMillis(player.currentItem?.currentDate()?.timeIntervalSince1970 ?? 0) }
    func duration() -> Int64 { var time: CMTime = player.currentItem?.duration ?? player.currentItem?.asset.duration ?? .zero; if !CMTIME_IS_INVALID(player.currentItem?.forwardPlaybackEndTime ?? .invalid) { time = player.currentItem!.forwardPlaybackEndTime }; return BetterPlayerTimeUtils.FLTCMTimeToMillis(time) }
    func seekTo(_ location: Int) { let wasPlaying = isPlaying; if wasPlaying { player.pause() }; player.seek(to: CMTimeMake(value: Int64(location), timescale: 1000), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in if wasPlaying { self?.player.rate = self?.playerRate ?? 1 } } }
    func setVolume(_ volume: Double) { player.volume = Float(max(0.0, min(1.0, volume))) }
    func setSpeed(_ speed: Double, result: FlutterResult) { if speed == 1.0 || speed == 0.0 { playerRate = 1; result(nil) } else if speed < 0 || speed > 2.0 { result(FlutterError(code: "unsupported_speed", message: "Speed must be >= 0.0 and <= 2.0", details: nil)) } else if (speed > 1.0 && player.currentItem?.canPlayFastForward == true) || (speed < 1.0 && player.currentItem?.canPlaySlowForward == true) { playerRate = Float(speed); result(nil) } else { if speed <= 1.0 { result(FlutterError(code: "unsupported_slow_forward", message: "This video cannot be played slow forward", details: nil)) } }; if isPlaying { if #available(iOS 16, *) { player.defaultRate = Float(speed) }; player.rate = Float(speed) } }
    func setTrackParameters(width: Int, height: Int, bitrate: Int) { player.currentItem?.preferredPeakBitRate = Double(bitrate); if #available(iOS 11.0, *) { player.currentItem?.preferredMaximumResolution = (width == 0 && height == 0) ? .zero : CGSize(width: width, height: height) } }

    // MARK: - PiP
    func setPictureInPicture(_ enabled: Bool) { pictureInPicture = enabled; if #available(iOS 9.0, *) { if let pip = pipController, enabled && !pip.isPictureInPictureActive { DispatchQueue.main.async { pip.startPictureInPicture() } } else if let pip = pipController, !enabled && pip.isPictureInPictureActive { DispatchQueue.main.async { pip.stopPictureInPicture() } } } }

    func setRestoreUserInterfaceForPIPStopCompletionHandler(_ restore: Bool) { restoreUserInterfaceForPIPStopCompletionHandler?(restore); restoreUserInterfaceForPIPStopCompletionHandler = nil }

    func setupPipController() { if #available(iOS 9.0, *) { try? AVAudioSession.sharedInstance().setActive(true); UIApplication.shared.beginReceivingRemoteControlEvents(); if pipController == nil, let layer = playerLayer, AVPictureInPictureController.isPictureInPictureSupported() { pipController = AVPictureInPictureController(playerLayer: layer); pipController?.delegate = self } } }

    func enablePictureInPicture(_ frame: CGRect) { disablePictureInPicture(); usePlayerLayer(frame) }

    private func usePlayerLayer(_ frame: CGRect) { guard true else { return }; playerLayer = AVPlayerLayer(player: player); let vc = UIApplication.shared.keyWindow?.rootViewController; playerLayer?.frame = frame; playerLayer?.needsDisplayOnBoundsChange = true; vc?.view.layer.addSublayer(playerLayer!); vc?.view.layer.needsDisplayOnBoundsChange = true; if #available(iOS 9.0, *) { pipController = nil }; setupPipController(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.setPictureInPicture(true) } }

    func disablePictureInPicture() { setPictureInPicture(true); if let layer = playerLayer { layer.removeFromSuperlayer(); playerLayer = nil; eventSink?(["event": "pipStop"]) } }

    // MARK: - Stream handler
    func onCancel(withArguments arguments: Any?) -> FlutterError? { eventSink = nil; return nil }
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? { eventSink = events; onReadyToPlay(); return nil }

    func disposeSansEventChannel() { clear() }
    func dispose() { pause(); disposeSansEventChannel(); eventChannel?.setStreamHandler(nil); disablePictureInPicture(); setPictureInPicture(false); disposed = true }
}

// MARK: - KVO context keys
private var timeRangeContext = 0
private var statusContext = 0
private var playbackLikelyToKeepUpContext = 0
private var playbackBufferEmptyContext = 0
private var playbackBufferFullContext = 0
private var presentationSizeContext = 0

// MARK: - PiP globals
#if os(iOS)
var restoreUserInterfaceForPIPStopCompletionHandler: ((Bool) -> Void)?
@available(iOS 9.0, *)
var pipController: AVPictureInPictureController?
#endif
