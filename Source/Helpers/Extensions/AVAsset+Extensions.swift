//
//  AVAsset+Extensions.swift
//  YPImagePicker
//
//  Created by Nik Kov on 23.04.2018.
//  Copyright © 2018 Yummypets. All rights reserved.
//

import AVFoundation

// MARK: Trim

extension AVAsset {
    func assetByTrimming(startTime: CMTime, endTime: CMTime) throws -> AVAsset {
        let timeRange = CMTimeRangeFromTimeToTime(start: startTime, end: endTime)
        let composition = AVMutableComposition()
        do {
            for track in tracks {
                let compositionTrack = composition.addMutableTrack(withMediaType: track.mediaType,
                                                                   preferredTrackID: track.trackID)
                try compositionTrack?.insertTimeRange(timeRange, of: track, at: CMTime.zero)
            }
        } catch let error {
            throw YPTrimError("Error during composition", underlyingError: error)
        }
        
        // Reaply correct transform to keep original orientation.
        if let videoTrack = self.tracks(withMediaType: .video).last,
            let compositionTrack = composition.tracks(withMediaType: .video).last {
            compositionTrack.preferredTransform = videoTrack.preferredTransform
        }

        return composition
    }
    
    /// Export the video
    ///
    /// - Parameters:
    ///   - destination: The url to export
    ///   - videoComposition: video composition settings, for example like crop
    ///   - removeOldFile: remove old video
    ///   - completion: resulting export closure
    ///   - isLast         : is Last Exporting
    /// - Throws: YPTrimError with description
    func export(to destination: URL,
                videoComposition: AVVideoComposition? = nil,
                removeOldFile: Bool = false,
                isLast: Bool = false,
                completion: @escaping (_ exportSession: AVAssetExportSession) -> Void) -> AVAssetExportSession? {
        // 백단에서 컴프레션 작업을 진행하는 옵션이면서 현재가 마지막이 아니면 무압축 프리셋을 쓰고 아니면 적용된 압축률을 쓰자
        let presetName = (YPConfig.library.backgroundComplession && !isLast) ? AVAssetExportPresetPassthrough : YPConfig.video.compression
        guard let exportSession = AVAssetExportSession(asset: self, presetName: presetName) else {
            ypLog("AVAsset -> Could not create an export session.")
            return nil
        }
        
        exportSession.outputURL = destination
        exportSession.outputFileType = YPConfig.video.fileType
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.videoComposition = videoComposition
        
        if removeOldFile { try? FileManager.default.removeFileIfNecessary(at: destination) }
        
        let exportTimer: Timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { timer in
            print(exportSession.progress * 100.0)
        }
        exportSession.exportAsynchronously(completionHandler: {
            exportTimer.invalidate()
            completion(exportSession)
        })

        return exportSession
    }
}
