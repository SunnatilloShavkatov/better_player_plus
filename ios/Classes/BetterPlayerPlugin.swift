import Foundation
import Flutter
import AVFoundation
import AVKit
import MediaPlayer
import UIKit

public class BetterPlayerPlugin: NSObject, FlutterPlugin, FlutterPlatformViewFactory {
    private weak var messenger: FlutterBinaryMessenger?
    private var players: [Int64: BetterPlayer] = [:]
    private var registrar: FlutterPluginRegistrar?

    private var dataSourceDict: [String: [String: Any]] = [:]
    private var timeObserverIdDict: [String: Any] = [:]
    private var artworkImageDict: [String: MPMediaItemArtwork] = [:]
    private var cacheManager: CacheManager = CacheManager()
    private var texturesCount: Int64 = -1
    private var notificationPlayer: BetterPlayer?
    private var remoteCommandsInitialized: Bool = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "better_player_channel", binaryMessenger: registrar.messenger())
        let instance = BetterPlayerPlugin(registrar: registrar)
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.register(instance, withId: "com.jhomlala/better_player")
    }

    init(registrar: FlutterPluginRegistrar) {
        super.init()
        self.messenger = registrar.messenger()
        self.registrar = registrar
        cacheManager.setup()
    }

    public func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        guard let dict = args as? [String: Any], let textureId = dict["textureId"] as? Int else {
            return BetterPlayer()
        }
        return players[Int64(textureId)] ?? BetterPlayer()
    }

    public func createArgsCodec() -> (NSObject & FlutterMessageCodec) {
        return FlutterStandardMessageCodec.sharedInstance()
    }

    private func newTextureId() -> Int64 { texturesCount += 1; return texturesCount }

    private func onPlayerSetup(_ player: BetterPlayer, result: FlutterResult) {
        let textureId = newTextureId()
        let eventChannel = FlutterEventChannel(name: "better_player_channel/videoEvents\(textureId)", binaryMessenger: messenger!)
        player.setMixWithOthers(false)
        eventChannel.setStreamHandler(player)
        player.eventChannel = eventChannel
        players[textureId] = player
        result(["textureId": NSNumber(value: textureId)])
    }

    private func setRemoteCommandsNotificationActive() {
        try? AVAudioSession.sharedInstance().setActive(true)
        UIApplication.shared.beginReceivingRemoteControlEvents()
    }

    private func setRemoteCommandsNotificationNotActive() {
        if players.isEmpty {
            try? AVAudioSession.sharedInstance().setActive(false)
        }
        UIApplication.shared.endReceivingRemoteControlEvents()
    }

    private func setupRemoteCommands(_ player: BetterPlayer) {
        if remoteCommandsInitialized { return }
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
        if #available(iOS 9.1, *) { commandCenter.changePlaybackPositionCommand.isEnabled = true }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self = self, let notificationPlayer = self.notificationPlayer else { return .commandFailed }
            if notificationPlayer.isPlaying { notificationPlayer.eventSink?(["event": "play"]) }
            else { notificationPlayer.eventSink?(["event": "pause"]) }
            return .success
        }
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self, let notificationPlayer = self.notificationPlayer else { return .commandFailed }
            notificationPlayer.eventSink?(["event": "play"]) ; return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self, let notificationPlayer = self.notificationPlayer else { return .commandFailed }
            notificationPlayer.eventSink?(["event": "pause"]) ; return .success
        }
        if #available(iOS 9.1, *) {
            commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
                guard let self = self, let notificationPlayer = self.notificationPlayer, let positionEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
                let time = CMTimeMake(value: Int64(positionEvent.positionTime), timescale: 1)
                let millis = BetterPlayerTimeUtils.cmTimeToMillis(time)
                notificationPlayer.seekTo(Int(millis))
                notificationPlayer.eventSink?(["event": "seek", "position": NSNumber(value: millis)])
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
        if let imageUrl = imageUrl {
            let key = getTextureId(player)
            if let artwork = artworkImageDict[key] {
                nowPlaying[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlaying
            } else {
                DispatchQueue.global(qos: .default).async { [weak self] in
                    guard let self = self else { return }
                    var tempImage: UIImage?
                    if imageUrl.contains("http") {
                        if let url = URL(string: imageUrl), let data = try? Data(contentsOf: url) { tempImage = UIImage(data: data) }
                    } else {
                        tempImage = UIImage(contentsOfFile: imageUrl)
                    }
                    if let tempImage = tempImage {
                        let artwork = MPMediaItemArtwork(boundsSize: tempImage.size) { _ in tempImage }
                        self.artworkImageDict[key] = artwork
                        nowPlaying[MPMediaItemPropertyArtwork] = artwork
                    }
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlaying
                }
            }
        } else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlaying
        }
    }

    private func getTextureId(_ player: BetterPlayer) -> String {
        for (key, value) in players where value === player { return String(key) }
        return ""
    }

    private func setupUpdateListener(_ player: BetterPlayer, title: String?, author: String?, imageUrl: String?) {
        let observer = player.player.addPeriodicTimeObserver(forInterval: CMTimeMake(value: 1, timescale: 1), queue: nil) { [weak self] _ in
            guard let self = self else { return }
            self.setupRemoteCommandNotification(player, title: title, author: author, imageUrl: imageUrl)
        }
        let key = getTextureId(player)
        timeObserverIdDict[key] = observer
    }

    private func disposeNotificationData(_ player: BetterPlayer) {
        if notificationPlayer === player { notificationPlayer = nil; remoteCommandsInitialized = false }
        let key = getTextureId(player)
        if let observer = timeObserverIdDict[key] {
            player.player.removeTimeObserver(observer)
        }
        timeObserverIdDict.removeValue(forKey: key)
        artworkImageDict.removeValue(forKey: key)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [:]
    }

    private func stopOtherUpdateListener(_ player: BetterPlayer) {
        let currentPlayerTextureId = getTextureId(player)
        for (textureId, observer) in timeObserverIdDict where textureId != currentPlayerTextureId {
            if let otherPlayer = players[Int64(textureId) ?? 0] {
                otherPlayer.player.removeTimeObserver(observer)
            }
        }
        timeObserverIdDict.removeAll()
    }
}

