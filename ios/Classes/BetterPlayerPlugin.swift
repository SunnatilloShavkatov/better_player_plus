import Foundation
import Flutter
import AVFoundation
import MediaPlayer
import UIKit

@objc(BetterPlayerPlugin)
public class BetterPlayerPlugin: NSObject, FlutterPlugin, FlutterPlatformViewFactory {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "better_player_channel", binaryMessenger: registrar.messenger())
        let instance = BetterPlayerPlugin(registrar: registrar)
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.register(instance, withId: "com.jhomlala/better_player")
    }

    public let messenger: FlutterBinaryMessenger
    public var players: [Int64: BetterPlayer] = [:]
    public let registrar: FlutterPluginRegistrar

    private var dataSourceDict: [String: [String: Any]] = [:]
    private var timeObserverIdDict: [String: Any] = [:]
    private var artworkImageDict: [String: MPMediaItemArtwork] = [:]
    private var cacheManager: CacheManager = CacheManager()
    private var texturesCount: Int64 = -1
    private var notificationPlayer: BetterPlayer?
    private var remoteCommandsInitialized = false

    init(registrar: FlutterPluginRegistrar) {
        self.messenger = registrar.messenger()
        self.registrar = registrar
        super.init()
        cacheManager.setup()
    }

    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        for (_, player) in players { player.disposeSansEventChannel() }
        players.removeAll()
    }

    // MARK: FlutterPlatformViewFactory
    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }

    public func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView? {
        guard let dict = args as? [String: Any], let textureId = dict["textureId"] as? NSNumber else { return nil }
        return players[textureId.int64Value]
    }

    // MARK: Helpers
    private func newTextureId() -> Int64 { texturesCount += 1; return texturesCount }

    private func onPlayerSetup(_ player: BetterPlayer, result: FlutterResult) {
        let textureId = newTextureId()
        let eventChannel = FlutterEventChannel(name: "better_player_channel/videoEvents\(textureId)", binaryMessenger: messenger)
        player.setMixWithOthers(false)
        eventChannel.setStreamHandler(player)
        player.eventChannel = eventChannel
        players[textureId] = player
        result(["textureId": NSNumber(value: textureId)])
    }

    private func setupRemoteCommandsNotificationActive() {
        try? AVAudioSession.sharedInstance().setActive(true)
        UIApplication.shared.beginReceivingRemoteControlEvents()
    }

    private func setRemoteCommandsNotificationNotActive() {
        if players.isEmpty {
            try? AVAudioSession.sharedInstance().setActive(false)
        }
        UIApplication.shared.endReceivingRemoteControlEvents()
    }

    private func getTextureId(_ player: BetterPlayer) -> String? {
        return players.first(where: { $0.value === player })?.key.description
    }

    private func setupRemoteCommands(_ player: BetterPlayer) {
        if remoteCommandsInitialized { return }
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
        if #available(iOS 9.1, *) {
            commandCenter.changePlaybackPositionCommand.isEnabled = true
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self, let nPlayer = self.notificationPlayer else { return .success }
            if nPlayer.isPlaying {
                nPlayer.eventSink?(["event": "play"]) 
            } else {
                nPlayer.eventSink?(["event": "pause"]) 
            }
            return .success
        }

        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.notificationPlayer?.eventSink?(["event": "play"]) 
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.notificationPlayer?.eventSink?(["event": "pause"]) 
            return .success
        }

        if #available(iOS 9.1, *) {
            commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
                guard let self, let nPlayer = self.notificationPlayer else { return .success }
                if let playbackEvent = event as? MPChangePlaybackPositionCommandEvent {
                    let time = CMTimeMakeWithSeconds(playbackEvent.positionTime, preferredTimescale: 1)
                    let millis = BetterPlayerTimeUtils.FLTCMTimeToMillis(time)
                    nPlayer.seekTo(Int(millis))
                    nPlayer.eventSink?(["event": "seek", "position": NSNumber(value: millis)])
                }
                return .success
            }
        }
        remoteCommandsInitialized = true
    }

    private func setupRemoteCommandNotification(_ player: BetterPlayer, title: String?, author: String?, imageUrl: String?) {
        let positionInSeconds = Double(player.position()) / 1000.0
        let durationInSeconds = Double(player.duration()) / 1000.0
        var nowPlaying: [String: Any] = [
            MPMediaItemPropertyArtist: author ?? "",
            MPMediaItemPropertyTitle: title ?? "",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: NSNumber(value: positionInSeconds),
            MPMediaItemPropertyPlaybackDuration: NSNumber(value: durationInSeconds),
            MPNowPlayingInfoPropertyPlaybackRate: NSNumber(value: 1)
        ]

        if let imageUrl, !imageUrl.isEmpty {
            if let key = getTextureId(player) {
                if let artworkImage = artworkImageDict[key] {
                    nowPlaying[MPMediaItemPropertyArtwork] = artworkImage
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlaying
                } else {
                    DispatchQueue.global(qos: .default).async { [weak self] in
                        guard let self else { return }
                        var tempImage: UIImage?
                        if imageUrl.contains("http") {
                            if let url = URL(string: imageUrl), let data = try? Data(contentsOf: url) { tempImage = UIImage(data: data) }
                        } else {
                            tempImage = UIImage(contentsOfFile: imageUrl)
                        }
                        if let tempImage {
                            let artwork = MPMediaItemArtwork(boundsSize: tempImage.size) { _ in tempImage }
                            self.artworkImageDict[key] = artwork
                            nowPlaying[MPMediaItemPropertyArtwork] = artwork
                        }
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlaying
                    }
                }
            }
        } else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlaying
        }
    }

    private func setupUpdateListener(_ player: BetterPlayer, title: String?, author: String?, imageUrl: String?) {
        let timeObserver = player.player.addPeriodicTimeObserver(forInterval: CMTimeMake(value: 1, timescale: 1), queue: nil) { [weak self] _ in
            self?.setupRemoteCommandNotification(player, title: title, author: author, imageUrl: imageUrl)
        }
        if let key = getTextureId(player) { timeObserverIdDict[key] = timeObserver }
    }

    private func disposeNotificationData(_ player: BetterPlayer) {
        if notificationPlayer === player { notificationPlayer = nil; remoteCommandsInitialized = false }
        if let key = getTextureId(player) {
            if let timeObserver = timeObserverIdDict[key] {
                player.player.removeTimeObserver(timeObserver)
            }
            timeObserverIdDict.removeValue(forKey: key)
            artworkImageDict.removeValue(forKey: key)
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [:]
    }

    private func stopOtherUpdateListener(_ player: BetterPlayer) {
        let currentPlayerTextureId = getTextureId(player)
        for (textureId, timeObserver) in timeObserverIdDict {
            if textureId == currentPlayerTextureId { continue }
            if let playerToRemoveListener = players[Int64(textureId) ?? -1] { // textureId is string key
                playerToRemoveListener.player.removeTimeObserver(timeObserver)
            }
        }
        timeObserverIdDict.removeAll()
    }
}

