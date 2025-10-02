// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation
import AVKit

class BetterPlayerTimeUtils {
    
    static func fltCMTimeToMillis(_ time: CMTime) -> Int64 {
        if time.timescale == 0 { return 0 }
        return time.value * 1000 / Int64(time.timescale)
    }
    
    static func fltNSTimeIntervalToMillis(_ interval: TimeInterval) -> Int64 {
        return Int64(interval * 1000.0)
    }
}