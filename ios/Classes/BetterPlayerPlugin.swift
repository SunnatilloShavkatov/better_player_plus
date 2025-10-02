// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation
import Flutter
import AVKit
import AVFoundation
import simd
import MediaPlayer

class BetterPlayerPlugin: NSObject, FlutterPlugin, FlutterPlatformViewFactory {
    
    // MARK: - Properties
    weak var messenger: FlutterBinaryMessenger?
    var players: [Int64: BetterPlayer] = [:]
    var registrar: FlutterPluginRegistrar?
    
    // MARK: - Private Properties
    private var dataSourceDict: [String: [String: Any]] = [:]
    private var timeObserverIdDict: [String: Any] = [:]
    private var artworkImageDict: [String: MPMediaItemArtwork] = [:]
    private var cacheManager: CacheManager
    private var texturesCount: Int = -1
    private var notificationPlayer: BetterPlayer?
    private var remoteCommandsInitialized: Bool = false
    
    // MARK: - Initialization
    override init() {
        cacheManager = CacheManager()
        cacheManager.setup()
        super.init()
    }
    
    // MARK: - FlutterPlugin Protocol
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "better_player_channel", binaryMessenger: registrar.messenger())
        let instance = BetterPlayerPlugin()
        instance.messenger = registrar.messenger()
        instance.registrar = registrar
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.registerViewFactory(instance, withId: "com.jhomlala/better_player")
    }
    
    func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        for (_, player) in players {
            player.disposeSansEventChannel()
        }
        players.removeAll()
    }
    
    // MARK: - FlutterPlatformViewFactory Protocol
    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        guard let args = args as? [String: Any],
              let textureId = args["textureId"] as? Int64 else {
            fatalError("Invalid arguments")
        }
        return players[textureId]!
    }
    
    func createArgsCodec() -> FlutterMessageCodec {
        return FlutterStandardMessageCodec.sharedInstance()
    }
    
    // MARK: - Helper Methods
    private func newTextureId() -> Int64 {
        texturesCount += 1
        return Int64(texturesCount)
    }
    
    private func onPlayerSetup(_ player: BetterPlayer, result: @escaping FlutterResult) {
        let textureId = newTextureId()
        let eventChannel = FlutterEventChannel(
            name: "better_player_channel/videoEvents\(textureId)",
            binaryMessenger: messenger!
        )
        player.setMixWithOthers(false)
        eventChannel.setStreamHandler(player)
        player.eventChannel = eventChannel
        players[textureId] = player
        result(["textureId": textureId])
    }
    
    private func setupRemoteNotification(_ player: BetterPlayer) {
        notificationPlayer = player
        stopOtherUpdateListener(player)
        
        guard let textureId = getTextureId(player),
              let dataSource = dataSourceDict[textureId] else { return }
        
        let showNotification = dataSource["showNotification"] as? Bool ?? false
        let title = dataSource["title"] as? String ?? ""
        let author = dataSource["author"] as? String ?? ""
        let imageUrl = dataSource["imageUrl"] as? String ?? ""
        
        if showNotification {
            setRemoteCommandsNotificationActive()
            setupRemoteCommands(player)
            setupRemoteCommandNotification(player, title: title, author: author, imageUrl: imageUrl)
            setupUpdateListener(player, title: title, author: author, imageUrl: imageUrl)
        }
    }
    
    private func setRemoteCommandsNotificationActive() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to activate audio session: \(error)")
        }
        UIApplication.shared.beginReceivingRemoteControlEvents()
    }
    
    private func setRemoteCommandsNotificationNotActive() {
        if players.isEmpty {
            do {
                try AVAudioSession.sharedInstance().setActive(false)
            } catch {
                print("Failed to deactivate audio session: \(error)")
            }
        }
        UIApplication.shared.endReceivingRemoteControlEvents()
    }
    
    private func setupRemoteCommands(_ player: BetterPlayer) {
        guard !remoteCommandsInitialized else { return }
        
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
        
        if #available(iOS 9.1, *) {
            commandCenter.changePlaybackPositionCommand.isEnabled = true
        }
        
        commandCenter.togglePlayPauseCommand.addTarget { event in
            if let notificationPlayer = self.notificationPlayer {
                if notificationPlayer.isPlaying {
                    notificationPlayer.eventSink?(["event": "play"])
                } else {
                    notificationPlayer.eventSink?(["event": "pause"])
                }
            }
            return .success
        }
        
        commandCenter.playCommand.addTarget { event in
            if let notificationPlayer = self.notificationPlayer {
                notificationPlayer.eventSink?(["event": "play"])
            }
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { event in
            if let notificationPlayer = self.notificationPlayer {
                notificationPlayer.eventSink?(["event": "pause"])
            }
            return .success
        }
        
        if #available(iOS 9.1, *) {
            commandCenter.changePlaybackPositionCommand.addTarget { event in
                if let notificationPlayer = self.notificationPlayer,
                   let playbackEvent = event as? MPChangePlaybackPositionCommandEvent {
                    let time = CMTime(value: CMTimeValue(playbackEvent.positionTime), timescale: 1)
                    let millis = BetterPlayerTimeUtils.fltCMTimeToMillis(time)
                    notificationPlayer.seekTo(Int(millis))
                    notificationPlayer.eventSink?(["event": "seek", "position": millis])
                }
                return .success
            }
        }
        
        remoteCommandsInitialized = true
    }
    
    private func setupRemoteCommandNotification(_ player: BetterPlayer, title: String, author: String, imageUrl: String) {
        let positionInSeconds = Float(player.position) / 1000
        let durationInSeconds = Float(player.duration) / 1000
        
        var nowPlayingInfoDict: [String: Any] = [
            MPMediaItemPropertyArtist: author,
            MPMediaItemPropertyTitle: title,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: positionInSeconds,
            MPMediaItemPropertyPlaybackDuration: durationInSeconds,
            MPNowPlayingInfoPropertyPlaybackRate: 1
        ]
        
        if !imageUrl.isEmpty {
            let key = getTextureId(player)
            if let artworkImage = artworkImageDict[key] {
                nowPlayingInfoDict[MPMediaItemPropertyArtwork] = artworkImage
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfoDict
            } else {
                DispatchQueue.global(qos: .default).async {
                    do {
                        var tempArtworkImage: UIImage?
                        if !imageUrl.contains("http") {
                            tempArtworkImage = UIImage(contentsOfFile: imageUrl)
                        } else {
                            if let nsImageUrl = URL(string: imageUrl),
                               let imageData = try? Data(contentsOf: nsImageUrl) {
                                tempArtworkImage = UIImage(data: imageData)
                            }
                        }
                        
                        if let tempArtworkImage = tempArtworkImage {
                            let artworkImage = MPMediaItemArtwork(boundsSize: tempArtworkImage.size) { _ in tempArtworkImage }
                            self.artworkImageDict[key] = artworkImage
                            nowPlayingInfoDict[MPMediaItemPropertyArtwork] = artworkImage
                        }
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfoDict
                    } catch {
                        print("Error loading artwork image: \(error)")
                    }
                }
            }
        } else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfoDict
        }
    }
    
    private func getTextureId(_ player: BetterPlayer) -> String {
        for (textureId, p) in players {
            if p === player {
                return String(textureId)
            }
        }
        return ""
    }
    
    private func setupUpdateListener(_ player: BetterPlayer, title: String, author: String, imageUrl: String) {
        let timeObserverId = player.player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 1), queue: nil) { _ in
            self.setupRemoteCommandNotification(player, title: title, author: author, imageUrl: imageUrl)
        }
        
        let key = getTextureId(player)
        timeObserverIdDict[key] = timeObserverId
    }
    
    private func disposeNotificationData(_ player: BetterPlayer) {
        if player === notificationPlayer {
            notificationPlayer = nil
            remoteCommandsInitialized = false
        }
        
        let key = getTextureId(player)
        if let timeObserverId = timeObserverIdDict[key] {
            player.player.removeTimeObserver(timeObserverId)
            timeObserverIdDict.removeValue(forKey: key)
        }
        artworkImageDict.removeValue(forKey: key)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [:]
    }
    
    private func stopOtherUpdateListener(_ player: BetterPlayer) {
        let currentPlayerTextureId = getTextureId(player)
        for (textureId, timeObserverId) in timeObserverIdDict {
            if currentPlayerTextureId == textureId {
                continue
            }
            
            if let playerToRemoveListener = players[Int64(textureId) ?? 0] {
                playerToRemoveListener.player.removeTimeObserver(timeObserverId)
            }
        }
        timeObserverIdDict.removeAll()
    }
    
    // MARK: - FlutterMethodCallDelegate
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "init":
            for (_, player) in players {
                player.dispose()
            }
            players.removeAll()
            result(nil)
            
        case "create":
            let player = BetterPlayer(frame: .zero)
            onPlayerSetup(player, result: result)
            
        default:
            guard let argsMap = call.arguments as? [String: Any],
                  let textureId = argsMap["textureId"] as? Int64,
                  let player = players[textureId] else {
                result(FlutterMethodNotImplemented())
                return
            }
            
            handlePlayerMethod(call, player: player, result: result)
        }
    }
    
    private func handlePlayerMethod(_ call: FlutterMethodCall, player: BetterPlayer, result: @escaping FlutterResult) {
        guard let argsMap = call.arguments as? [String: Any] else {
            result(FlutterMethodNotImplemented())
            return
        }
        
        switch call.method {
        case "setDataSource":
            player.clear()
            
            guard let dataSource = argsMap["dataSource"] as? [String: Any] else {
                result(FlutterMethodNotImplemented())
                return
            }
            
            let textureId = getTextureId(player)
            dataSourceDict[textureId] = dataSource
            
            let assetArg = dataSource["asset"] as? String
            let uriArg = dataSource["uri"] as? String
            let key = dataSource["key"] as? String ?? ""
            let certificateUrl = dataSource["certificateUrl"] as? String
            let licenseUrl = dataSource["licenseUrl"] as? String
            let headers = dataSource["headers"] as? [String: Any] ?? [:]
            let cacheKey = dataSource["cacheKey"] as? String
            let maxCacheSize = dataSource["maxCacheSize"] as? NSNumber
            let videoExtension = dataSource["videoExtension"] as? String
            
            let overriddenDuration = dataSource["overriddenDuration"] as? Int ?? 0
            let useCache = dataSource["useCache"] as? Bool ?? false
            
            if useCache {
                cacheManager.setMaxCacheSize(maxCacheSize)
            }
            
            if let assetArg = assetArg {
                let package = dataSource["package"] as? String
                let assetPath: String
                if let package = package {
                    assetPath = registrar!.lookupKey(forAsset: assetArg, fromPackage: package)
                } else {
                    assetPath = registrar!.lookupKey(forAsset: assetArg)
                }
                player.setDataSourceAsset(assetPath, key: key, certificateUrl: certificateUrl, licenseUrl: licenseUrl, cacheKey: cacheKey, cacheManager: cacheManager, overriddenDuration: overriddenDuration)
            } else if let uriArg = uriArg {
                let url = URL(string: uriArg)!
                player.setDataSourceURL(url, key: key, certificateUrl: certificateUrl, licenseUrl: licenseUrl, headers: headers, useCache: useCache, cacheKey: cacheKey, cacheManager: cacheManager, overriddenDuration: overriddenDuration, videoExtension: videoExtension)
            } else {
                result(FlutterMethodNotImplemented())
                return
            }
            result(nil)
            
        case "dispose":
            player.clear()
            disposeNotificationData(player)
            setRemoteCommandsNotificationNotActive()
            players.removeValue(forKey: getTextureId(player).isEmpty ? 0 : Int64(getTextureId(player)) ?? 0)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if !player.disposed {
                    player.dispose()
                }
            }
            
            if players.isEmpty {
                do {
                    try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                } catch {
                    print("Failed to deactivate audio session: \(error)")
                }
            }
            result(nil)
            
        case "setLooping":
            let looping = argsMap["looping"] as? Bool ?? false
            player.setIsLooping(looping)
            result(nil)
            
        case "setVolume":
            let volume = argsMap["volume"] as? Double ?? 0.0
            player.setVolume(volume)
            result(nil)
            
        case "play":
            setupRemoteNotification(player)
            player.play()
            result(nil)
            
        case "position":
            result(player.position)
            
        case "absolutePosition":
            result(player.absolutePosition)
            
        case "seekTo":
            let location = argsMap["location"] as? Int ?? 0
            player.seekTo(location)
            result(nil)
            
        case "pause":
            player.pause()
            result(nil)
            
        case "setSpeed":
            let speed = argsMap["speed"] as? Double ?? 1.0
            player.setSpeed(speed, result: result)
            
        case "setTrackParameters":
            let width = argsMap["width"] as? Int ?? 0
            let height = argsMap["height"] as? Int ?? 0
            let bitrate = argsMap["bitrate"] as? Int ?? 0
            player.setTrackParameters(width: width, height: height, bitrate: bitrate)
            result(nil)
            
        case "enablePictureInPicture":
            let left = argsMap["left"] as? Double ?? 0
            let top = argsMap["top"] as? Double ?? 0
            let width = argsMap["width"] as? Double ?? 0
            let height = argsMap["height"] as? Double ?? 0
            #if TARGET_OS_IOS
            player.enablePictureInPicture(frame: CGRect(x: left, y: top, width: width, height: height))
            #endif
            result(nil)
            
        case "isPictureInPictureSupported":
            #if TARGET_OS_IOS
            if #available(iOS 9.0, *) {
                result(AVPictureInPictureController.isPictureInPictureSupported())
            } else {
                result(false)
            }
            #else
            result(false)
            #endif
            
        case "disablePictureInPicture":
            #if TARGET_OS_IOS
            player.disablePictureInPicture()
            player.setPictureInPicture(false)
            #endif
            result(nil)
            
        case "setAudioTrack":
            let name = argsMap["name"] as? String ?? ""
            let index = argsMap["index"] as? Int ?? 0
            player.setAudioTrack(name: name, index: index)
            result(nil)
            
        case "setMixWithOthers":
            let mixWithOthers = argsMap["mixWithOthers"] as? Bool ?? false
            player.setMixWithOthers(mixWithOthers)
            result(nil)
            
        case "preCache":
            guard let dataSource = argsMap["dataSource"] as? [String: Any] else {
                result(FlutterMethodNotImplemented())
                return
            }
            
            let urlArg = dataSource["uri"] as? String
            let cacheKey = dataSource["cacheKey"] as? String
            let headers = dataSource["headers"] as? [String: Any] ?? [:]
            let maxCacheSize = dataSource["maxCacheSize"] as? NSNumber
            let videoExtension = dataSource["videoExtension"] as? String
            
            if let urlArg = urlArg {
                let url = URL(string: urlArg)!
                if cacheManager.isPreCacheSupportedWithUrl(url, videoExtension: videoExtension) {
                    cacheManager.setMaxCacheSize(maxCacheSize)
                    cacheManager.preCacheURL(url, cacheKey: cacheKey, videoExtension: videoExtension, withHeaders: headers) { success in
                        // Completion handler
                    }
                } else {
                    print("Pre cache is not supported for given data source.")
                }
            }
            result(nil)
            
        case "clearCache":
            cacheManager.clearCache()
            result(nil)
            
        case "stopPreCache":
            let urlArg = argsMap["url"] as? String
            let cacheKey = argsMap["cacheKey"] as? String
            let videoExtension = argsMap["videoExtension"] as? String
            
            if let urlArg = urlArg {
                let url = URL(string: urlArg)!
                if cacheManager.isPreCacheSupportedWithUrl(url, videoExtension: videoExtension) {
                    cacheManager.stopPreCache(url, cacheKey: cacheKey) { success in
                        // Completion handler
                    }
                } else {
                    print("Stop pre cache is not supported for given data source.")
                }
            }
            result(nil)
            
        default:
            result(FlutterMethodNotImplemented())
        }
    }
}