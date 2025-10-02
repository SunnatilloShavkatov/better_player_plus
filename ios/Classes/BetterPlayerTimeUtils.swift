import Foundation
import AVFoundation

@objc public class BetterPlayerTimeUtils: NSObject {
    @objc public static func FLTCMTimeToMillis(_ time: CMTime) -> Int64 {
        if time.timescale == 0 { return 0 }
        return Int64(time.value) * 1000 / Int64(time.timescale)
    }

    @objc public static func FLTNSTimeIntervalToMillis(_ interval: TimeInterval) -> Int64 {
        return Int64(interval * 1000.0)
    }
}
