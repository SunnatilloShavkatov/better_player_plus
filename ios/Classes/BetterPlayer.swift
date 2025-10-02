// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation
import Flutter
import AVKit
import AVFoundation
import simd

class BetterPlayer: NSObject, FlutterPlatformView, FlutterStreamHandler, AVPictureInPictureControllerDelegate {
    
    // MARK: - Properties
    let player: AVPlayer
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
    private var observersAdded: Bool = false
    var stalledCount: Int = 0
    var isStalledCheckStarted: Bool = false
    var playerRate: Float = 1.0
    var overriddenDuration: Int = 0
    var lastAvPlayerTimeControlStatus: AVPlayer.TimeControlStatus = .paused
    
    // MARK: - Context Variables
    private static let timeRangeContext = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)
    private static let statusContext = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)
    private static let playbackLikelyToKeepUpContext = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)
    private static let playbackBufferEmptyContext = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)
    private static let playbackBufferFullContext = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)
    private static let presentationSizeContext = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)
    
    #if TARGET_OS_IOS
    private var restoreUserInterfaceForPIPStopCompletionHandler: ((Bool) -> Void)?
    @available(iOS 9.0, *)
    private var pipController: AVPictureInPictureController?
    #endif
    
    // MARK: - Initialization
    init(frame: CGRect) {
        isInitialized = false
        isPlaying = false
        disposed = false
        player = AVPlayer()
        player.actionAtItemEnd = .none
        
        // Fix for loading large videos
        if #available(iOS 10.0, *) {
            player.automaticallyWaitsToMinimizeStalling = false
        }
        
        observersAdded = false
        super.init()
    }
    
    // MARK: - FlutterPlatformView
    func view() -> UIView {
        let playerView = BetterPlayerView(frame: .zero)
        playerView.player = player
        return playerView
    }
    
    // MARK: - Observer Management
    private func addObservers(_ item: AVPlayerItem) {
        guard !observersAdded else { return }
        
        player.addObserver(self, forKeyPath: "rate", options: [], context: nil)
        item.addObserver(self, forKeyPath: "loadedTimeRanges", options: [], context: BetterPlayer.timeRangeContext)
        item.addObserver(self, forKeyPath: "status", options: [], context: BetterPlayer.statusContext)
        item.addObserver(self, forKeyPath: "presentationSize", options: [], context: BetterPlayer.presentationSizeContext)
        item.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: [], context: BetterPlayer.playbackLikelyToKeepUpContext)
        item.addObserver(self, forKeyPath: "playbackBufferEmpty", options: [], context: BetterPlayer.playbackBufferEmptyContext)
        item.addObserver(self, forKeyPath: "playbackBufferFull", options: [], context: BetterPlayer.playbackBufferFullContext)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(itemDidPlayToEndTime(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
        
        observersAdded = true
    }
    
    private func removeObservers() {
        guard observersAdded else { return }
        
        player.removeObserver(self, forKeyPath: "rate", context: nil)
        player.currentItem?.removeObserver(self, forKeyPath: "status", context: BetterPlayer.statusContext)
        player.currentItem?.removeObserver(self, forKeyPath: "presentationSize", context: BetterPlayer.presentationSizeContext)
        player.currentItem?.removeObserver(self, forKeyPath: "loadedTimeRanges", context: BetterPlayer.timeRangeContext)
        player.currentItem?.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp", context: BetterPlayer.playbackLikelyToKeepUpContext)
        player.currentItem?.removeObserver(self, forKeyPath: "playbackBufferEmpty", context: BetterPlayer.playbackBufferEmptyContext)
        player.currentItem?.removeObserver(self, forKeyPath: "playbackBufferFull", context: BetterPlayer.playbackBufferFullContext)
        
        NotificationCenter.default.removeObserver(self)
        observersAdded = false
    }
    
    // MARK: - Player Control Methods
    func play() {
        stalledCount = 0
        isStalledCheckStarted = false
        isPlaying = true
        updatePlayingState()
    }
    
    func pause() {
        isPlaying = false
        updatePlayingState()
    }
    
    func setIsLooping(_ isLooping: Bool) {
        self.isLooping = isLooping
    }
    
    func updatePlayingState() {
        guard isInitialized, let key = key else { return }
        
        if !observersAdded {
            addObservers(player.currentItem!)
        }
        
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
    
    // MARK: - Data Source Methods
    func setDataSourceAsset(_ asset: String, key: String, certificateUrl: String?, licenseUrl: String?, cacheKey: String?, cacheManager: CacheManager, overriddenDuration: Int) {
        guard let path = Bundle.main.path(forResource: asset, ofType: nil) else { return }
        let url = URL(fileURLWithPath: path)
        setDataSourceURL(url, key: key, certificateUrl: certificateUrl, licenseUrl: licenseUrl, headers: [:], useCache: false, cacheKey: cacheKey, cacheManager: cacheManager, overriddenDuration: overriddenDuration, videoExtension: nil)
    }
    
    func setDataSourceURL(_ url: URL, key: String, certificateUrl: String?, licenseUrl: String?, headers: [String: Any], useCache: Bool, cacheKey: String?, cacheManager: CacheManager, overriddenDuration: Int, videoExtension: String?) {
        overriddenDuration = 0
        
        let item: AVPlayerItem
        if useCache {
            item = cacheManager.getCachingPlayerItemForNormalPlayback(url, cacheKey: cacheKey, videoExtension: videoExtension, headers: headers)
        } else {
            let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
            
            if let certificateUrl = certificateUrl, !certificateUrl.isEmpty,
               let licenseUrl = licenseUrl, !licenseUrl.isEmpty {
                let certificateNSURL = URL(string: certificateUrl)!
                let licenseNSURL = URL(string: licenseUrl)!
                loaderDelegate = BetterPlayerEzDrmAssetsLoaderDelegate(certificateURL: certificateNSURL, licenseURL: licenseNSURL)
                
                let qos = DispatchQoS.default
                let streamQueue = DispatchQueue(label: "streamQueue", qos: qos)
                asset.resourceLoader.setDelegate(loaderDelegate, queue: streamQueue)
            }
            
            item = AVPlayerItem(asset: asset)
        }
        
        if #available(iOS 10.0, *), overriddenDuration > 0 {
            self.overriddenDuration = overriddenDuration
        }
        
        setDataSourcePlayerItem(item, key: key)
    }
    
    private func setDataSourcePlayerItem(_ item: AVPlayerItem, key: String) {
        self.key = key
        stalledCount = 0
        isStalledCheckStarted = false
        playerRate = 1.0
        player.replaceCurrentItem(with: item)
        
        let asset = item.asset
        asset.loadValuesAsynchronously(forKeys: ["tracks"]) {
            if asset.statusOfValue(forKey: "tracks", error: nil) == .loaded {
                let tracks = asset.tracks(withMediaType: .video)
                if !tracks.isEmpty {
                    let videoTrack = tracks[0]
                    videoTrack.loadValuesAsynchronously(forKeys: ["preferredTransform"]) {
                        if self.disposed { return }
                        if videoTrack.statusOfValue(forKey: "preferredTransform", error: nil) == .loaded {
                            self.preferredTransform = self.fixTransform(videoTrack)
                            let videoComposition = self.getVideoCompositionWithTransform(self.preferredTransform, asset: asset, videoTrack: videoTrack)
                            item.videoComposition = videoComposition
                        }
                    }
                }
            }
        }
        
        addObservers(item)
    }
    
    // MARK: - Utility Methods
    func clear() {
        isInitialized = false
        isPlaying = false
        disposed = false
        failedCount = 0
        key = nil
        
        guard let currentItem = player.currentItem else { return }
        
        removeObservers()
        let asset = currentItem.asset
        asset.cancelLoading()
    }
    
    func seekTo(_ location: Int) {
        let wasPlaying = isPlaying
        if wasPlaying {
            player.pause()
        }
        
        let time = CMTime(value: CMTimeValue(location), timescale: 1000)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
            if wasPlaying {
                self.player.rate = self.playerRate
            }
        }
    }
    
    func setVolume(_ volume: Double) {
        player.volume = Float(max(0.0, min(1.0, volume)))
    }
    
    func setSpeed(_ speed: Double, result: @escaping FlutterResult) {
        if speed == 1.0 || speed == 0.0 {
            playerRate = 1.0
            result(nil)
        } else if speed < 0 || speed > 2.0 {
            result(FlutterError(code: "unsupported_speed", message: "Speed must be >= 0.0 and <= 2.0", details: nil))
        } else if (speed > 1.0 && player.currentItem?.canPlayFastForward == true) ||
                  (speed < 1.0 && player.currentItem?.canPlaySlowForward == true) {
            playerRate = Float(speed)
            result(nil)
        } else {
            if speed <= 1.0 {
                result(FlutterError(code: "unsupported_slow_forward", message: "This video cannot be played slow forward", details: nil))
            }
        }
        
        if isPlaying {
            if #available(iOS 16, *) {
                player.defaultRate = Float(speed)
            }
            player.rate = Float(speed)
        }
    }
    
    func setTrackParameters(width: Int, height: Int, bitrate: Int) {
        player.currentItem?.preferredPeakBitRate = Double(bitrate)
        if #available(iOS 11.0, *) {
            if width == 0 && height == 0 {
                player.currentItem?.preferredMaximumResolution = .zero
            } else {
                player.currentItem?.preferredMaximumResolution = CGSize(width: width, height: height)
            }
        }
    }
    
    func setAudioTrack(name: String, index: Int) {
        guard let asset = player.currentItem?.asset,
              let audioSelectionGroup = asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else { return }
        
        let options = audioSelectionGroup.options
        for (audioTrackIndex, option) in options.enumerated() {
            let metaDatas = AVMetadataItem.metadataItems(from: option.commonMetadata, withKey: "title", keySpace: "comn")
            if !metaDatas.isEmpty {
                let title = metaDatas[0].stringValue
                if name == title && audioTrackIndex == index {
                    player.currentItem?.select(option, in: audioSelectionGroup)
                }
            }
        }
    }
    
    func setMixWithOthers(_ mixWithOthers: Bool) {
        do {
            if mixWithOthers {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
            } else {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            }
        } catch {
            print("Failed to set audio session category: \(error)")
        }
    }
    
    // MARK: - Position and Duration
    var position: Int64 {
        return BetterPlayerTimeUtils.fltCMTimeToMillis(player.currentTime())
    }
    
    var absolutePosition: Int64 {
        return BetterPlayerTimeUtils.fltNSTimeIntervalToMillis(player.currentItem?.currentDate().timeIntervalSince1970 ?? 0)
    }
    
    var duration: Int64 {
        let time: CMTime
        if #available(iOS 13, *) {
            time = player.currentItem?.duration ?? .zero
        } else {
            time = player.currentItem?.asset.duration ?? .zero
        }
        
        if let forwardPlaybackEndTime = player.currentItem?.forwardPlaybackEndTime, !forwardPlaybackEndTime.isInvalid {
            return BetterPlayerTimeUtils.fltCMTimeToMillis(forwardPlaybackEndTime)
        }
        
        return BetterPlayerTimeUtils.fltCMTimeToMillis(time)
    }
    
    // MARK: - Picture in Picture
    #if TARGET_OS_IOS
    func enablePictureInPicture(frame: CGRect) {
        disablePictureInPicture()
        usePlayerLayer(frame: frame)
    }
    
    private func usePlayerLayer(frame: CGRect) {
        guard let player = player else { return }
        
        playerLayer = AVPlayerLayer(player: player)
        guard let vc = UIApplication.shared.keyWindow?.rootViewController else { return }
        
        playerLayer?.frame = frame
        playerLayer?.needsDisplayOnBoundsChange = true
        vc.view.layer.addSublayer(playerLayer!)
        vc.view.layer.needsDisplayOnBoundsChange = true
        
        if #available(iOS 9.0, *) {
            pipController = nil
        }
        setupPipController()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.setPictureInPicture(true)
        }
    }
    
    func disablePictureInPicture() {
        setPictureInPicture(true)
        if let playerLayer = playerLayer {
            playerLayer.removeFromSuperlayer()
            self.playerLayer = nil
            eventSink?(["event": "pipStop"])
        }
    }
    
    func setPictureInPicture(_ pictureInPicture: Bool) {
        self.pictureInPicture = pictureInPicture
        if #available(iOS 9.0, *) {
            if let pipController = pipController, self.pictureInPicture && !pipController.isPictureInPictureActive {
                DispatchQueue.main.async {
                    pipController.startPictureInPicture()
                }
            } else if let pipController = pipController, !self.pictureInPicture && pipController.isPictureInPictureActive {
                DispatchQueue.main.async {
                    pipController.stopPictureInPicture()
                }
            }
        }
    }
    
    private func setupPipController() {
        if #available(iOS 9.0, *) {
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Failed to activate audio session: \(error)")
            }
            UIApplication.shared.beginReceivingRemoteControlEvents()
            
            if pipController == nil, let playerLayer = playerLayer, AVPictureInPictureController.isPictureInPictureSupported() {
                pipController = AVPictureInPictureController(playerLayer: playerLayer)
                pipController?.delegate = self
            }
        }
    }
    
    private func setRestoreUserInterfaceForPIPStopCompletionHandler(_ restore: Bool) {
        restoreUserInterfaceForPIPStopCompletionHandler?(restore)
        restoreUserInterfaceForPIPStopCompletionHandler = nil
    }
    
    // MARK: - AVPictureInPictureControllerDelegate
    @available(iOS 9.0, *)
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        disablePictureInPicture()
    }
    
    @available(iOS 9.0, *)
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        eventSink?(["event": "pipStart"])
    }
    
    @available(iOS 9.0, *)
    func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        // Implementation if needed
    }
    
    @available(iOS 9.0, *)
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        // Implementation if needed
    }
    
    @available(iOS 9.0, *)
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        // Implementation if needed
    }
    
    @available(iOS 9.0, *)
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        setRestoreUserInterfaceForPIPStopCompletionHandler(true)
    }
    #endif
    
    // MARK: - FlutterStreamHandler
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        onReadyToPlay()
        return nil
    }
    
    // MARK: - Disposal
    func disposeSansEventChannel() {
        do {
            clear()
        } catch {
            print("Error during clear: \(error)")
        }
    }
    
    func dispose() {
        pause()
        disposeSansEventChannel()
        eventChannel?.setStreamHandler(nil)
        #if TARGET_OS_IOS
        disablePictureInPicture()
        setPictureInPicture(false)
        #endif
        disposed = true
    }
    
    // MARK: - Helper Methods
    private func radiansToDegrees(_ radians: CGFloat) -> CGFloat {
        let degrees = radians * 180.0 / .pi
        if degrees < 0 {
            return degrees + 360
        }
        return degrees
    }
    
    private func getVideoCompositionWithTransform(_ transform: CGAffineTransform, asset: AVAsset, videoTrack: AVAssetTrack) -> AVMutableVideoComposition {
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
        
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        layerInstruction.setTransform(preferredTransform, at: .zero)
        
        let videoComposition = AVMutableVideoComposition()
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]
        
        var width = videoTrack.naturalSize.width
        var height = videoTrack.naturalSize.height
        let rotationDegrees = Int(round(radiansToDegrees(atan2(transform.b, transform.a))))
        
        if rotationDegrees == 90 || rotationDegrees == 270 {
            width = videoTrack.naturalSize.height
            height = videoTrack.naturalSize.width
        }
        
        videoComposition.renderSize = CGSize(width: width, height: height)
        
        let nominalFrameRate = videoTrack.nominalFrameRate
        let fps = nominalFrameRate > 0 ? Int(ceil(nominalFrameRate)) : 30
        videoComposition.frameDuration = CMTime(value: 1, timescale: Int32(fps))
        
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
    
    private func handleStalled() {
        guard !isStalledCheckStarted else { return }
        isStalledCheckStarted = true
        startStalledCheck()
    }
    
    private func startStalledCheck() {
        if player.currentItem?.isPlaybackLikelyToKeepUp == true ||
           availableDuration - CMTimeGetSeconds(player.currentItem?.currentTime() ?? .zero) > 10.0 {
            play()
        } else {
            stalledCount += 1
            if stalledCount > 60 {
                eventSink?(FlutterError(code: "VideoError", message: "Failed to load video: playback stalled", details: nil))
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.startStalledCheck()
            }
        }
    }
    
    private var availableDuration: TimeInterval {
        guard let loadedTimeRanges = player.currentItem?.loadedTimeRanges,
              !loadedTimeRanges.isEmpty else { return 0 }
        
        let timeRange = loadedTimeRanges[0].timeRangeValue
        let startSeconds = CMTimeGetSeconds(timeRange.start)
        let durationSeconds = CMTimeGetSeconds(timeRange.duration)
        return startSeconds + durationSeconds
    }
    
    private func onReadyToPlay() {
        guard let eventSink = eventSink, !isInitialized, let key = key else { return }
        guard let currentItem = player.currentItem else { return }
        guard player.status == .readyToPlay else { return }
        
        let size = currentItem.presentationSize
        let width = size.width
        let height = size.height
        
        let asset = currentItem.asset
        let onlyAudio = asset.tracks(withMediaType: .video).isEmpty
        
        if !onlyAudio && height == 0 && width == 0 {
            return
        }
        
        let isLive = currentItem.duration.isIndefinite
        if !isLive && duration == 0 {
            return
        }
        
        // Fix from https://github.com/flutter/flutter/issues/66413
        guard let track = player.currentItem?.tracks.first else { return }
        let naturalSize = track.assetTrack.naturalSize
        let prefTrans = track.assetTrack.preferredTransform
        let realSize = naturalSize.applying(prefTrans)
        
        let duration = BetterPlayerTimeUtils.fltCMTimeToMillis(currentItem.asset.duration)
        if overriddenDuration > 0 && duration > Int64(overriddenDuration) {
            currentItem.forwardPlaybackEndTime = CMTime(value: CMTimeValue(overriddenDuration), timescale: 1000)
        }
        
        isInitialized = true
        updatePlayingState()
        eventSink([
            "event": "initialized",
            "duration": duration,
            "width": abs(realSize.width) > 0 ? realSize.width : width,
            "height": abs(realSize.height) > 0 ? realSize.height : height,
            "key": key
        ])
    }
    
    @objc private func itemDidPlayToEndTime(_ notification: Notification) {
        if isLooping {
            if let item = notification.object as? AVPlayerItem {
                item.seek(to: .zero, completionHandler: nil)
            }
        } else {
            eventSink?(["event": "completed", "key": key])
            removeObservers()
        }
    }
    
    // MARK: - KVO Observer
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if keyPath == "rate" {
            if #available(iOS 10.0, *) {
                if let pipController = pipController, pipController.isPictureInPictureActive {
                    if lastAvPlayerTimeControlStatus != .unknown && lastAvPlayerTimeControlStatus == player.timeControlStatus {
                        return
                    }
                    
                    if player.timeControlStatus == .paused {
                        lastAvPlayerTimeControlStatus = player.timeControlStatus
                        eventSink?(["event": "pause"])
                        return
                    }
                    
                    if player.timeControlStatus == .playing {
                        lastAvPlayerTimeControlStatus = player.timeControlStatus
                        eventSink?(["event": "play"])
                    }
                }
            }
            
            if player.rate == 0 &&
               CMTimeCompare(player.currentItem?.currentTime() ?? .zero, .zero) > 0 &&
               CMTimeCompare(player.currentItem?.currentTime() ?? .zero, player.currentItem?.duration ?? .zero) < 0 &&
               isPlaying {
                handleStalled()
            }
        }
        
        if context == BetterPlayer.timeRangeContext {
            if let eventSink = eventSink {
                var values: [[Int64]] = []
                if let item = object as? AVPlayerItem {
                    for rangeValue in item.loadedTimeRanges {
                        let range = rangeValue.timeRangeValue
                        let start = BetterPlayerTimeUtils.fltCMTimeToMillis(range.start)
                        var end = start + BetterPlayerTimeUtils.fltCMTimeToMillis(range.duration)
                        
                        if let forwardPlaybackEndTime = player.currentItem?.forwardPlaybackEndTime, !forwardPlaybackEndTime.isInvalid {
                            let endTime = BetterPlayerTimeUtils.fltCMTimeToMillis(forwardPlaybackEndTime)
                            if end > endTime {
                                end = endTime
                            }
                        }
                        
                        values.append([start, end])
                    }
                }
                eventSink(["event": "bufferingUpdate", "values": values, "key": key])
            }
        } else if context == BetterPlayer.presentationSizeContext {
            onReadyToPlay()
        } else if context == BetterPlayer.statusContext {
            if let item = object as? AVPlayerItem {
                switch item.status {
                case .failed:
                    print("Failed to load video: \(item.error?.localizedDescription ?? "Unknown error")")
                    eventSink?(FlutterError(code: "VideoError", message: "Failed to load video: \(item.error?.localizedDescription ?? "Unknown error")", details: nil))
                case .unknown:
                    break
                case .readyToPlay:
                    onReadyToPlay()
                @unknown default:
                    break
                }
            }
        } else if context == BetterPlayer.playbackLikelyToKeepUpContext {
            if player.currentItem?.isPlaybackLikelyToKeepUp == true {
                updatePlayingState()
                eventSink?(["event": "bufferingEnd", "key": key])
            }
        } else if context == BetterPlayer.playbackBufferEmptyContext {
            eventSink?(["event": "bufferingStart", "key": key])
        } else if context == BetterPlayer.playbackBufferFullContext {
            eventSink?(["event": "bufferingEnd", "key": key])
        }
    }
}