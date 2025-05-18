//
//  ISVideoCropViewController.swift
//  trim-crop-video
//
//  Created by 官泉华 on 2025/5/14.
//

import UIKit
import AVFoundation

class ISVideoCropViewController: UIViewController {

    var url: URL
    var cropSize: CGSize
    var minDuration: Double = 0.5 // 最小选择时长, 单位: s
    var maxDuration: Double = 6.0 // 最大选择时长, 单位: s
    
    var cropTimeRangeView: ISCropTimeRangeView?
    
    private var widthPerSecond: Double = 129.0 // 底部图片预览进图视图, 每秒对应宽度, 单位: pt
    private var fps: Double = 1.0
    private let previewThumbSize: CGSize = CGSizeMake(30, 40)
    
    private var videoContainerScrollView = UIScrollView()
    private var (maskView, maskLayer) = (UIView(), CAShapeLayer())
    private var cropAreaView = ISCropAreaView()
    private var (videoPreviewView, playerLayer, playButton) = (UIView(), AVPlayerLayer(), UIButton(type: .custom))
    
    private var videoSize: CGSize = .zero
    private var videoDuration: Double = 0
    
    private var startTime: CMTime = .zero
    private var endTime: CMTime = .zero
    private var endTimeObserver: Any?
    private var periodicTimeObserver: Any?
    
    private var progressIndicatorView: UIView = UIView()
    
    private var previewImagesScrollView = UIScrollView()
    private var previewImagesScrollViewContentView: UIView = UIView()
    private var ignorePreviewImagesScrollViewScroll: Bool = false
    private var previewImages: [UIImage] = []
    
    private var timeRangeView: UIView = UIView()
    private var startTimeView: UIView = UIView()
    private var endTimeView: UIView = UIView()
    private var startTimePanGesture: UIPanGestureRecognizer = UIPanGestureRecognizer()
    private var endTimePanGesture: UIPanGestureRecognizer = UIPanGestureRecognizer()
    
    private var cropButton: UIButton = UIButton(type: .custom)
    
    init(url: URL, cropSize: CGSize) {
        self.url = url
        self.cropSize = cropSize
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setup()
    }
    
