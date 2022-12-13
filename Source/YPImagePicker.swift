//
//  YPImagePicker.swift
//  YPImgePicker
//
//  Created by Sacha Durand Saint Omer on 27/10/16.
//  Copyright © 2016 Yummypets. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

public protocol YPImagePickerDelegate: AnyObject {
    func imagePickerHasNoItemsInLibrary(_ picker: YPImagePicker)
    func shouldAddToSelection(indexPath: IndexPath, numSelections: Int) -> Bool
}

public protocol YPImagePickerProgressDelegate {
    func progressUpdated(progress: Float)
}

open class YPImagePicker: UINavigationController {
    public typealias DidFinishPickingCompletion = (_ items: [YPMediaItem], _ cancelled: Bool) -> Void
    public typealias DidFinishOnlyThumbCompletion = (_ thumbnailImage: UIImage, Int) -> Void
    public typealias DidFinishExportCompletion = () -> Void

    // MARK: - Public

    public weak var imagePickerDelegate: YPImagePickerDelegate?
    public weak var videoFilterVC: YPVideoFiltersVC?
    public func didFinishPicking(completion: @escaping DidFinishPickingCompletion) {
        _didFinishPicking = completion
    }
    
    public func didFinishOnlyThumb(completion: @escaping DidFinishOnlyThumbCompletion) {
        _didFinishOnlyThumb = completion
    }
    
    public func didFinishExportCompletion(completion: @escaping DidFinishExportCompletion) {
        _didFinishExport = completion
    }

    /// Get a YPImagePicker instance with the default configuration.
    public convenience init() {
        self.init(configuration: YPImagePickerConfiguration.shared)
    }

