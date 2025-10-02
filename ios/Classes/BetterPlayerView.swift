import UIKit
import AVFoundation

@objc public class BetterPlayerView: UIView {
    @objc public var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }

    @objc public var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }

    @objc override public class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
}