    func setup() {
        view.backgroundColor = .black
        
        // 430x510
        view.addSubview(videoContainerScrollView)
        videoContainerScrollView.addSubview(videoPreviewView)
        maskView.layer.addSublayer(maskLayer)
        view.addSubview(maskView)
        view.addSubview(cropAreaView)
        view.addSubview(playButton)
        view.addSubview(previewImagesScrollView)
        previewImagesScrollView.addSubview(timeRangeView)
        previewImagesScrollView.addSubview(progressIndicatorView)
        previewImagesScrollView.addSubview(startTimeView)
        previewImagesScrollView.addSubview(endTimeView)
        
        progressIndicatorView.bounds = CGRectMake(0, 0, 2, previewThumbSize.height + 10)
        progressIndicatorView.center = CGPointMake(0, previewThumbSize.height * 0.5)
        progressIndicatorView.layer.cornerRadius = 1
        progressIndicatorView.backgroundColor = .white.withAlphaComponent(0.9)
        
        cropButton.setTitle("裁剪", for: .normal)
        cropButton.addAction(.init(handler: { [weak self] _ in
            self?.crop()
        }), for: .touchUpInside)
        view.addSubview(cropButton)
        
        videoContainerScrollView.delegate = self
        videoContainerScrollView.showsHorizontalScrollIndicator = false
        videoContainerScrollView.showsVerticalScrollIndicator = false
        maskView.isUserInteractionEnabled = false
        cropAreaView.isUserInteractionEnabled = false
        playButton.setImage(UIImage(named: "diyLivePhotoPlay"), for: .normal)
        playButton.addAction(.init(handler: { [weak self] _ in
            if let self, let player = self.playerLayer.player {
                if let observer = self.periodicTimeObserver {
                    player.removeTimeObserver(observer)
                    self.periodicTimeObserver = nil
                }
                if player.rate == 0 {
                    self.periodicTimeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 60), queue: .main) { [weak self] _ in
                        if let self, let player = self.playerLayer.player {
                            let currentTime = player.currentTime()
                            self.progressIndicatorView.center = CGPointMake(currentTime.seconds / self.videoDuration * self.previewImagesScrollViewContentView.bounds.width, self.timeRangeView.bounds.midY)
                            self.cropTimeRangeView?.updateProgressIndicator(time: currentTime)
                        }
                    }
                    if abs(player.currentTime().seconds - self.endTime.seconds) < 0.01 {
                        player.seek(to: self.startTime, toleranceBefore: .zero, toleranceAfter: .zero)
                    }
                    player.play()
                } else {
                    player.pause()
                }
            }
        }), for: .touchUpInside)
        
        videoPreviewView.layer.addSublayer(playerLayer)
        let player = AVPlayer(url: url)
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspect
        
        let asset = AVURLAsset(url: url)
        if let track = asset.tracks(withMediaType: .video).first {
            videoSize = track.naturalSize.applying(track.preferredTransform)
            videoSize = CGSizeMake(abs(videoSize.width), abs(videoSize.height))
        } else {
            assert(false)
            videoSize = CGSizeMake(512, 512)
        }
        endTime = CMTimeMake(value: Int64(maxDuration * Double(asset.duration.timescale)), timescale: asset.duration.timescale)
        updatePlayerStartEndTime()
        
        player.volume = 0
        player.pause()
        
        timeRangeView.layer.borderColor = UIColor.white.cgColor
        timeRangeView.layer.borderWidth = 1.0
        timeRangeView.backgroundColor = .clear
        timeRangeView.alpha = 0
        startTimeView.backgroundColor = .white.withAlphaComponent(0.5)
        endTimeView.backgroundColor = .white.withAlphaComponent(0.5)
        
        startTimeView.addGestureRecognizer(startTimePanGesture)
        startTimePanGesture.addTarget(self, action: #selector(handleStartTimePanGesture(gesture:)))
        endTimeView.addGestureRecognizer(endTimePanGesture)
        endTimePanGesture.addTarget(self, action: #selector(handleEndTimePanGesture(gesture:)))
        
        let videoDuration = CMTimeGetSeconds(asset.duration)
        self.videoDuration = videoDuration
        // 最小选择时长 min(0.5, 视频时长)
        // 最大选择时长 min(6.0, 视频时长)
        minDuration = min(0.5, videoDuration)
        maxDuration = min(6.0, videoDuration)
        // 取屏展示宽度 w
        let w = getVideoContainerScrollViewFrame().width
        // 左右间距 40
        previewImagesScrollView.contentInset = UIEdgeInsets(top: 0, left: 40, bottom: 0, right: 40)
        // w - 40 * 2 -> 对应视频最大选择时长
        widthPerSecond = (w - 40 * 2.0) / maxDuration
        // 预览小图宽高 previewThumbSize
        // 计算每秒取预览图帧数 = withPerSecond / 30.0
        //fps = max(1.0, widthPerSecond / previewThumbSize.width)
        fps = ISCropTimeRangeView.calcFps(displayWidth: w, maxDuration: self.maxDuration)
        
        previewImagesScrollView.showsVerticalScrollIndicator = false
        previewImagesScrollView.showsHorizontalScrollIndicator = false
        getVideoPreviewImages(asset: AVURLAsset(url: url)) { [weak self] images in
            guard let self else { return }
            
            self.previewImages = images
            self.updatePreviewScrollView(duration: videoDuration)
            self.updateTimeRangeViewFrame()
            self.timeRangeView.alpha = 1
            
            let fps = ISCropTimeRangeView.calcFps(displayWidth: w, maxDuration: self.maxDuration)
            let cropTimeRangeView = ISCropTimeRangeView(duration: videoDuration, previewImages: images, fps: fps)
            cropTimeRangeView.didStopScroll = { [weak self] v in
                // 完全停止后, 触发播放器更新播放范围
                self?.updatePlayerStartEndTime()
            }
            cropTimeRangeView.onStartTimeChanged = { [weak self] v in
                if let player = self?.playerLayer.player {
                    if player.rate != 0 {
                        player.pause()
                    }
                    player.seek(to: v.startTime, toleranceBefore: .zero, toleranceAfter: .zero)
                }
            }
            cropTimeRangeView.onEndTimeChanged = { [weak self] v in
                if let player = self?.playerLayer.player {
                    if player.rate != 0 {
                        player.pause()
                    }
                    player.seek(to: v.endTime, toleranceBefore: .zero, toleranceAfter: .zero)
                }
            }
            cropTimeRangeView.onStartTimeChangeEnded = { [weak self] v in
                self?.updatePlayerStartEndTime()
            }
            cropTimeRangeView.onEndTimeChangeEnded = { [weak self] v in
                self?.updatePlayerStartEndTime()
            }
            self.cropTimeRangeView = cropTimeRangeView
            self.view.addSubview(cropTimeRangeView)
            self.view.setNeedsLayout()
        }
        previewImagesScrollView.delegate = self
        previewImagesScrollView.alpha = 0
    }
    
    private func getVideoPreviewImages(asset: AVURLAsset, complete: (([UIImage]) -> Void)?) {
        let duration = CMTimeGetSeconds(asset.duration)
        
        var times = [NSValue]()
        let totalFrames = Float64(duration * fps)
        let timescale = Int32(fps * 1000)
        for i in 0..<Int(totalFrames) {
            let value = min(Int64(i * 1000), Int64(duration * Double(timescale)))
            let t = CMTimeMake(value: value, timescale: timescale)
            times.append(NSValue(time: t))
        }
        // 补充最后一帧
        if let lastTime = times.last?.timeValue,
           CMTimeGetSeconds(lastTime) < duration {
            let value = Int64(duration * Double(timescale))
            times.append(NSValue(time: CMTimeMake(value: value, timescale: timescale)))
        }
        
        let imgGenerator = AVAssetImageGenerator(asset: asset)
        imgGenerator.appliesPreferredTrackTransform = true
        imgGenerator.requestedTimeToleranceBefore = .zero
        imgGenerator.requestedTimeToleranceAfter = .zero
        
        var images = [String: UIImage]()
        let getTimeKey: (CMTime) -> String = { time in
            return "\(Int(time.value))-\(Int(time.timescale))"
        }
        let rect = CGRectMake(0, 0, previewThumbSize.width * screenScale, previewThumbSize.height * screenScale)
        let timesCount = times.count
        imgGenerator.generateCGImagesAsynchronously(forTimes: times) { requestedTime, cgimage, actualTime, result, error in
            let key = getTimeKey(requestedTime)
            switch result {
            case .cancelled:
                debugPrint("image generate - cancelled")
                images[key] = UIImage()
            case .failed:
                debugPrint("image generate - failed")
                images[key] = UIImage()
            case .succeeded:
                let image = UIImage(cgImage: cgimage!)
                let targetSize = ISMakeRectAspectFill(aspectRatio: image.size, insideRect: rect).size
                let resizedImage = image.resizeImageTo(size: targetSize, scale: 1.0) ?? image
                images[key] = resizedImage
                debugPrint("image generate - success - \(key)")
            default:
                images[key] = UIImage()
                debugPrint("image generate - default")
            }
            
            if error != nil {
                debugPrint(error?.localizedDescription ?? "Error")
            }
            
            if images.count == timesCount {
                // 完成图片导出
                var theImages = [UIImage]()
                for timeValue in times {
                    let time = timeValue.timeValue
                    let key = getTimeKey(time)
                    if let image = images[key] {
                        theImages.append(image)
                    }
                }
                DispatchQueue.main.async {
                    complete?(theImages)
                }
            }
        }
    }
    
    private func updatePreviewScrollView(duration: Double) {
        previewImagesScrollView.alpha = 0
        let contentView = self.previewImagesScrollViewContentView
        previewImagesScrollView.addSubview(contentView)
        previewImagesScrollView.sendSubviewToBack(contentView)
        
        let imageContentView = UIView()
        imageContentView.clipsToBounds = true
        contentView.addSubview(imageContentView)
        
        var x = 0.0
        let imgW = previewThumbSize.width
        let imgH = previewThumbSize.height
        for image in previewImages {
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageContentView.addSubview(imageView)
            imageView.frame = CGRectMake(x, 0, imgW, imgH)
            x += imgW
        }
        previewImagesScrollView.contentSize = CGSizeMake(widthPerSecond * duration, 105)
        contentView.frame = CGRect(origin: .zero, size: previewImagesScrollView.contentSize)
        imageContentView.frame = contentView.bounds
        
        x = 0.0
        let secSpacing = widthPerSecond / 10.0
        let first = 0
        let last = Int(duration * 10)
        for sec in first...last {
            let v = UIView()
            v.backgroundColor = .white
            v.frame = CGRectMake(x - 0.5, 105 - 20.0, 1, 4)
            contentView.addSubview(v)
            if sec % 10 == 0 {
                v.alpha = 1.0
            } else {
                v.alpha = 0.5
            }
            
            if (sec == first || abs(sec - last) < 10) && sec % 10 == 0 {
                let label = UILabel()
                label.text = "\(sec / 10)S"
                label.textColor = .white.withAlphaComponent(0.5)
                label.font = .systemFont(ofSize: 8)
                label.textAlignment = .center
                label.bounds = CGRectMake(0, 0, 100, 12)
                label.center = CGPointMake(v.center.x, v.center.y + 15.0)
                contentView.addSubview(label)
            }
            x += secSpacing
        }
        
        UIView.animate(withDuration: 0.2) {
            //self.previewImagesScrollView.alpha = 1.0
        }
    }
    
    private func updatePlayerStartEndTime() {
        guard let player = playerLayer.player else { return }
        
        if let observer = endTimeObserver {
            player.removeTimeObserver(observer)
            endTimeObserver = nil
        }
        endTimeObserver = player.addBoundaryTimeObserver(forTimes: [NSValue(time: endTime)], queue: .main, using: { [weak self] in
            guard let self, let player = self.playerLayer.player else { return }
            player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
            player.play()
        })
    }
    
    private func centerTimeRangeView() {
        ignorePreviewImagesScrollViewScroll = true
        
        let midX = view.bounds.midX
        let timeRangeViewMidX = view.convert(CGPointMake(timeRangeView.bounds.midX, 0), from: timeRangeView).x
        var offset = previewImagesScrollView.contentOffset
        offset.x += timeRangeViewMidX - midX
        UIView.animate(withDuration: 0.35) {
            self.previewImagesScrollView.contentOffset = offset
        } completion: { _ in
            var insets = self.previewImagesScrollView.contentInset
            let left = max(insets.left, (self.previewImagesScrollView.bounds.width - self.timeRangeView.bounds.width) * 0.5)
            insets.left = left
            insets.right = left
            self.previewImagesScrollView.contentInset = insets
            self.ignorePreviewImagesScrollViewScroll = false
        }
    }
    
    // MARK: Layout
    
    private func getVideoContainerScrollViewFrame() -> CGRect {
        let w = view.bounds.width
        let l = min(UIDevice.current.userInterfaceIdiom == .pad ? 430.0 : w, 430.0)
        return CGRectMake((w - l) / 2.0, 100, l, l / 430.0 * 510.0)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        videoContainerScrollView.frame = getVideoContainerScrollViewFrame()
        maskView.frame = videoContainerScrollView.frame
        maskLayer.frame = maskView.bounds
        
        let oldFrame = cropAreaView.frame
        let f = videoContainerScrollView.frame.inset(by: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20))
        cropAreaView.frame = AVMakeRect(aspectRatio: cropSize, insideRect: f)
        
        if oldFrame != cropAreaView.frame {
            let path = UIBezierPath()
            path.append(.init(rect: maskView.bounds))
            path.append(.init(rect: maskView.convert(cropAreaView.bounds, from: cropAreaView)))
            maskLayer.path = path.cgPath
            maskLayer.fillRule = .evenOdd
            maskLayer.fillColor = UIColor.black.cgColor
        }
        
        var newSize = ISMakeRectAspectFill(aspectRatio: videoSize, insideRect: videoContainerScrollView.bounds).size
        newSize = CGSizeMake(floor(newSize.width), floor(newSize.height))
        let newBounds = CGRect(origin: .zero, size: newSize)
        if videoPreviewView.bounds != newBounds {
            videoPreviewView.bounds = newBounds
            playerLayer.frame = newBounds
            videoContainerScrollView.contentSize = videoPreviewView.bounds.size
            let minZoomScale = max(cropAreaView.bounds.width / newBounds.width, cropAreaView.bounds.height / newBounds.height)
            videoContainerScrollView.zoomScale = minZoomScale
            videoContainerScrollView.minimumZoomScale = minZoomScale
            videoContainerScrollView.maximumZoomScale = max(ceil(minZoomScale + 1), 5.0)
            
            let frame: CGRect = maskView.convert(cropAreaView.bounds, from: cropAreaView)
            videoContainerScrollView.contentInset = UIEdgeInsets(top: frame.minY, left: frame.minX, bottom: frame.minY, right: frame.minX)
            videoPreviewView.center = CGPointMake(videoPreviewView.bounds.midX, videoPreviewView.bounds.midY)
        }
        
        playButton.bounds = CGRectMake(0, 0, 100, 100)
        playButton.center = CGPointMake(maskView.frame.midX, maskView.frame.maxY + playButton.bounds.height * 0.5)
        
        previewImagesScrollView.bounds = CGRectMake(0, 0, maskView.frame.width, 105)
        previewImagesScrollView.center = CGPointMake(view.bounds.midX, playButton.frame.maxY + previewImagesScrollView.bounds.height * 0.5)
        cropTimeRangeView?.bounds = CGRectMake(0, 0, maskView.frame.width, 105)
        cropTimeRangeView?.center = CGPointMake(view.bounds.midX, playButton.frame.maxY + previewImagesScrollView.bounds.height * 0.5)
        
        cropButton.bounds = CGRectMake(0, 0, 100, 50)
        cropButton.center = CGPointMake(view.bounds.midX, previewImagesScrollView.frame.maxY + 10 + 50 * 0.5)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    private func updateTimeRangeViewFrame() {
        let scrollView = previewImagesScrollView
        let w = (endTime.seconds - startTime.seconds) * widthPerSecond
        let x = min(scrollView.contentSize.width - w, max(0, startTime.seconds * widthPerSecond))
        timeRangeView.frame = CGRectMake(x, 0, w, previewThumbSize.height)
        
        startTimeView.frame = CGRectMake(timeRangeView.frame.minX - 5 - 25, 0, 50, previewThumbSize.height)
        endTimeView.frame = CGRectMake(timeRangeView.frame.maxX + 5 - 25, 0, 50, previewThumbSize.height)
    }
    
    // MARK: Pan Gesture Handler
    
    private var centerX = 0.0
    private var centerMinX = 0.0
    private var centerMaxX = 0.0
    @objc private func handleStartTimePanGesture(gesture: UIPanGestureRecognizer) {
        let state = gesture.state
        let contentView = previewImagesScrollViewContentView
        let view = startTimeView
        let translateX = gesture.translation(in: contentView).x
        var x = view.center.x
        var isEnded = false
        if state == .began {
            centerX = view.center.x
            centerMinX = max(0, endTime.seconds - maxDuration) * widthPerSecond - 5
            centerMaxX = (endTime.seconds - minDuration) * widthPerSecond - 5.0
            
            x = centerX + translateX
            previewImagesScrollView.isUserInteractionEnabled = false
        }
        else if state == .changed {
            x = centerX + translateX
        }
        else if state == .cancelled || state == .ended {
            x = centerX + translateX
            isEnded = true
            previewImagesScrollView.isUserInteractionEnabled = true
        }
        x = max(min(centerMaxX, x), centerMinX)
        if centerMinX < centerMaxX && view.center.x != x {
            view.center = CGPointMake(x, view.center.y)
            let time = (x + 5) / contentView.bounds.width * videoDuration
            let timescale = max(startTime.timescale, 1000)
            let cmtime = CMTimeMake(value: Int64(time * Double(timescale)), timescale: timescale)
            if playerLayer.player?.rate != 0 {
                playerLayer.player?.pause()
            }
            playerLayer.player?.seek(to: cmtime, toleranceBefore: .zero, toleranceAfter: .zero)
            startTime = cmtime
        }
        progressIndicatorView.center = CGPointMake(startTime.seconds / videoDuration * previewImagesScrollViewContentView.bounds.width, timeRangeView.bounds.midY)

        if isEnded {
            updateTimeRangeViewFrame()
            updatePlayerStartEndTime()
            centerTimeRangeView()
        }
    }
    
    @objc private func handleEndTimePanGesture(gesture: UIPanGestureRecognizer) {
        let state = gesture.state
        let contentView = previewImagesScrollViewContentView
        let view = endTimeView
        let translateX = gesture.translation(in: contentView).x
        var x = view.center.x
        var isEnded = false
        if state == .began {
            centerX = view.center.x
            centerMinX = (startTime.seconds + minDuration) * widthPerSecond + 5
            centerMaxX = min(startTime.seconds + maxDuration, videoDuration) * widthPerSecond + 5.0
            
            x = centerX + translateX
            previewImagesScrollView.isUserInteractionEnabled = false
        }
        else if state == .changed {
            x = centerX + translateX
        }
        else if state == .cancelled || state == .ended {
            x = centerX + translateX
            isEnded = true
            previewImagesScrollView.isUserInteractionEnabled = true
        }
        x = max(min(centerMaxX, x), centerMinX)
        if centerMinX < centerMaxX && view.center.x != x {
            view.center = CGPointMake(x, view.center.y)
            let time = (x - 5) / contentView.bounds.width * videoDuration
            let timescale = max(endTime.timescale, 1000)
            let cmtime = CMTimeMake(value: Int64(time * Double(timescale)), timescale: timescale)
            if playerLayer.player?.rate != 0 {
                playerLayer.player?.pause()
            }
            playerLayer.player?.seek(to: cmtime, toleranceBefore: .zero, toleranceAfter: .zero)
            endTime = cmtime
        }
        progressIndicatorView.center = CGPointMake(endTime.seconds / videoDuration * previewImagesScrollViewContentView.bounds.width, timeRangeView.bounds.midY)
        
        if isEnded {
            updateTimeRangeViewFrame()
            updatePlayerStartEndTime()
            centerTimeRangeView()
        }
    }
    
    // MARK: Crop
    
    private func crop() {
        var cropRect = cropAreaView.convert(cropAreaView.bounds, to: videoPreviewView)
        cropRect.origin = CGPointMake(
            cropRect.minX / videoPreviewView.bounds.width * videoSize.width,
            cropRect.minY / videoPreviewView.bounds.height * videoSize.height
        )
        cropRect.size = CGSizeMake(
            cropRect.width / videoPreviewView.bounds.width * videoSize.width,
            cropRect.height / videoPreviewView.bounds.height * videoSize.height
        )
        let originFlipTransform = CGAffineTransform(scaleX: 1, y: -1)
        let frameTranslateTransform = CGAffineTransform(translationX: 0, y: videoSize.height)
        cropRect = cropRect.applying(originFlipTransform)
        cropRect = cropRect.applying(frameTranslateTransform)
        
        let asset = AVURLAsset(url: url)
        let cropScaleComposition = AVMutableVideoComposition(asset: asset) { request in
            guard let cropFilter = CIFilter(name: "CICrop") else {
                request.finish(with: request.sourceImage, context: nil)
                assert(false)
                return
            }
            
            cropFilter.setValue(request.sourceImage, forKey: kCIInputImageKey)
            cropFilter.setValue(CIVector(cgRect: cropRect), forKey: "inputRectangle")
            
            let imageAtOrigin = cropFilter.outputImage?.transformed(by: CGAffineTransform(translationX: -cropRect.origin.x, y: -cropRect.origin.y)) ?? request.sourceImage
            request.finish(with: imageAtOrigin, context: nil)
        }
        cropScaleComposition.renderSize = cropRect.size
        
        let outputPath = NSTemporaryDirectory() + UUID().uuidString + ".mp4"
        let outputURL = URL(fileURLWithPath: outputPath)
        
        let timeRange = CMTimeRangeFromTimeToTime(start: startTime, end: endTime)
        
        if let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) {
            exporter.videoComposition = cropScaleComposition
            exporter.outputURL = outputURL
            exporter.outputFileType = .mp4
            exporter.timeRange = timeRange
            exporter.exportAsynchronously { [weak exporter, weak self] in
                DispatchQueue.main.async {
                    if let error = exporter?.error {
                        debugPrint(error.localizedDescription)
                    } else {
                        NotificationCenter.default.post(name: NSNotification.Name("CropDone"), object: outputURL)
                        self?.dismiss(animated: true)
                    }
                }
            }
        } else {
            debugPrint("error")
        }
    }
}

