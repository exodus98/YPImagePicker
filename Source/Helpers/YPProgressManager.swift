//
//  YPProgressManager.swift
//  
//
//  Created by 엑소더스이엔티 on 2022/11/24.
//

import Foundation

class YPProgressManager {
    static let shared = YPProgressManager()
    
    var numberOfImage = 0
    var numberOfVideo = 0
    
    public typealias DidFinishCropImageCompletion = (_ success: Bool) -> Void
    public typealias DidFinishExportVideoCompletion = (_ success: Bool) -> Void
    
    private var _didFinishCropImage: DidFinishCropImageCompletion?
    private var _didFinishExportVideo: DidFinishExportVideoCompletion?
    
    public func didFinishCropImage(completion: @escaping DidFinishCropImageCompletion) {
        _didFinishCropImage = completion
    }
    public func didFinishExportVideo(completion: @escaping DidFinishExportVideoCompletion) {
        _didFinishExportVideo = completion
    }
    
    func cropImage() {
        if numberOfImage > 0 {
            numberOfImage -= 1
        }
        
        if numberOfImage == 0 {
            _didFinishCropImage?(true)
        }
    }
    
    func exportVideo() {
        if numberOfVideo > 0 {
            numberOfVideo -= 1
        }
        
        if numberOfVideo == 0 {
            _didFinishExportVideo?(true)
        }
    }
}
