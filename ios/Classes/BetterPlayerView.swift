import UIKit
import AVFoundation

final class BetterPlayerView: UIView {
    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }

    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    override class var layerClass: AnyClass { AVPlayerLayer.self }
}