extension ISVideoCropViewController: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        if scrollView == videoContainerScrollView {
            return videoPreviewView
        }
        return nil
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == previewImagesScrollView {
            let w = timeRangeView.bounds.width
            guard w > 0, !ignorePreviewImagesScrollViewScroll else { return }
            
            let contentView = previewImagesScrollViewContentView
            let pointInView = CGPointMake(scrollView.frame.midX - w * 0.5, 0)
            let pointInContentView = contentView.convert(pointInView, from: view)
            var x = min(contentView.bounds.width - w, max(0, pointInContentView.x))
            timeRangeView.frame = CGRectMake(x, 0, w, previewThumbSize.height)
            
            startTimeView.frame = CGRectMake(timeRangeView.frame.minX - 5 - 25, 0, 50, previewThumbSize.height)
            endTimeView.frame = CGRectMake(timeRangeView.frame.maxX + 5 - 25, 0, 50, previewThumbSize.height)
            
            x = timeRangeView.frame.minX
            var time = x / contentView.bounds.width * videoDuration
            let timescale = max(startTime.timescale, 1000)
            var cmtime = CMTimeMake(value: Int64(time * Double(timescale)), timescale: timescale)
            if playerLayer.player?.rate != 0 {
                playerLayer.player?.pause()
            }
            playerLayer.player?.seek(to: cmtime, toleranceBefore: .zero, toleranceAfter: .zero)
            startTime = cmtime
            
            x = timeRangeView.frame.maxX
            time = x / contentView.bounds.width * videoDuration
            cmtime = CMTimeMake(value: Int64(time * Double(timescale)), timescale: timescale)
            endTime = cmtime
            
            progressIndicatorView.center = CGPointMake(startTime.seconds / videoDuration * previewImagesScrollViewContentView.bounds.width, timeRangeView.bounds.midY)
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if scrollView == videoContainerScrollView {
            UIView.animate(withDuration: 0.3) {
                self.maskView.alpha = 0.75
            }
        }
    }
    
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        if scrollView == videoContainerScrollView {
            UIView.animate(withDuration: 0.3) {
                self.maskView.alpha = 0.75
            }
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if scrollView == videoContainerScrollView {
            UIView.animate(withDuration: 0.3, delay: 0.35) {
                self.maskView.alpha = 1.0
            }
        } else if scrollView == previewImagesScrollView {
            if !decelerate {
                // 完全停止后, 触发播放器更新播放范围
                updatePlayerStartEndTime()
            }
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if scrollView == previewImagesScrollView {
            // 完全停止后, 触发播放器更新播放范围
            updatePlayerStartEndTime()
        }
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        if scrollView == videoContainerScrollView {
            UIView.animate(withDuration: 0.3, delay: 0.35) {
                self.maskView.alpha = 1.0
            }
        }
    }
    
}