extension BetterPlayerPlugin {
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "init" {
            for (_, player) in players { player.dispose() }
            players.removeAll()
            result(nil)
            return
        } else if call.method == "create" {
            let player = BetterPlayer()
            onPlayerSetup(player, result: result)
            return
        }

        guard let args = call.arguments as? [String: Any], let textureId = (args["textureId"] as? NSNumber)?.int64Value, let player = players[textureId] else {
            result(FlutterMethodNotImplemented)
            return
        }

        switch call.method {
        case "setDataSource":
            player.clear()
            if let dataSource = args["dataSource"] as? [String: Any] {
                if let key = getTextureId(player) { dataSourceDict[key] = dataSource }
                let assetArg = dataSource["asset"] as? String
                let uriArg = dataSource["uri"] as? String
                let key = dataSource["key"] as? String
                let certificateUrl = dataSource["certificateUrl"] as? String
                let licenseUrl = dataSource["licenseUrl"] as? String
                let headers = (dataSource["headers"] as? [String: Any]) ?? [:]
                let cacheKey = dataSource["cacheKey"] as? String
                let maxCacheSize = dataSource["maxCacheSize"] as? NSNumber
                let videoExtension = dataSource["videoExtension"] as? String
                var overriddenDuration: Int = 0
                if let overrideDurationObj = dataSource["overriddenDuration"], !(overrideDurationObj is NSNull) {
                    overriddenDuration = (overrideDurationObj as? NSNumber)?.intValue ?? 0
                }

                var useCache = false
                if let useCacheObj = dataSource["useCache"], !(useCacheObj is NSNull) {
                    useCache = (useCacheObj as? NSNumber)?.boolValue ?? false
                    if useCache, let maxCacheSize { cacheManager.setMaxCacheSize(maxCacheSize) }
                }

                if let asset = assetArg {
                    let assetPath: String
                    if let package = dataSource["package"] as? String, !(package is NSNull) {
                        assetPath = registrar.lookupKey(forAsset: asset, fromPackage: package)
                    } else {
                        assetPath = registrar.lookupKey(forAsset: asset)
                    }
                    player.setDataSourceAsset(assetPath, withKey: key, withCertificateUrl: certificateUrl, withLicenseUrl: licenseUrl, cacheKey: cacheKey, cacheManager: cacheManager, overriddenDuration: overriddenDuration)
                } else if let uri = uriArg, let url = URL(string: uri) {
                    player.setDataSourceURL(url, withKey: key, withCertificateUrl: certificateUrl, withLicenseUrl: licenseUrl, withHeaders: headers, withCache: useCache, cacheKey: cacheKey, cacheManager: cacheManager, overriddenDuration: overriddenDuration, videoExtension: videoExtension)
                } else {
                    result(FlutterMethodNotImplemented)
                }
            }
            result(nil)
        case "dispose":
            player.clear()
            disposeNotificationData(player)
            setRemoteCommandsNotificationNotActive()
            players.removeValue(forKey: textureId)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if !player.disposed { player.dispose() }
            }
            if players.isEmpty {
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }
            result(nil)
        case "setLooping":
            player.setIsLooping((args["looping"] as? NSNumber)?.boolValue ?? false)
            result(nil)
        case "setVolume":
            player.setVolume((args["volume"] as? NSNumber)?.doubleValue ?? 1.0)
            result(nil)
        case "play":
            setupRemoteNotification(player)
            player.play()
            result(nil)
        case "position":
            result(NSNumber(value: player.position()))
        case "absolutePosition":
            result(NSNumber(value: player.absolutePosition()))
        case "seekTo":
            player.seekTo((args["location"] as? NSNumber)?.intValue ?? 0)
            result(nil)
        case "pause":
            player.pause()
            result(nil)
        case "setSpeed":
            player.setSpeed((args["speed"] as? NSNumber)?.doubleValue ?? 1.0, result: result)
        case "setTrackParameters":
            let width = (args["width"] as? NSNumber)?.intValue ?? 0
            let height = (args["height"] as? NSNumber)?.intValue ?? 0
            let bitrate = (args["bitrate"] as? NSNumber)?.intValue ?? 0
            player.setTrackParameters(width, height, bitrate)
            result(nil)
        case "enablePictureInPicture":
            let left = (args["left"] as? NSNumber)?.doubleValue ?? 0
            let top = (args["top"] as? NSNumber)?.doubleValue ?? 0
            let width = (args["width"] as? NSNumber)?.doubleValue ?? 0
            let height = (args["height"] as? NSNumber)?.doubleValue ?? 0
            player.enablePictureInPicture(CGRect(x: left, y: top, width: width, height: height))
            result(nil)
        case "isPictureInPictureSupported":
            if #available(iOS 9.0, *) {
                result(NSNumber(value: AVPictureInPictureController.isPictureInPictureSupported()))
            } else {
                result(NSNumber(value: false))
            }
        case "disablePictureInPicture":
            player.disablePictureInPicture()
            player.setPictureInPicture(false)
            result(nil)
        case "setAudioTrack":
            let name = args["name"] as? String ?? ""
            let index = (args["index"] as? NSNumber)?.intValue ?? 0
            player.setAudioTrack(name, index: index)
            result(nil)
        case "setMixWithOthers":
            player.setMixWithOthers((args["mixWithOthers"] as? NSNumber)?.boolValue ?? false)
            result(nil)
        case "preCache":
            guard let dataSource = args["dataSource"] as? [String: Any] else { result(nil); return }
            let urlArg = dataSource["uri"] as? String
            let cacheKey = dataSource["cacheKey"] as? String
            let headers = (dataSource["headers"] as? [String: Any]) ?? [:]
            let maxCacheSize = dataSource["maxCacheSize"] as? NSNumber
            let videoExtension = dataSource["videoExtension"] as? String
            if let urlArg, let url = URL(string: urlArg) {
                if cacheManager.isPreCacheSupported(url: url, videoExtension: videoExtension) {
                    if let maxCacheSize { cacheManager.setMaxCacheSize(maxCacheSize) }
                    cacheManager.preCacheURL(url, cacheKey: cacheKey, videoExtension: videoExtension, withHeaders: headers as [NSObject : AnyObject]) { _ in }
                } else {
                    NSLog("Pre cache is not supported for given data source.")
                }
            }
            result(nil)
        case "clearCache":
            cacheManager.clearCache()
            result(nil)
        case "stopPreCache":
            let urlArg = args["url"] as? String
            let cacheKey = args["cacheKey"] as? String
            let videoExtension = args["videoExtension"] as? String
            if let urlArg, let url = URL(string: urlArg) {
                if cacheManager.isPreCacheSupported(url: url, videoExtension: videoExtension) {
                    cacheManager.stopPreCache(url, cacheKey: cacheKey) { _ in }
                } else {
                    NSLog("Stop pre cache is not supported for given data source.")
                }
            }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func setupRemoteNotification(_ player: BetterPlayer) {
        notificationPlayer = player
        stopOtherUpdateListener(player)
        guard let key = getTextureId(player), let dataSource = dataSourceDict[key] else { return }
        let showNotification = (dataSource["showNotification"] as? NSNumber)?.boolValue ?? false
        let title = dataSource["title"] as? String
        let author = dataSource["author"] as? String
        let imageUrl = dataSource["imageUrl"] as? String
        if showNotification {
            setupRemoteCommandsNotificationActive()
            setupRemoteCommands(player)
            setupRemoteCommandNotification(player, title: title, author: author, imageUrl: imageUrl)
            setupUpdateListener(player, title: title, author: author, imageUrl: imageUrl)
        }
    }
}
