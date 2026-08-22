import UIKit
import AVFoundation
import AVKit

public class BetterPlayerView: UIView {
    public var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }

    public var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }

    public override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }

    /// Called whenever this view enters or leaves a window.
    ///
    /// Flutter creates a second platform view for the fullscreen route and destroys
    /// it on pop, without ever calling `view()` again for the inline one. This is the
    /// only signal that the layer PiP is attached to has gone away.
    public var onWindowChanged: (() -> Void)?

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        onWindowChanged?()
    }
}
