//
//  ISVideoCropViewController.swift
//  trim-crop-video
//
//  Created by 官泉华 on 2025/5/14.
//

import UIKit
import AVFoundation

class ISVideoCropViewController: YZDBaseVC {
    
    var cropDidFinished: ((_ croppedVideoUrl: URL) -> Void)?
    
    let asset: AVAsset
    let cropSize: CGSize
    let player: AVPlayer
    
    private var navigationView = ISNavigationView()
    private var videoPreviewView: ISVideoCropPreviewView
    private var timeRangeView: ISTimeRangeSelectView?
    
    private var playButton = UIButton(type: .custom)
    
    private var exportProgressTimer: Timer?
    
    private var startTime: CMTime {
        let ts = Int32(1000)
        return CMTimeMake(value: Int64((timeRangeView?.startTime ?? 0.0) * Double(ts)), timescale: ts)
    }
    
    private var endTime: CMTime {
        let ts = Int32(1000)
        return CMTimeMake(value: Int64((timeRangeView?.endTime ?? 0.0) * Double(ts)), timescale: ts)
    }
    
    init(asset: AVAsset, cropSize: CGSize) {
        self.asset = asset
        self.cropSize = cropSize
        self.player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        self.videoPreviewView = ISVideoCropPreviewView(player: player, cropSize: cropSize)
        super.init(nibName: nil, bundle: nil)
    }
    
    init(url: URL, cropSize: CGSize) {
        self.asset = AVURLAsset(url: url)
        self.cropSize = cropSize
        self.player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        self.videoPreviewView = ISVideoCropPreviewView(player: player, cropSize: cropSize)
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
        
        view.addSubview(navigationView)
        navigationView.onClose = { [weak self] in
            self?.close()
        }
        navigationView.onConfirm = { [weak self] in
            self?.done()
        }
        
        view.addSubview(videoPreviewView)
        videoPreviewView.playerCurrentTimeChanged = { [weak self] time in
            self?.timeRangeView?.updateProgressIndicator(time: time.seconds)
        }
        videoPreviewView.playerPlayingStateChanged = { [weak self] isPlaying in
            self?.playButton.isSelected = isPlaying
        }
        
        view.addSubview(playButton)
        playButton.setImage(UIImage(named: "diyLivePhotoPlay"), for: .normal)
        playButton.setImage(UIImage(named: "diyLivePhotoPause"), for: .selected)
        playButton.isSelected = false
        playButton.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        playButton.addAction(.init(handler: { [weak self] _ in
            guard let self else { return }
            self.videoPreviewView.playOrPause(startTime: self.startTime, endTime: self.endTime)
        }), for: .touchUpInside)
        
        let videoDuration = CMTimeGetSeconds(asset.duration)
        let maxDuration = min(6.0, videoDuration)
        let w = getVideoPreviewViewBounds().width // 预览视图展示宽度 w
        let fps = ISTimeRangeSelectView.calcFps(displayWidth: w, maxDuration: maxDuration)
        
        let isIpad = UIDevice.current.userInterfaceIdiom == .pad
        let previewThumbSize = isIpad ? CGSizeMake(60, 80) : CGSizeMake(30, 40)
        
        getVideoPreviewImages(fps: fps, previewThumbSize: previewThumbSize) { [weak self] images in
            guard let self else { return }
            
            let horizonInset = isIpad ? 80.0 : 40.0
            let cropTimeRangeView = ISTimeRangeSelectView(duration: videoDuration, previewImages: images, fps: fps, horizonInset: horizonInset, previewThumbSize: previewThumbSize)
            cropTimeRangeView.didStopScroll = { [weak self] v in
                // 完全停止后, 触发播放器更新播放范围
                guard let startTime = self?.startTime, let endTime = self?.endTime else { return }
                self?.videoPreviewView.updatePlayerStartEndTime(startTime: startTime, endTime: endTime)
            }
            cropTimeRangeView.onStartTimeChanged = { [weak self] v in
                guard let self else { return }
                
                if self.videoPreviewView.isPlaying {
                    self.videoPreviewView.pause()
                }
                self.videoPreviewView.seek(to: self.startTime)
            }
            cropTimeRangeView.onEndTimeChanged = { [weak self] v in
                guard let self else { return }
                
                if self.videoPreviewView.isPlaying {
                    self.videoPreviewView.pause()
                }
                self.videoPreviewView.seek(to: self.endTime)
            }
            cropTimeRangeView.onStartTimeChangeEnded = { [weak self] v in
                guard let startTime = self?.startTime, let endTime = self?.endTime else { return }
                self?.videoPreviewView.updatePlayerStartEndTime(startTime: startTime, endTime: endTime)
            }
            cropTimeRangeView.onEndTimeChangeEnded = { [weak self] v in
                guard let startTime = self?.startTime, let endTime = self?.endTime else { return }
                self?.videoPreviewView.updatePlayerStartEndTime(startTime: startTime, endTime: endTime)
            }
            self.timeRangeView = cropTimeRangeView
            self.view.addSubview(cropTimeRangeView)
            self.view.setNeedsLayout()
        }
    }
    
