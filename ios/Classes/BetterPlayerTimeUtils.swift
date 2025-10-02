import Foundation
import AVFoundation

final class BetterPlayerTimeUtils {
    static func FLTCMTimeToMillis(_ time: CMTime) -> Int64 {
        guard time.timescale != 0 else { return 0 }
        return Int64(time.value) * 1000 / Int64(time.timescale)
    }

    static func FLTNSTimeIntervalToMillis(_ interval: TimeInterval) -> Int64 {
        return Int64(interval * 1000.0)
    }
}
