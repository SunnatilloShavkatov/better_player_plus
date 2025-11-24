//
//  TrackUtil.swift
//  xstream_player
//
//  Created by Kaleb Kebede on 14/09/2025.
//

import AVFoundation
import Foundation
import mamba
import CoreMedia

public struct HLSStreamData {
    let type: String // "video", "audio", "combined"
    let mime: String? // Derived from CODECS (e.g., "video/mp4", "audio/mp4")
    let language: String? // For audio or combined streams (from EXT-X-MEDIA LANGUAGE, or derived)
    let label: String?    // For audio streams (from EXT-X-MEDIA NAME or a derived name)
    let width: Int?       // For video or combined streams
    let height: Int?      // For video or combined streams
    let bitrate: Int      // BANDWIDTH from EXT-X-STREAM-INF, or derived for audio tracks
    let audioGroupId: String? // The AUDIO group ID if present for video streams
}
private struct HLSMediaGroup {
    let groupId: String
    let type: String
    let name: String
    let language: String?
    let autoSelect: Bool
    let isDefault: Bool
    let inStreamId: String?
    let channels: String?
}

@objc(TrackUtil)
@objcMembers
public class TrackUtil: NSObject {
    
    @objc public func extractUtil(asset: AVURLAsset, eventSink: FlutterEventSink?, key: String?){
        NSLog("LOADING-TRACKS %@", asset.description)
        let playlistURL = asset.url
        NSLog("PARSING URL %@", playlistURL.absoluteString)
        
        // 1. Create a URLSession data task to fetch the playlist content
        let task = URLSession.shared.dataTask(with: playlistURL) { [weak self] (data, response, error) in
            guard let self = self else { return }
            
            if let error = error {
                NSLog("FETCH_ERROR %@", error.localizedDescription)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                NSLog("HTTP_ERROR Status Code: %ld", statusCode)
                return
            }
            
            guard let playlistData = data else {
                NSLog("NO_PLAYLIST_DATA")
                return
            }
            
            // 2. Now that we have the playlist content, create the parser and parse
            let parser = PlaylistParser()
            let result = parser.parse(playlistData: playlistData, url: playlistURL)
            var extractedStreams: [HLSStreamData] = []
            switch result {
            case .parsedVariant(let variant):
                NSLog("PARSE VARIANT PLAYLIST %@", variant.debugDescription)
                // Handle variant playlist (e.g., audio-only, video-only)
                // You might want to recursively parse this if it's a sub-playlist
                break
            case .parsedMaster(let master):
                NSLog("PARSED MASTER PLAYLIST")
                for tag in master.tags {
                    if(tag.tagDescriptor.toString() == "EXT-X-MEDIA") {
                        extractedStreams.append(HLSStreamData(
                            type: tag.value(forKey: "TYPE") ?? "audio",
                            mime: nil,
                            language: tag.value(forKey: "LANGUAGE"),
                            label: tag.value(forKey: "NAME"),
                            width: -1,
                            height: -1,
                            bitrate: -1,
                            audioGroupId: tag.value(forKey: "GROUP-ID")
                        ))
                    }
                    if(tag.isAudioVideoStream() == .TRUE || tag.isVideoStream() == .TRUE) {
                        let resolution = tag.resolution()
                        extractedStreams.append(HLSStreamData(
                            type: "video",
                            mime: "video/avc",
                            language: nil,
                            label: nil,
                            width: resolution?.w,
                            height: resolution?.h,
                            bitrate: Int(tag.bandwidth() ?? -1),
                            audioGroupId: tag.value(forKey: "AUDIO")
                        ))
                    }
                }
                break
            case .parseError(let error):
                NSLog("PARSING_ERROR %@", error.localizedDescription)
                break
            }
            if(eventSink != nil) {
                let tracks = extractedStreams.reduce(into: [[:]], {(result, stream) in
                    result.append(["type": stream.type, "mime": stream.mime, "language": stream.language, "label": stream.label, "width": stream.width, "height": stream.height, "bitrate": stream.bitrate, "audioGroupId": stream.audioGroupId])
                })
                eventSink?(["event": "tracksChanged", "key": key, "tracks": tracks])
            }
        }
        
        // 3. Start the data task
        task.resume()
    }
}