    private func getVideoPreviewImages(fps: Double, previewThumbSize: CGSize, complete: (([UIImage]) -> Void)?) {
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
        if let lastTime = times.last?.timeValue, CMTimeGetSeconds(lastTime) < duration {
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
        let timeValues = times.map({ $0.timeValue })
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
                for time in timeValues {
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
    
    // MARK: Layout
    
    private func getVideoPreviewViewBounds() -> CGRect {
        let w = view.bounds.width, h = view.bounds.height
        var l = w
        if UIDevice.current.userInterfaceIdiom == .pad {
            l = (600.0 / 843.0) * min(w, h)
        }
        return CGRectMake(0, 0, l, l)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        navigationView.frame = CGRectMake(0, view.safeAreaInsets.top, view.bounds.width, 44)
        
        let isIpad = UIDevice.current.userInterfaceIdiom == .pad
        videoPreviewView.bounds = getVideoPreviewViewBounds()
        videoPreviewView.center = CGPointMake(view.bounds.midX, navigationView.frame.maxY + (isIpad ? 50 : 30) + videoPreviewView.bounds.height * 0.5)
        
        let w = (isIpad ? 60.0 : 48.0) + 20.0
        playButton.bounds = CGRectMake(0, 0, w, w)
        playButton.center = CGPointMake(videoPreviewView.frame.midX, videoPreviewView.frame.maxY + playButton.bounds.height * 0.5)
        
        let h = isIpad ? 202.0 : 101.0
        timeRangeView?.bounds = CGRectMake(0, 0, view.frame.width, h)
        timeRangeView?.center = CGPointMake(view.bounds.midX, playButton.frame.maxY + (isIpad ? 40.0 : 16.0) + h * 0.5)
    }
    
    // MARK: Actions
    
    private func close() {
        if let navc = self.navigationController, navc.viewControllers.count > 1 {
            navc.popViewController(animated: true)
        } else {
            self.dismiss(animated: true)
        }
    }
    
    private func done() {
        self.crop()
    }
    
    // MARK: Crop & Export
    
    private func crop() {
        let cropRect = videoPreviewView.cropRect
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
            // 监听导出进度
            navigationView.progressView.progress = 0.1
            exportProgressTimer = Timer(timeInterval: 0.05, repeats: true, block: { [weak exporter, weak self] _ in
                if let progress = exporter?.progress {
                    self?.navigationView.progressView.progress = max(0.1, CGFloat(progress))
                    if progress >= 1.0, self?.exportProgressTimer?.isValid == true {
                        self?.exportProgressTimer?.invalidate()
                    }
                }
            })
            navigationView.hideProgress(hide: false)
            
            exporter.videoComposition = cropScaleComposition
            exporter.outputURL = outputURL
            exporter.outputFileType = .mp4
            exporter.timeRange = timeRange
            exporter.exportAsynchronously {
                DispatchQueue.main.async { [weak exporter, weak self] in
                    self?.navigationView.progressView.progress = 1
                    if self?.exportProgressTimer?.isValid == true {
                        self?.exportProgressTimer?.invalidate()
                    }
                    
                    if let error = exporter?.error {
                        debugPrint(error.localizedDescription)
                    } else {
                        // 导出成功回调, 然后关闭页面
                        self?.cropDidFinished?(outputURL)
                        self?.close()
                    }
                }
            }
        } else {
            debugPrint("error")
        }
    }
}

class ISNavigationView: UIView {
    
    var onClose: (() -> Void)?
    var onConfirm: (() -> Void)?
    
    let backButton = UIButton(type: .custom)
    let titleLabel = UILabel()
    let doneButton = UIButton(type: .custom)
    let progressView = QGCircularProgressView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        addSubview(backButton)
        addSubview(titleLabel)
        addSubview(doneButton)
        addSubview(progressView)
        
        backButton.yzd.sizeEqualTo(44, 44).leading(16).top().end()
        let backImageView = UIImageView(image: UIImage(named: "arrow_left_24")?.withRenderingMode(.alwaysTemplate))
        backImageView.isUserInteractionEnabled = false
        backImageView.tintColor = .white
        backButton.addSubview(backImageView)
        backImageView.yzd.sizeEqualTo(24, 24).center().end()
        backButton.addAction(.init(handler: { [weak self] _ in
            self?.onClose?()
        }), for: .touchUpInside)
        
        doneButton.setTitle("完成"/*.L*/, for: .normal) // TODO: guan
        doneButton.setTitleColor(.tinctBlue, for: .normal)
        doneButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        doneButton.addAction(.init(handler: { [weak self] _ in
            self?.onConfirm?()
        }), for: .touchUpInside)
        doneButton.yzd.sizeEqualTo(60, 44).trailing().top().end()
        
        progressView.isHidden = true
        progressView.lineWidth = 1.5
        progressView.progressTintColor = .white
        progressView.trackTintColor = .white.withAlphaComponent(0.5)
        progressView.progressTextFont = .systemFont(ofSize: 8, weight: .medium)
        progressView.showProgressText = true
        progressView.yzd.center(equalTo: doneButton).sizeEqualTo(26, 26).end()
        
        titleLabel.text = "调整"//.L // TODO: guan
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.yzd.leadingEqualTo(anchor: backButton.trailingAnchor)
            .trailingEqualTo(anchor: doneButton.leadingAnchor)
            .centerY().height()
            .end()
    }
    
    func hideProgress(hide: Bool = true) {
        progressView.isHidden = hide
        doneButton.isHidden = !hide
    }
}

class ISVideoCropPreviewView: UIView, UIScrollViewDelegate {
    
