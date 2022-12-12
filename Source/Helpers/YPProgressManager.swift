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
    
    var numberOfCroppedImage = 0
    var numberOfExportedVideo = 0
    
    var picker: YPImagePicker?
    
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
    
    func numberOfCropingImages(_ count: Int) {
        numberOfImage = count
    }
    
    func numberOfExportingVideos(_ count: Int) {
        numberOfVideo = count
    }
    
    func initProgress() {
        numberOfImage = 0
        numberOfVideo = 0
        
        numberOfCroppedImage = 0
        numberOfExportedVideo = 0
    }
    
    func cropImage() {
        if numberOfImage != numberOfCroppedImage {
            numberOfCroppedImage += 1
        }
        
        if numberOfImage == numberOfCroppedImage {
            picker = nil
            _didFinishCropImage?(true)
        }
    }
    
    func calculteImageProgress() {
        let progress: Float = numberOfImage == numberOfCroppedImage ? 1.0 : Float(numberOfCroppedImage) / Float(numberOfImage)
        picker?.progress = progress
    }
    
    func exportProgress(progress: Float) {
        picker?.progress = progress
    }
    
    func exportVideo() {
        picker = nil
        _didFinishExportVideo?(true)
    }
}