    /// Get a YPImagePicker with the specified configuration.
    public required init(configuration: YPImagePickerConfiguration) {
        YPImagePickerConfiguration.shared = configuration
        picker = YPPickerVC()
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen // Force .fullScreen as iOS 13 now shows modals as cards by default.
        picker.pickerVCDelegate = self
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    open override var preferredStatusBarStyle: UIStatusBarStyle {
        return YPImagePickerConfiguration.shared.preferredStatusBarStyle
    }

    // MARK: - Private

    private var _didFinishPicking: DidFinishPickingCompletion?
    private var _didFinishOnlyThumb: DidFinishOnlyThumbCompletion?
    private var _didFinishExport: DidFinishExportCompletion?
    private var selectedImages = [YPMediaItem]()
    // This nifty little trick enables us to call the single version of the callbacks.
    // This keeps the backwards compatibility keeps the api as simple as possible.
    // Multiple selection becomes available as an opt-in.
    private func didSelect(items: [YPMediaItem], success: Bool = true) {
        _didFinishPicking?(items, success)
    }
    
    private func willProcess(thumbnail: UIImage, duration: Int) {
        _didFinishOnlyThumb?(thumbnail, duration)
    }
    
    private func startExport() {
        _didFinishExport?()
    }
    
    private let loadingView = YPLoadingView()
    public let picker: YPPickerVC!
    public var progressDelegate: YPImagePickerProgressDelegate?
    public var progress: Float = 0 {
        didSet {
            if self.progressDelegate != nil {
                self.progressDelegate!.progressUpdated(progress: progress)
            }
        }
    }

    override open func viewDidLoad() {
        super.viewDidLoad()
        picker.didClose = { [weak self] in
            self?.picker.stopAll()
            self?._didFinishPicking?([], true)
        }
        viewControllers = [picker]
        setupLoadingView()
        navigationBar.isTranslucent = false
        navigationBar.tintColor = .ypLabel
        view.backgroundColor = .ypSystemBackground
        
        picker.didSelectThumb = { [weak self] item in
            switch item {
            case .video(_):
                break
            case .photo(let photo):
                self?.willProcess(thumbnail: photo.image, duration: 0)
            }
        }
        
        YPProgressManager.shared.picker = self
        picker.didSelectItems = { [weak self] items in
            if let isSuccess = self?.checkItemsSuccess(items: items), !isSuccess {
                self?.didSelect(items: items, success: false)
                return
            }
            
            // Use Fade transition instead of default push animation
            let transition = CATransition()
            transition.duration = 0.3
            transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
            transition.type = CATransitionType.fade
            self?.view.layer.add(transition, forKey: nil)
            
            // Multiple items flow
            if items.count > 1 {
                if YPConfig.library.skipSelectionsGallery {
                    // 선택한 이미지 데이터 저장해 놓고 처리는 이후에 한다.
//                    self?.selectedImages = items
//                    if let firstItem = items.first {
//                        switch firstItem {
//                        case .video(_):
//                            break
//                        case .photo(let photo):
//                            self?.willProcess(thumbnail: photo.image)
//                        }
//                    }
                    self?.didSelect(items: items)
                    return
                } else {
                    let selectionsGalleryVC = YPSelectionsGalleryVC(items: items) { _, items in
                        self?.didSelect(items: items)
                    }
                    self?.pushViewController(selectionsGalleryVC, animated: true)
                    return
                }
            }
            
            // One item flow
            let item = items.first!
            switch item {
            case .photo(let photo):
                let completion = { (photo: YPMediaPhoto) in
                    let mediaItem = YPMediaItem.photo(p: photo)
                    // Save new image or existing but modified, to the photo album.
                    if YPConfig.shouldSaveNewPicturesToAlbum {
                        let isModified = photo.modifiedImage != nil
                        if photo.fromCamera || (!photo.fromCamera && isModified) {
                            YPPhotoSaver.trySaveImage(photo.image, inAlbumNamed: YPConfig.albumName)
                        }
                    }
//                    self?.selectedImages = [mediaItem]
//                    self?.willProcess(thumbnail: photo.image)
                    self?.didSelect(items: [mediaItem])
                }
                
                func showCropVC(photo: YPMediaPhoto, completion: @escaping (_ aphoto: YPMediaPhoto) -> Void) {
                    switch YPConfig.showsCrop {
                    case .rectangle, .circle:
                        let cropVC = YPCropVC(image: photo.image)
                        cropVC.didFinishCropping = { croppedImage in
                            photo.modifiedImage = croppedImage
                            completion(photo)
                        }
                        self?.pushViewController(cropVC, animated: true)
                    default:
                        completion(photo)
                    }
                }
                
                if YPConfig.showsPhotoFilters {
                    let filterVC = YPPhotoFiltersVC(inputPhoto: photo,
                                                    isFromSelectionVC: false)
                    // Show filters and then crop
                    filterVC.didSave = { outputMedia, successed in
                        if case let YPMediaItem.photo(outputPhoto) = outputMedia {
                            showCropVC(photo: outputPhoto, completion: completion)
                        }
                    }
                    self?.pushViewController(filterVC, animated: false)
                } else {
                    showCropVC(photo: photo, completion: completion)
                }
            case .video(let video):
                // 트리머와 썸네일 화면 보여주기
                if YPConfig.showsVideoTrimmer {
                    let videoFiltersVC = YPVideoFiltersVC.initWith(video: video,
                                                                   isFromSelectionVC: false)
                    if YPConfig.library.backgroundComplession {
                        videoFiltersVC.willBackgroundProcessing = { [weak self] image, duration in
                            self?.willProcess(thumbnail: image, duration: duration)
                        }
                    }
                    // 저장 후 액션(영상 멈추고 피커 나가기)
                    videoFiltersVC.didSave = { [weak self] outputMedia, success in
                        self?.picker.stopAll()
                        self?.didSelect(items: [outputMedia], success: success)
                    }
                    self?.videoFilterVC = videoFiltersVC
                    self?.pushViewController(videoFiltersVC, animated: true)
                } else {
                    self?.picker.stopAll()
                    self?.didSelect(items: [YPMediaItem.video(v: video)])
                }
            }
        }
    }
    
    deinit {
        ypLog("Picker deinited 👍")
    }
    
    private func setupLoadingView() {
        view.subviews(
            loadingView
        )
        loadingView.fillContainer()
        loadingView.alpha = 0
    }
    
    public func exportImage() {
//        let items = self.selectedImages
//        if items.isEmpty {
//            return
//        }
//        self.didSelect(items: items)
    }
    
    // 성공적으로 items를 가져왔는지 여부(중도 처리 실패시 임시 디렉토리를 URL로 하는 sturct를 반환하기 때문에 이를 체크한다.
    private func checkItemsSuccess(items: [YPMediaItem]) -> Bool {
        guard let firstItem = items.first,
              let tempDirectory = URL(string: NSTemporaryDirectory()) else { return false }
        
        switch firstItem {
        case .photo(p: let p):
            if p.url == tempDirectory {
                return false
            }
        case .video(v: let v):
            if v.url == tempDirectory {
                return false
            }
        }
        
        return true
    }
}

extension YPImagePicker: YPPickerVCDelegate {
    func libraryHasNoItems() {
        self.imagePickerDelegate?.imagePickerHasNoItemsInLibrary(self)
    }
    
    func shouldAddToSelection(indexPath: IndexPath, numSelections: Int) -> Bool {
        return self.imagePickerDelegate?.shouldAddToSelection(indexPath: indexPath, numSelections: numSelections)
            ?? true
    }
}