    private var player: AVPlayer
    private var videoSize: CGSize = .zero
    private var cropSize: CGSize
    
    private var videoContainerScrollView = UIScrollView()
    private var (videoMaskView, videoMaskLayer) = (UIView(), CAShapeLayer())
    private var cropAreaView = ISCropAreaView()
    private var (videoPreviewView, playerLayer, playButton) = (UIView(), AVPlayerLayer(), UIButton(type: .custom))
    
    private var endTimeObserver: Any?
    private var periodicTimeObserver: Any?
    
    var playerCurrentTimeChanged: ((_ time: CMTime) -> Void)?
    var playerPlayingStateChanged: ((_ isPlaying: Bool) -> Void)?
    
    var cropRect: CGRect {
        var cropRect = cropAreaView.convert(cropAreaView.bounds, to: videoPreviewView)
        let videoPreviewSize = videoPreviewView.bounds.size
        cropRect.origin = CGPointMake(
            cropRect.minX / videoPreviewSize.width * videoSize.width,
            cropRect.minY / videoPreviewSize.height * videoSize.height
        )
        cropRect.size = CGSizeMake(
            cropRect.width / videoPreviewSize.width * videoSize.width,
            cropRect.height / videoPreviewSize.height * videoSize.height
        )
        let originFlipTransform = CGAffineTransform(scaleX: 1, y: -1)
        let frameTranslateTransform = CGAffineTransform(translationX: 0, y: videoSize.height)
        cropRect = cropRect.applying(originFlipTransform)
        cropRect = cropRect.applying(frameTranslateTransform)
        
        return cropRect
    }
    
