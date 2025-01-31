//
//  VideoFiltersVC.swift
//  YPImagePicker
//
//  Created by Nik Kov || nik-kov.com on 18.04.2018.
//  Copyright © 2018 Yummypets. All rights reserved.
//

import UIKit
import Photos
import PryntTrimmerView
import Stevia

public final class YPVideoFiltersVC: UIViewController, IsMediaFilterVC {

    /// Designated initializer
    public class func initWith(video: YPMediaVideo,
                               isFromSelectionVC: Bool) -> YPVideoFiltersVC {
        let vc = YPVideoFiltersVC()
        vc.inputVideo = video
        vc.isFromSelectionVC = isFromSelectionVC
        return vc
    }

    // MARK: - Public vars

    public var inputVideo: YPMediaVideo!
    public var inputAsset: AVAsset { return AVAsset(url: inputVideo.url) }
    public var willBackgroundProcessing: ((UIImage, Int) -> Void)?
    public var didSave: ((YPMediaItem, Bool) -> Void)?
    public var didCancel: (() -> Void)?

    // MARK: - Private vars

    private var playbackTimeCheckerTimer: Timer?
    private var imageGenerator: AVAssetImageGenerator?
    private var isFromSelectionVC = false

    private let trimmerContainerView: UIView = {
        let v = UIView()
        return v
    }()
    private let trimmerView: TrimmerView = {
        let v = TrimmerView()
        v.mainColor = YPConfig.colors.trimmerTabLineCOlor
        v.handleColor = YPConfig.colors.trimmerHandleColor
        v.positionBarColor = YPConfig.colors.positionLineColor
        v.maxDuration = YPConfig.video.trimmerMaxDuration
        v.minDuration = YPConfig.video.trimmerMinDuration
        return v
    }()
    private let coverThumbSelectorView: ThumbSelectorView = {
        let v = ThumbSelectorView()
        v.thumbBorderColor = YPConfig.colors.coverSelectorBorderColor
        v.isHidden = true
        return v
    }()
    private let trimBottomItem: YPMenuItem = {
        let v = YPMenuItem()
        v.textLabel.text = YPConfig.wordings.trim
        v.button.addTarget(self, action: #selector(selectTrim), for: .touchUpInside)
        return v
    }()
    private let coverBottomItem: YPMenuItem = {
        let v = YPMenuItem()
        v.textLabel.text = YPConfig.wordings.cover
        v.button.addTarget(self, action: #selector(selectCover), for: .touchUpInside)
        return v
    }()
    private let videoView: YPVideoView = {
        let v = YPVideoView()
        return v
    }()
    private let coverImageView: UIImageView = {
        let v = UIImageView()
        v.contentMode = .scaleAspectFit
        v.isHidden = true
        return v
    }()
    
    // FLUV
    private let bottomLine: UIView = {
        let v = UIView()
        v.backgroundColor = YPConfig.colors.trimmerTabLineCOlor
        return v
    }()
    
    private let selectionTrim: UIView = {
        let v = UIView()
        v.backgroundColor = YPConfig.colors.trimmerTabSelected
        return v
    }()

    private let selectionCover: UIView = {
        let v = UIView()
        v.backgroundColor = YPConfig.colors.trimmerTabSelected
        return v
    }()

    // MARK: - Live cycle

    override public func viewDidLoad() {
        super.viewDidLoad()

        setupLayout()
        title = YPConfig.wordings.trim
        view.backgroundColor = YPConfig.colors.backgroundColor
        setupNavigationBar(isFromSelectionVC: self.isFromSelectionVC)

        // Remove the default and add a notification to repeat playback from the start
        videoView.removeReachEndObserver()
        NotificationCenter.default
            .addObserver(self,
                         selector: #selector(itemDidFinishPlaying(_:)),
                         name: .AVPlayerItemDidPlayToEndTime,
                         object: nil)
        
        // Set initial video cover
        imageGenerator = AVAssetImageGenerator(asset: self.inputAsset)
        imageGenerator?.appliesPreferredTrackTransform = true
        didChangeThumbPosition(CMTime(seconds: 0, preferredTimescale: 1))
    }

    override public func viewDidAppear(_ animated: Bool) {
        trimmerView.asset = inputAsset
        trimmerView.delegate = self
        
        coverThumbSelectorView.asset = inputAsset
        coverThumbSelectorView.delegate = self
        
        selectTrim()
        videoView.loadVideo(inputVideo)
//        videoView.showPlayImage(show: true)
//        startPlaybackTimeChecker()

        // FLUV
        if YPConfig.video.shouldStartPlaying {
            videoView.play()
        }
        
        super.viewDidAppear(animated)
        moveBar(CMTime.zero)
        stopBar(CMTime.zero)
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        stopPlaybackTimeChecker()
        videoView.stop()
    }

    // MARK: - Setup

    private func setupNavigationBar(isFromSelectionVC: Bool) {
        if isFromSelectionVC {
            navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(named: "btn_close_24px"),
                                                               style: .plain,
                                                               target: self,
                                                               action: #selector(cancel))
        } else {
            navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(named: "btn_back_24px"),
                                                               style: .plain,
                                                               target: self,
                                                               action: #selector(back))
        }
        setupRightBarButtonItem()
    }

    private func setupRightBarButtonItem() {
        let rightBarButtonTitle = isFromSelectionVC ? YPConfig.wordings.done : YPConfig.wordings.next
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: rightBarButtonTitle,
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(selectMedia))
        navigationItem.rightBarButtonItem?.tintColor = YPConfig.colors.tintColor
        navigationItem.rightBarButtonItem?.setFont(font: YPConfig.fonts.rightBarButtonFont, forState: .normal)
    }

    private func setupLayout() {
        view.subviews(
            bottomLine,
            selectionTrim,
            selectionCover,
            trimBottomItem,
            coverBottomItem,
            videoView,
            coverImageView,
            trimmerContainerView.subviews(
                trimmerView,
                coverThumbSelectorView
            )
        )

        bottomLine.height(1.0/UIScreen.main.scale)
        bottomLine.Bottom == trimBottomItem.Top
        bottomLine.fillHorizontally()
        
        selectionTrim.height(2)
        selectionTrim.Bottom == trimBottomItem.Top
        selectionTrim.Leading == view.Leading
        selectionTrim.Trailing == selectionCover.Leading
        selectionCover.height(2)
        selectionCover.Bottom == trimBottomItem.Top
        selectionCover.trailing(0)
        selectionCover.isHidden = true
        equal(sizes: selectionTrim, selectionCover)

        trimBottomItem.leading(0).height(48)
        trimBottomItem.Bottom == view.safeAreaLayoutGuide.Bottom
        trimBottomItem.Trailing == coverBottomItem.Leading
        coverBottomItem.Bottom == view.safeAreaLayoutGuide.Bottom
        coverBottomItem.trailing(0)
        equal(sizes: trimBottomItem, coverBottomItem)

        videoView.heightEqualsWidth().fillHorizontally().top(0)
//        videoView.Bottom == trimmerContainerView.Top

        coverImageView.followEdges(videoView)

        trimmerContainerView.backgroundColor = .clear
        trimmerContainerView.fillHorizontally()
//        trimmerContainerView.Top == videoView.Bottom
        trimmerContainerView.Bottom == trimBottomItem.Top - 40
        trimmerContainerView.height(60)

        trimmerView.fillHorizontally(padding: 30).centerVertically()
        trimmerView.Height == trimmerContainerView.Height

        coverThumbSelectorView.followEdges(trimmerView)
    }

    // MARK: - Actions
    
    @objc private func selectMedia() {
        guard let startTime = trimmerView.startTime,
              let endTime = trimmerView.endTime else { return }
        
        let videoDuration = CMTimeSubtract(endTime, startTime)
        if let coverImage = self.coverImageView.image,
           let willBackgroundProcessing = self.willBackgroundProcessing {
            willBackgroundProcessing(coverImage, Int(videoDuration.value) / Int(videoDuration.timescale))
        }
    }

    @objc public func save() {
        guard let didSave = didSave else {
            return ypLog("Don't have saveCallback")
        }

        navigationItem.rightBarButtonItem = YPLoaders.defaultLoader

        do {
            let asset = AVURLAsset(url: inputVideo.url)
            let trimmedAsset = try asset
                .assetByTrimming(startTime: trimmerView.startTime ?? CMTime.zero,
                                 endTime: trimmerView.endTime ?? inputAsset.duration)
            
            // Looks like file:///private/var/mobile/Containers/Data/Application
            // /FAD486B4-784D-4397-B00C-AD0EFFB45F52/tmp/8A2B410A-BD34-4E3F-8CB5-A548A946C1F1.mov
            let destinationURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingUniquePathComponent(pathExtension: YPConfig.video.fileType.fileExtension)
            print("export")
            _ = trimmedAsset.export(to: destinationURL, isLast: true) { [weak self] session in
                switch session.status {
                case .completed:
                    DispatchQueue.main.async {
                        if let coverImage = self?.coverImageView.image {
                            let resultVideo = YPMediaVideo(thumbnail: coverImage,
                                                           videoURL: destinationURL,
                                                           asset: self?.inputVideo.asset)
                            didSave(YPMediaItem.video(v: resultVideo), true)
                            self?.setupRightBarButtonItem()
                        } else {
                            let resultVideo = YPMediaVideo(thumbnail: UIImage(),
                                                           videoURL: destinationURL,
                                                           asset: self?.inputVideo.asset)
                            didSave(YPMediaItem.video(v: resultVideo), true)
                            self?.setupRightBarButtonItem()
                        }
                        YPProgressManager.shared.exportVideo()
                    }
                case .failed:
                    ypLog("Export of the video failed. Reason: \(String(describing: session.error))")
                    if let videoURL = self?.inputVideo.url {
                        let resultVideo = YPMediaVideo(thumbnail: UIImage(),
                                                       videoURL: videoURL,
                                                       asset: self?.inputVideo.asset)
                        didSave(YPMediaItem.video(v: resultVideo), false)
                    }
                    
                default:
                    ypLog("Export session completed with \(session.status) status. Not handled")
                }
            }
        } catch let error {
            ypLog("Error: \(error)")
        }
    }
    
    @objc private func cancel() {
        didCancel?()
    }
    
    @objc private func back() {
        self.navigationController?.popViewController(animated: true)
    }
    
    public func saveAndReturnInfo(completed: @escaping ([URL], [CMTime], [CMTime]) -> Void) {
        let fileURL = inputVideo.url
        let startTime = trimmerView.startTime ?? CMTime.zero
        let endTime = trimmerView.endTime ?? inputAsset.duration
        save()
        completed([fileURL], [startTime], [endTime])
    }

    // MARK: - Bottom buttons

    @objc private func selectTrim() {
        selectionTrim.isHidden = false
        selectionCover.isHidden = true
        
        trimBottomItem.select()
        coverBottomItem.deselect()

        trimmerView.isHidden = false
        videoView.isHidden = false
        coverImageView.isHidden = true
        coverThumbSelectorView.isHidden = true
    }
    
    @objc private func selectCover() {
        selectionTrim.isHidden = true
        selectionCover.isHidden = false
        
        trimBottomItem.deselect()
        coverBottomItem.select()
        
        trimmerView.isHidden = true
        videoView.isHidden = true
        coverImageView.isHidden = false
        coverThumbSelectorView.isHidden = false
        
        stopPlaybackTimeChecker()
        videoView.stop()
    }
    
    // MARK: - Various Methods

    // Updates the bounds of the cover picker if the video is trimmed
    // TODO: Now the trimmer framework doesn't support an easy way to do this.
    // Need to rethink a flow or search other ways.
    private func updateCoverPickerBounds() {
        if let startTime = trimmerView.startTime,
            let endTime = trimmerView.endTime {
            if let selectedCoverTime = coverThumbSelectorView.selectedTime {
                let range = CMTimeRange(start: startTime, end: endTime)
                if !range.containsTime(selectedCoverTime) {
                    // If the selected before cover range is not in new trimeed range,
                    // than reset the cover to start time of the trimmed video
                }
            } else {
                // If none cover time selected yet, than set the cover to the start time of the trimmed video
            }
        }
    }
    
    // MARK: - Trimmer playback
    
    @objc private func itemDidFinishPlaying(_ notification: Notification) {
        if let startTime = trimmerView.startTime {
            videoView.player.seek(to: startTime)
        }
    }
    
    private func startPlaybackTimeChecker() {
        stopPlaybackTimeChecker()
        playbackTimeCheckerTimer = Timer
            .scheduledTimer(timeInterval: 0.05, target: self,
                            selector: #selector(onPlaybackTimeChecker),
                            userInfo: nil,
                            repeats: true)
    }
    
    private func stopPlaybackTimeChecker() {
        playbackTimeCheckerTimer?.invalidate()
        playbackTimeCheckerTimer = nil
    }
    
    @objc private func onPlaybackTimeChecker() {
        guard let startTime = trimmerView.startTime,
            let endTime = trimmerView.endTime else {
            return
        }
        
        let playBackTime = videoView.player.currentTime()
        trimmerView.seek(to: playBackTime)
        
        if playBackTime >= endTime {
            videoView.player.seek(to: startTime,
                                  toleranceBefore: CMTime.zero,
                                  toleranceAfter: CMTime.zero)
            trimmerView.seek(to: startTime)
        }
    }
    
    func moveBar(_ playerTime: CMTime) {
        stopPlaybackTimeChecker()
        videoView.pause()
        videoView.player.seek(to: playerTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
    }
    
    func stopBar(_ playerTime: CMTime) {
        videoView.player.seek(to: playerTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
        videoView.play()
        startPlaybackTimeChecker()
        updateCoverPickerBounds()
    }
}

// MARK: - TrimmerViewDelegate
extension YPVideoFiltersVC: TrimmerViewDelegate {
    public func positionBarStoppedMoving(_ playerTime: CMTime) {
        stopBar(playerTime)
    }
    
    public func didChangePositionBar(_ playerTime: CMTime) {
        moveBar(playerTime)
    }
}

// MARK: - ThumbSelectorViewDelegate
extension YPVideoFiltersVC: ThumbSelectorViewDelegate {
    public func didChangeThumbPosition(_ imageTime: CMTime) {
        if let imageGenerator = imageGenerator,
            let imageRef = try? imageGenerator.copyCGImage(at: imageTime, actualTime: nil) {
            coverImageView.image = UIImage(cgImage: imageRef)
        }
    }
}