extension BetterPlayerPlugin: FlutterMethodCallDelegate {
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "init" {
            for (_, player) in players { player.dispose() }
            players.removeAll()
            result(nil)
            return
        }
        if call.method == "create" {
            let player = BetterPlayer()
            onPlayerSetup(player, result: result)
            return
        }
        guard let args = call.arguments as? [String: Any], let textureIdNumber = args["textureId"] as? NSNumber, let player = players[textureIdNumber.int64Value] else {
            result(FlutterMethodNotImplemented)
            return
        }
        switch call.method {
        case "setDataSource":
            player.clear()
            if let dataSource = args["dataSource"] as? [String: Any] {
                dataSourceDict[getTextureId(player)] = dataSource
                let asset = dataSource["asset"] as? String
                let uri = dataSource["uri"] as? String
                let key = dataSource["key"] as? String
                let certificateUrl = dataSource["certificateUrl"] as? String
                let licenseUrl = dataSource["licenseUrl"] as? String
                var headers = dataSource["headers"] as? [NSObject: Any] ?? [:]
                let cacheKey = dataSource["cacheKey"] as? String
                let maxCacheSize = dataSource["maxCacheSize"] as? NSNumber
                let videoExtension = dataSource["videoExtension"] as? String
                let overriddenDuration = (dataSource["overriddenDuration"] as? NSNumber)?.intValue ?? 0
                if let maxCacheSize = maxCacheSize { cacheManager.setMaxCacheSize(maxCacheSize) }
                if asset != nil {
                    player.setDataSourceAsset(asset!, key: key, certificateUrl: certificateUrl, licenseUrl: licenseUrl, cacheKey: cacheKey, cacheManager: cacheManager, overriddenDuration: overriddenDuration)
                } else if let uri = uri, let url = URL(string: uri) {
                    let useCache = (dataSource["useCache"] as? NSNumber)?.boolValue ?? false
                    player.setDataSourceURL(url, key: key, certificateUrl: certificateUrl, licenseUrl: licenseUrl, headers: headers, useCache: useCache, cacheKey: cacheKey, cacheManager: cacheManager, overriddenDuration: overriddenDuration, videoExtension: videoExtension)
                } else {
                    result(FlutterMethodNotImplemented); return
                }
            }
            result(nil)
        case "dispose":
            player.clear()
            disposeNotificationData(player)
            setRemoteCommandsNotificationNotActive()
            players.removeValue(forKey: textureIdNumber.int64Value)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if !player.disposed { player.dispose() }
            }
            if players.isEmpty {
                try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            }
            result(nil)
        case "setLooping":
            player.isLooping = (args["looping"] as? NSNumber)?.boolValue ?? false
            result(nil)
        case "setVolume":
            player.setVolume(args["volume"] as? Double ?? 1.0)
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
            player.seekTo(args["location"] as? Int ?? 0)
            result(nil)
        case "pause":
            player.pause(); result(nil)
        case "setSpeed":
            player.setSpeed(args["speed"] as? Double ?? 1.0, result: result)
        case "setTrackParameters":
            let width = (args["width"] as? NSNumber)?.intValue ?? 0
            let height = (args["height"] as? NSNumber)?.intValue ?? 0
            let bitrate = (args["bitrate"] as? NSNumber)?.intValue ?? 0
            player.setTrackParameters(width: width, height: height, bitrate: bitrate)
            result(nil)
        case "enablePictureInPicture":
            let left = (args["left"] as? NSNumber)?.doubleValue ?? 0
            let top = (args["top"] as? NSNumber)?.doubleValue ?? 0
            let width = (args["width"] as? NSNumber)?.doubleValue ?? 0
            let height = (args["height"] as? NSNumber)?.doubleValue ?? 0
            player.enablePictureInPicture(CGRect(x: left, y: top, width: width, height: height))
            result(nil)
        case "isPictureInPictureSupported":
            if #available(iOS 9.0, *), AVPictureInPictureController.isPictureInPictureSupported() { result(NSNumber(value: true)) } else { result(NSNumber(value: false)) }
        case "disablePictureInPicture":
            player.disablePictureInPicture(); player.setPictureInPicture(false); result(nil)
        case "setAudioTrack":
            let name = args["name"] as? String ?? ""
            let index = (args["index"] as? NSNumber)?.intValue ?? 0
            player.setAudioTrack(name: name, index: index); result(nil)
        case "setMixWithOthers":
            player.setMixWithOthers((args["mixWithOthers"] as? NSNumber)?.boolValue ?? false); result(nil)
        case "preCache":
            if let dataSource = args["dataSource"] as? [String: Any] {
                let urlArg = dataSource["uri"] as? String
                let cacheKey = dataSource["cacheKey"] as? String
                let headers = dataSource["headers"] as? [NSObject: Any] ?? [:]
                let maxCacheSize = dataSource["maxCacheSize"] as? NSNumber
                let videoExtension = dataSource["videoExtension"] as? String
                if let maxCacheSize = maxCacheSize { cacheManager.setMaxCacheSize(maxCacheSize) }
                if let urlArg = urlArg, let url = URL(string: urlArg) {
                    if cacheManager.isPreCacheSupported(url: url, videoExtension: videoExtension) {
                        cacheManager.preCacheURL(url, cacheKey: cacheKey, videoExtension: videoExtension, withHeaders: headers) { _ in }
                    } else {
                        NSLog("Pre cache is not supported for given data source.")
                    }
                }
            }
            result(nil)
        case "clearCache":
            cacheManager.clearCache(); result(nil)
        case "stopPreCache":
            let urlArg = args["url"] as? String
            let cacheKey = args["cacheKey"] as? String
            let videoExtension = args["videoExtension"] as? String
            if let urlArg = urlArg, let url = URL(string: urlArg) {
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
        let dataSource = dataSourceDict[getTextureId(player)] ?? [:]
        let showNotification = (dataSource["showNotification"] as? NSNumber)?.boolValue ?? false
        let title = dataSource["title"] as? String
        let author = dataSource["author"] as? String
        let imageUrl = dataSource["imageUrl"] as? String
        if showNotification {
            setRemoteCommandsNotificationActive()
            setupRemoteCommands(player)
            setupRemoteCommandNotification(player, title: title, author: author, imageUrl: imageUrl)
            setupUpdateListener(player, title: title, author: author, imageUrl: imageUrl)
        }
    }
}