    var isPlaying: Bool {
        player.rate != 0
    }
    
    init(player: AVPlayer, cropSize: CGSize) {
        self.player = player
        self.cropSize = cropSize
        super.init(frame: .zero)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("no imp: ISVideoCropPreviewView")
    }
    
    private func setup() {
        addSubview(videoContainerScrollView)
        videoContainerScrollView.addSubview(videoPreviewView)
        videoMaskView.layer.addSublayer(videoMaskLayer)
        addSubview(videoMaskView)
        addSubview(cropAreaView)
        
        videoContainerScrollView.delegate = self
        videoContainerScrollView.showsHorizontalScrollIndicator = false
        videoContainerScrollView.showsVerticalScrollIndicator = false
        videoMaskView.isUserInteractionEnabled = false
        cropAreaView.isUserInteractionEnabled = false
        
        videoPreviewView.layer.addSublayer(playerLayer)
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspect
        
        if let track = player.currentItem?.asset.tracks(withMediaType: .video).first {
            let size = track.naturalSize.applying(track.preferredTransform)
            videoSize = CGSizeMake(abs(size.width), abs(size.height))
        } else {
            assert(false)
            videoSize = CGSizeMake(512, 512)
        }
        
        player.volume = 0
        player.pause()
        playerPlayingStateChanged?(false)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        videoContainerScrollView.frame = bounds
        videoMaskView.frame = videoContainerScrollView.frame
        videoMaskLayer.frame = videoMaskView.bounds
        
        let oldFrame = cropAreaView.frame
        let tempFrame = videoContainerScrollView.frame.inset(by: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20))
        cropAreaView.frame = AVMakeRect(aspectRatio: cropSize, insideRect: tempFrame)
        
        if oldFrame != cropAreaView.frame {
            let path = UIBezierPath()
            path.append(.init(rect: videoMaskView.bounds))
            path.append(.init(rect: videoMaskView.convert(cropAreaView.bounds, from: cropAreaView)))
            videoMaskLayer.path = path.cgPath
            videoMaskLayer.fillRule = .evenOdd
            videoMaskLayer.fillColor = UIColor.black.cgColor
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
            
            let frame: CGRect = videoMaskView.convert(cropAreaView.bounds, from: cropAreaView)
            videoContainerScrollView.contentInset = UIEdgeInsets(top: frame.minY, left: frame.minX, bottom: frame.minY, right: frame.minX)
            videoPreviewView.center = CGPointMake(videoPreviewView.bounds.midX, videoPreviewView.bounds.midY)
        }
    }
    
    func updatePlayerStartEndTime(startTime: CMTime, endTime: CMTime) {
        if let observer = endTimeObserver {
            player.removeTimeObserver(observer)
            endTimeObserver = nil
        }
        endTimeObserver = player.addBoundaryTimeObserver(forTimes: [NSValue(time: endTime)], queue: .main, using: { [weak self] in
            guard let self else { return }
            
            let player = self.player
            player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
            player.play()
        })
    }
    