class ISCropAreaView: UIView {
    
    private var lineViews = [UIView(), UIView(), UIView(), UIView()]
    private var borderView = UIView()
    
    var lineAlpha: CGFloat {
        get {
            lineViews[0].alpha
        }
        set {
            lineViews.forEach { v in
                v.alpha = newValue
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        self.isUserInteractionEnabled = false
        
        addSubview(borderView)
        borderView.layer.borderColor = UIColor.white.cgColor
        borderView.layer.borderWidth = 1.0
        
        lineViews.forEach { v in
            v.backgroundColor = .white.withAlphaComponent(0.35)
            addSubview(v)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let w = bounds.width, h = bounds.height
        // 边框
        borderView.frame = CGRectMake(-1, -1, w + 2, h + 2)
        
        // 线条 横1
        lineViews[0].frame = CGRectMake(0, h / 3.0 * 1.0, w, 0.5)
        // 线条 横2
        lineViews[1].frame = CGRectMake(0, h / 3.0 * 2.0, w, 0.5)
        // 线条 竖1
        lineViews[2].frame = CGRectMake(w / 3.0 * 1.0, 0, 0.5, h)
        // 线条 竖2
        lineViews[3].frame = CGRectMake(w / 3.0 * 2.0, 0, 0.5, h)
    }
    
}

class ISCropTimeRangeView: UIView {
    
    var didStopScroll: ((ISCropTimeRangeView) -> Void)?
    var onStartTimeChanged: ((ISCropTimeRangeView) -> Void)?
    var onStartTimeChangeEnded: ((ISCropTimeRangeView) -> Void)?
    var onEndTimeChanged: ((ISCropTimeRangeView) -> Void)?
    var onEndTimeChangeEnded: ((ISCropTimeRangeView) -> Void)?
    
    let duration: Double // 时长, 单位: s
    let previewImages: [UIImage]
    private var previewImageViews: [UIImageView] = []
    private var scaleViews: [UIView] = [] // 刻度视图
    private var secondViews: [UIView] = [] // 刻度秒数
    
    var startTime: CMTime = .zero
    var endTime: CMTime = .zero
    
    var minDuration: Double = 0.5 // 最小选择时长, 单位: s
    var maxDuration: Double = 6.0 // 最大选择时长, 单位: s
    
    private var widthPerSecond: Double = 129.0 // 底部图片预览进图视图, 每秒对应宽度, 单位: pt
    let fps: Double
    var horizonInset: Double
    private var previewThumbSize: CGSize = CGSizeMake(30, 40)
    
    /// 当前进度指示器
    private let progressIndicatorView: UIView = UIView()
    
    private let previewImagesScrollView = UIScrollView()
    private let previewImagesScrollViewContentView: UIView = UIView()
    private let imageContentView = UIView()
    private var ignorePreviewImagesScrollViewScroll: Bool = false
    
    private let timeRangeView: UIView = UIView()
    private let startTimeView: UIView = UIView()
    private let endTimeView: UIView = UIView()
    private let startTimePanGesture: UIPanGestureRecognizer = UIPanGestureRecognizer()
    private let endTimePanGesture: UIPanGestureRecognizer = UIPanGestureRecognizer()
    
    init(duration: Double, previewImages: [UIImage], fps: Double, horizonInset: Double = 40, previewThumbSize: CGSize = CGSizeMake(30, 40)) {
        self.duration = duration
        self.previewImages = previewImages
        self.fps = fps
        self.horizonInset = horizonInset
        self.previewThumbSize = previewThumbSize
        super.init(frame: .zero)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("no imp")
    }
    
    private func setup() {
        addSubview(previewImagesScrollView)
        
        let contentView = previewImagesScrollViewContentView
        previewImagesScrollView.addSubview(contentView)
        
        previewImagesScrollView.addSubview(timeRangeView)
        previewImagesScrollView.addSubview(progressIndicatorView)
        previewImagesScrollView.addSubview(startTimeView)
        previewImagesScrollView.addSubview(endTimeView)
        
        progressIndicatorView.bounds = CGRectMake(0, 0, 2, previewThumbSize.height + 10)
        progressIndicatorView.center = CGPointMake(0, previewThumbSize.height * 0.5)
        progressIndicatorView.layer.cornerRadius = 1
        progressIndicatorView.backgroundColor = .white.withAlphaComponent(0.9)
        
        timeRangeView.layer.borderColor = UIColor.white.cgColor
        timeRangeView.layer.borderWidth = 1.0
        timeRangeView.backgroundColor = .clear
        startTimeView.backgroundColor = .white.withAlphaComponent(0.5)
        endTimeView.backgroundColor = .white.withAlphaComponent(0.5)
        
        startTimeView.addGestureRecognizer(startTimePanGesture)
        startTimePanGesture.addTarget(self, action: #selector(handleStartTimePanGesture(gesture:)))
        endTimeView.addGestureRecognizer(endTimePanGesture)
        endTimePanGesture.addTarget(self, action: #selector(handleEndTimePanGesture(gesture:)))
        
        // 最小选择时长 min(0.5, 视频时长)
        // 最大选择时长 min(6.0, 视频时长)
        minDuration = min(0.5, duration)
        maxDuration = min(6.0, duration)
        
        // 默认结束时间
        endTime = CMTimeMake(value: Int64(maxDuration * 1000), timescale: 1000)
        
        previewImagesScrollView.showsVerticalScrollIndicator = false
        previewImagesScrollView.showsHorizontalScrollIndicator = false
        
        previewImagesScrollView.delegate = self
        
        imageContentView.clipsToBounds = true
        contentView.addSubview(imageContentView)
        
        for image in previewImages {
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageContentView.addSubview(imageView)
            previewImageViews.append(imageView)
        }
        
        let first = 0
        let last = Int(duration * 10)
        for sec in first...last {
            let v = UIView()
            v.backgroundColor = .white
            contentView.addSubview(v)
            if sec % 10 == 0 {
                v.alpha = 1.0
            } else {
                v.alpha = 0.5
            }
            scaleViews.append(v)
            
            if (sec == first || abs(sec - last) < 10) && sec % 10 == 0 {
                let label = UILabel()
                label.text = "\(sec / 10)S"
                label.textColor = .white.withAlphaComponent(0.5)
                label.font = .systemFont(ofSize: 8)
                label.textAlignment = .center
                contentView.addSubview(label)
                
                secondViews.append(label)
            }
        }
    }
    
    static func calcFps(displayWidth w: Double, horizonInset: Double = 40.0, maxDuration: Double, previewThumbWidth: Double = 30.0) -> Double {
        assert(maxDuration > 0)
        let widthPerSecond = (w - horizonInset * 2) / maxDuration
        let fps = max(1.0, widthPerSecond / previewThumbWidth)
        return fps
    }
    
    func updateProgressIndicator(time: CMTime) {
        progressIndicatorView.center = CGPointMake(time.seconds / duration * previewImagesScrollViewContentView.bounds.width, timeRangeView.bounds.midY)
    }
    
    // MARK: Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewImagesScrollView.frame = bounds

        guard bounds.width > 0, bounds.height > 0,
              fps > 0, maxDuration > 0
        else {
            return
        }
        
        // 取展示宽度 w
        let w = bounds.width, h = bounds.height
        let sv = previewImagesScrollView
        // 左右间距默认 40
        sv.contentInset = UIEdgeInsets(top: 0, left: horizonInset, bottom: 0, right: horizonInset)
        // w - 40 * 2 -> 对应视频最大选择时长
        widthPerSecond = (w - sv.contentInset.left - sv.contentInset.right) / maxDuration
        // 小图预览宽高 previewThumbSize
        // 计算每秒取预览图帧数 fps = withPerSecond / previewThumbSize.width
        // fps = max(1.0, widthPerSecond / previewThumbSize.width)
        // fps固定, 计算更新 previewThumbSize.width
        previewThumbSize.width = widthPerSecond / fps
        
        previewImagesScrollView.contentSize = CGSizeMake(widthPerSecond * duration, h)
        let contentView = previewImagesScrollViewContentView
        contentView.frame = CGRect(origin: .zero, size: previewImagesScrollView.contentSize)
        imageContentView.frame = contentView.bounds
        
        var x = 0.0
        let imgW = previewThumbSize.width
        let imgH = previewThumbSize.height
        for imageView in previewImageViews {
            imageView.frame = CGRectMake(x, 0, imgW, imgH)
            x += imgW
        }
        
        x = 0
        let secSpacing = widthPerSecond / 10.0
        let first = 0
        let last = Int(duration * 10)
        for sec in first...last {
            let v = scaleViews[sec]
            v.frame = CGRectMake(x - 0.5, h - 20.0, 1, 4)
            
            if (sec == first || abs(sec - last) < 10) && sec % 10 == 0 {
                if let label = sec == first ? secondViews.first : secondViews.last {
                    label.bounds = CGRectMake(0, 0, 100, 12)
                    label.center = CGPointMake(v.center.x, v.center.y + 15.0)
                }
            }
            x += secSpacing
        }
        
        updateTimeRangeViewFrame()
        centerTimeRangeView()
    }
    
    private func updateTimeRangeViewFrame() {
        let scrollView = previewImagesScrollView
        let w = (endTime.seconds - startTime.seconds) * widthPerSecond
        let x = min(scrollView.contentSize.width - w, max(0, startTime.seconds * widthPerSecond))
        timeRangeView.frame = CGRectMake(x, 0, w, previewThumbSize.height)
        
        startTimeView.frame = CGRectMake(timeRangeView.frame.minX - 5 - 25, 0, 50, previewThumbSize.height)
        endTimeView.frame = CGRectMake(timeRangeView.frame.maxX + 5 - 25, 0, 50, previewThumbSize.height)
    }
    
    private func centerTimeRangeView() {
        ignorePreviewImagesScrollViewScroll = true
        
        let midX = bounds.midX
        let timeRangeViewMidX = convert(CGPointMake(timeRangeView.bounds.midX, 0), from: timeRangeView).x
        var offset = previewImagesScrollView.contentOffset
        offset.x += timeRangeViewMidX - midX
        UIView.animate(withDuration: 0.35) {
            self.previewImagesScrollView.contentOffset = offset
        } completion: { _ in
            var insets = self.previewImagesScrollView.contentInset
            let left = max(insets.left, (self.previewImagesScrollView.bounds.width - self.timeRangeView.bounds.width) * 0.5)
            insets.left = left
            insets.right = left
            self.previewImagesScrollView.contentInset = insets
            self.ignorePreviewImagesScrollViewScroll = false
        }
    }
    
    // MARK: Gesture Handlers
    
    private var centerX = 0.0
    private var centerMinX = 0.0
    private var centerMaxX = 0.0
    @objc private func handleStartTimePanGesture(gesture: UIPanGestureRecognizer) {
        let state = gesture.state
        let contentView = previewImagesScrollViewContentView
        let view = startTimeView
        let translateX = gesture.translation(in: contentView).x
        var x = view.center.x
        var isEnded = false
        if state == .began {
            centerX = view.center.x
            centerMinX = max(0, endTime.seconds - maxDuration) * widthPerSecond - 5
            centerMaxX = (endTime.seconds - minDuration) * widthPerSecond - 5.0
            
            x = centerX + translateX
            previewImagesScrollView.isUserInteractionEnabled = false
        }
        else if state == .changed {
            x = centerX + translateX
        }
        else if state == .cancelled || state == .ended {
            x = centerX + translateX
            isEnded = true
            previewImagesScrollView.isUserInteractionEnabled = true
        }
        x = max(min(centerMaxX, x), centerMinX)
        if centerMinX < centerMaxX && view.center.x != x {
            view.center = CGPointMake(x, view.center.y)
            let time = (x + 5) / contentView.bounds.width * duration
            let timescale = max(startTime.timescale, 1000)
            let cmtime = CMTimeMake(value: Int64(time * Double(timescale)), timescale: timescale)
//            if playerLayer.player?.rate != 0 {
//                playerLayer.player?.pause()
//            }
//            playerLayer.player?.seek(to: cmtime, toleranceBefore: .zero, toleranceAfter: .zero)
            startTime = cmtime
            onStartTimeChanged?(self)
        }
        updateProgressIndicator(time: startTime)

        if isEnded {
            updateTimeRangeViewFrame()
//            updatePlayerStartEndTime()
            centerTimeRangeView()
            onStartTimeChangeEnded?(self)
        }
    }
    
    @objc private func handleEndTimePanGesture(gesture: UIPanGestureRecognizer) {
        let state = gesture.state
        let contentView = previewImagesScrollViewContentView
        let view = endTimeView
        let translateX = gesture.translation(in: contentView).x
        var x = view.center.x
        var isEnded = false
        if state == .began {
            centerX = view.center.x
            centerMinX = (startTime.seconds + minDuration) * widthPerSecond + 5
            centerMaxX = min(startTime.seconds + maxDuration, duration) * widthPerSecond + 5.0
            
            x = centerX + translateX
            previewImagesScrollView.isUserInteractionEnabled = false
        }
        else if state == .changed {
            x = centerX + translateX
        }
        else if state == .cancelled || state == .ended {
            x = centerX + translateX
            isEnded = true
            previewImagesScrollView.isUserInteractionEnabled = true
        }
        x = max(min(centerMaxX, x), centerMinX)
        if centerMinX < centerMaxX && view.center.x != x {
            view.center = CGPointMake(x, view.center.y)
            let time = (x - 5) / contentView.bounds.width * duration
            let timescale = max(endTime.timescale, 1000)
            let cmtime = CMTimeMake(value: Int64(time * Double(timescale)), timescale: timescale)
//            if playerLayer.player?.rate != 0 {
//                playerLayer.player?.pause()
//            }
//            playerLayer.player?.seek(to: cmtime, toleranceBefore: .zero, toleranceAfter: .zero)
            endTime = cmtime
            onEndTimeChanged?(self)
        }
        updateProgressIndicator(time: endTime)
        
        if isEnded {
            updateTimeRangeViewFrame()
//            updatePlayerStartEndTime()
            centerTimeRangeView()
            onEndTimeChangeEnded?(self)
        }
    }
}

extension ISCropTimeRangeView: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let w = timeRangeView.bounds.width
        guard w > 0, !ignorePreviewImagesScrollViewScroll else { return }
        
        let contentView = previewImagesScrollViewContentView
        let pointInView = CGPointMake(scrollView.frame.midX - w * 0.5, 0)
        let pointInContentView = contentView.convert(pointInView, from: self)
        var x = min(contentView.bounds.width - w, max(0, pointInContentView.x))
        timeRangeView.frame = CGRectMake(x, 0, w, previewThumbSize.height)
        
        startTimeView.frame = CGRectMake(timeRangeView.frame.minX - 5 - 25, 0, 50, previewThumbSize.height)
        endTimeView.frame = CGRectMake(timeRangeView.frame.maxX + 5 - 25, 0, 50, previewThumbSize.height)
        
        x = timeRangeView.frame.minX
        var time = x / contentView.bounds.width * duration
        let timescale = max(startTime.timescale, 1000)
        var cmtime = CMTimeMake(value: Int64(time * Double(timescale)), timescale: timescale)
//        if playerLayer.player?.rate != 0 {
//            playerLayer.player?.pause()
//        }
//        playerLayer.player?.seek(to: cmtime, toleranceBefore: .zero, toleranceAfter: .zero)
        startTime = cmtime
        onStartTimeChanged?(self)
        
        x = timeRangeView.frame.maxX
        time = x / contentView.bounds.width * duration
        cmtime = CMTimeMake(value: Int64(time * Double(timescale)), timescale: timescale)
        endTime = cmtime
        
        updateProgressIndicator(time: startTime)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            // 完全停止后, 触发播放器更新播放范围
            didStopScroll?(self)
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // 完全停止后, 触发播放器更新播放范围
        didStopScroll?(self)
    }
    
}