    func playOrPause(startTime: CMTime, endTime: CMTime) {
        if let observer = self.periodicTimeObserver {
            player.removeTimeObserver(observer)
            self.periodicTimeObserver = nil
        }
        if isPlaying {
            player.pause()
        } else {
            self.periodicTimeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 60), queue: .main) { [weak self] _ in
                guard let self else { return }
                self.playerCurrentTimeChanged?(self.player.currentTime())
            }
            if abs(player.currentTime().seconds - endTime.seconds) < 0.01 {
                player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
            }
            player.play()
        }
        
        playerPlayingStateChanged?(isPlaying)
    }
    
    func play() {
        player.play()
        playerPlayingStateChanged?(isPlaying)
    }
    
    func pause() {
        player.pause()
        playerPlayingStateChanged?(isPlaying)
    }
    
    func seek(to time: CMTime) {
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    // MARK: UIScrollViewDelegate
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return videoPreviewView
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        UIView.animate(withDuration: 0.3) {
            self.videoMaskView.alpha = 0.75
        }
    }
    
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        UIView.animate(withDuration: 0.3) {
            self.videoMaskView.alpha = 0.75
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        UIView.animate(withDuration: 0.3, delay: 0.35) {
            self.videoMaskView.alpha = 1.0
        }
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        UIView.animate(withDuration: 0.3, delay: 0.35) {
            self.videoMaskView.alpha = 1.0
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

class ISTimeRangeSelectView: UIView, UIScrollViewDelegate {
    
    var didStopScroll: ((ISTimeRangeSelectView) -> Void)?
    var onStartTimeChanged: ((ISTimeRangeSelectView) -> Void)?
    var onStartTimeChangeEnded: ((ISTimeRangeSelectView) -> Void)?
    var onEndTimeChanged: ((ISTimeRangeSelectView) -> Void)?
    var onEndTimeChangeEnded: ((ISTimeRangeSelectView) -> Void)?
    
    let duration: Double // 时长, 单位: s
    let previewImages: [UIImage]
    private var previewImageViews: [UIImageView] = []
    private var scaleViews: [UIView] = [] // 刻度视图
    private var secondViews: [UILabel] = [] // 刻度秒数
    private var selectedSecondViews: [UILabel] = [] // 选中视频秒数刻度
    private var selectedSecondDotViews: [UIView] = [] // 选中视频秒数刻度左侧分隔点
    
    var startTime: Double = 0
    var endTime: Double = 0
    
    var minDuration: Double = 0.5 // 最小选择时长, 单位: s
    var maxDuration: Double = 6.0 // 最大选择时长, 单位: s
    
    private var widthPerSecond: Double = 129.0 // 底部图片预览进图视图, 每秒对应宽度, 单位: pt
    let fps: Double
    var horizonInset: Double
    private(set) var previewThumbSize: CGSize
    
    private var r = 1.0
    
    /// 当前进度指示器
    private let progressIndicatorView: UIView = UIView()
    
    private let previewImagesScrollView = UIScrollView()
    private let previewImagesScrollViewContentView: UIView = UIView()
    private let imageContentView = UIView()
    private var ignorePreviewImagesScrollViewScroll: Bool = false
    
    private let timeRangeView: UIView = UIView()
    
    private let startTimeView: UIImageView = UIImageView(image: UIImage(named: "start_time_icon"))
    private let endTimeView: UIImageView = UIImageView(image: UIImage(named: "end_time_icon"))
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
        
        progressIndicatorView.backgroundColor = .white.withAlphaComponent(0.9)
        
        timeRangeView.layer.borderColor = UIColor.white.cgColor
        timeRangeView.backgroundColor = .clear
        startTimeView.contentMode = .scaleAspectFit
        startTimeView.isUserInteractionEnabled = true
        endTimeView.contentMode = .scaleAspectFit
        endTimeView.isUserInteractionEnabled = true
        
        startTimeView.addGestureRecognizer(startTimePanGesture)
        startTimePanGesture.addTarget(self, action: #selector(handleStartTimePanGesture(gesture:)))
        endTimeView.addGestureRecognizer(endTimePanGesture)
        endTimePanGesture.addTarget(self, action: #selector(handleEndTimePanGesture(gesture:)))
        
        // 最小选择时长 min(0.5, 视频时长)
        // 最大选择时长 min(6.0, 视频时长)
        minDuration = min(0.5, duration)
        maxDuration = min(6.0, duration)
        
        // 默认结束时间
        endTime = maxDuration
        
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
                label.textAlignment = .center
                contentView.addSubview(label)
                
                secondViews.append(label)
            }
        }
        
        assert(maxDuration < 10, "不支持")
        for sec in 0...Int(maxDuration) {
            let label = UILabel()
            label.bounds = CGRectMake(0, 0, 100, 26)
            label.text = "00:\(String(format: "%02d", sec))"
            label.textColor = .white.withAlphaComponent(0.5)
            label.textAlignment = .center
            timeRangeView.addSubview(label)
            selectedSecondViews.append(label)
            
            let dot = UIView()
            dot.bounds = CGRectMake(0, 0, 0.5, 0.5)
            dot.backgroundColor = .white.withAlphaComponent(sec == 0 ? 0.0 : 0.5)
            timeRangeView.addSubview(dot)
            selectedSecondDotViews.append(dot)
        }
    }
    
    static func calcFps(displayWidth w: Double, horizonInset: Double = 40.0, maxDuration: Double, previewThumbWidth: Double = 30.0) -> Double {
        assert(maxDuration > 0)
        let widthPerSecond = (w - horizonInset * 2) / maxDuration
        let fps = max(1.0, widthPerSecond / previewThumbWidth)
        return fps
    }
    
    func updateProgressIndicator(time: Double) {
        progressIndicatorView.center = CGPointMake(time / duration * previewImagesScrollViewContentView.bounds.width, progressIndicatorView.center.y)
    }
    
    private func updateSelectSecondViews() {
        let selectDuration = endTime - startTime
        for sec in 0...Int(maxDuration) {
            let shown = Double(sec) <= selectDuration
            let secLabel = selectedSecondViews[sec]
            secLabel.isHidden = !shown
            let dotLabel = selectedSecondDotViews[sec]
            dotLabel.isHidden = !shown
        }
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
        r = h / 101.0
        let sv = previewImagesScrollView
        // 左右间距 horizonInset
        sv.contentInset = UIEdgeInsets(top: 0, left: horizonInset, bottom: 0, right: horizonInset)
        // w - horizonInset * 2 -> 对应视频最大选择时长
        widthPerSecond = (w - sv.contentInset.left - sv.contentInset.right) / maxDuration
        // 小图预览宽高 previewThumbSize
        // 计算每秒取预览图帧数 fps = withPerSecond / previewThumbSize.width
        // fps = max(1.0, widthPerSecond / previewThumbSize.width)
        // fps固定, 计算更新 previewThumbSize.width
        previewThumbSize.width = widthPerSecond / fps
        
        previewImagesScrollView.contentSize = CGSizeMake(widthPerSecond * duration, h)
        let contentView = previewImagesScrollViewContentView
        contentView.frame = CGRect(origin: .zero, size: previewImagesScrollView.contentSize)
        imageContentView.frame = CGRectMake(0, 27 * r, contentView.bounds.width, previewThumbSize.height)
        
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
            v.frame = CGRectMake(x - 0.5 * r, h - 19 * r, 1 * r, 4 * r)
            
            if (sec == first || abs(sec - last) < 10) && sec % 10 == 0 {
                if let label = sec == first ? secondViews.first : secondViews.last {
                    label.bounds = CGRectMake(0, 0, 100 * r, 13 * r)
                    label.center = CGPointMake(v.center.x, v.center.y + (4.0 + 6.5) * r)
                    label.font = .systemFont(ofSize: 9 * r, weight: .regular)
                }
            }
            x += secSpacing
        }
        
        let selectDuration = endTime - startTime
        let selectViewCenterY = -18.5 * r
        for sec in 0...Int(maxDuration) {
            let shown = Double(sec) <= selectDuration
            let secLabel = selectedSecondViews[sec]
            secLabel.font = .systemFont(ofSize: 9 * r, weight: .regular)
            secLabel.isHidden = !shown
            secLabel.center = CGPointMake(Double(sec) * widthPerSecond, selectViewCenterY)
            let dot = selectedSecondDotViews[sec]
            dot.isHidden = !shown
            dot.center = CGPointMake((Double(sec) - 0.5) * widthPerSecond, selectViewCenterY)
        }
        
        progressIndicatorView.bounds = CGRectMake(0, 0, 2 * r, 70 * r)
        progressIndicatorView.center = CGPointMake(0, (17.0 + 70.0 * 0.5) * r)
        progressIndicatorView.layer.cornerRadius = 1 * r
        
        timeRangeView.layer.borderWidth = 2 * r
        
        updateTimeRangeViewFrame()
        centerTimeRangeView()
    }
    
    private func updateTimeRangeViewFrame(updateStartEndTime: Bool = true) {
        let scrollView = previewImagesScrollView
        let w = (endTime - startTime) * widthPerSecond
        let x = min(scrollView.contentSize.width - w, max(0, startTime * widthPerSecond))
        timeRangeView.frame = CGRectMake(x, 25.0 * r, w, previewThumbSize.height + 4 * r)
        
        if updateStartEndTime {
            startTimeView.frame = CGRectMake(timeRangeView.frame.minX - 5 * r - 25, timeRangeView.frame.minY, 50, previewThumbSize.height + 4 * r)
            endTimeView.frame = CGRectMake(timeRangeView.frame.maxX + 5 * r - 25, timeRangeView.frame.minY, 50, previewThumbSize.height + 4 * r)
        }
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
            self.horizonInset = left
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
            centerMinX = max(0, endTime - maxDuration) * widthPerSecond - 5
            centerMaxX = (endTime - minDuration) * widthPerSecond - 5.0
            
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
            startTime = (x + 5) / contentView.bounds.width * duration
            onStartTimeChanged?(self)
        }
        updateProgressIndicator(time: startTime)
        updateSelectSecondViews()

        if isEnded {
            updateTimeRangeViewFrame()
            centerTimeRangeView()
            onStartTimeChangeEnded?(self)
        } else {
            updateTimeRangeViewFrame(updateStartEndTime: false)
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
            centerMinX = (startTime + minDuration) * widthPerSecond + 5
            centerMaxX = min(startTime + maxDuration, duration) * widthPerSecond + 5.0
            
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
            endTime = (x - 5) / contentView.bounds.width * duration
            onEndTimeChanged?(self)
        }
        updateProgressIndicator(time: endTime)
        updateSelectSecondViews()
        
        if isEnded {
            updateTimeRangeViewFrame()
            centerTimeRangeView()
            onEndTimeChangeEnded?(self)
        } else {
            updateTimeRangeViewFrame(updateStartEndTime: false)
        }
    }
    
    // MARK: UIScrollViewDelegate
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let w = timeRangeView.bounds.width
        guard w > 0, !ignorePreviewImagesScrollViewScroll else { return }
        
        let contentView = previewImagesScrollViewContentView
        let pointInView = CGPointMake(scrollView.frame.midX - w * 0.5, 0)
        let pointInContentView = contentView.convert(pointInView, from: self)
        var x = min(contentView.bounds.width - w, max(0, pointInContentView.x))
        timeRangeView.frame = CGRectMake(x, timeRangeView.frame.minY, w, timeRangeView.frame.height)
        
        startTimeView.frame = CGRectMake(
            timeRangeView.frame.minX - 5 * r - 25,
            startTimeView.frame.minY,
            startTimeView.frame.width,
            startTimeView.frame.height
        )
        endTimeView.frame = CGRectMake(
            timeRangeView.frame.maxX + 5 * r - 25,
            endTimeView.frame.minY,
            endTimeView.frame.width,
            endTimeView.frame.height
        )
        
        x = timeRangeView.frame.minX
        startTime = x / contentView.bounds.width * duration
        onStartTimeChanged?(self)
        
        x = timeRangeView.frame.maxX
        endTime = x / contentView.bounds.width * duration
        
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
