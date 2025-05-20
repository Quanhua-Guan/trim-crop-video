//
//  ISGifCropViewController.swift
//  trim-crop-video
//
//  Created by 官泉华 on 2025/5/20.
//

import UIKit
import AVFoundation

/// 动图裁剪页(支持裁剪图片大小和时间)
class ISGifCropViewController: YZDBaseVC {
    
    var cropDidFinished: ((_ croppedImages: [UIImage], _ duration: Double) -> Void)?
    
    let gifImage: UIImage
    let cropSize: CGSize
    
    private var navigationView = ISNavigationView()
    private var gifPreviewView: ISGifCropPreviewView
    private var timeRangeView: ISTimeRangeSelectView?
    
    private var playButton = UIButton(type: .custom)
    
    private var startTime: Double {
        timeRangeView?.startTime ?? 0.0
    }
    
    private var endTime: Double {
        timeRangeView?.endTime ?? 0.0
    }
    
    init(image: UIImage, cropSize: CGSize) {
        assert(image.images != nil && image.duration > 0)
        self.gifImage = image
        self.cropSize = cropSize
        self.gifPreviewView = ISGifCropPreviewView(image: image, cropSize: cropSize)
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
        
        view.addSubview(gifPreviewView)
        gifPreviewView.currentTimeChanged = { [weak self] time in
            self?.timeRangeView?.updateProgressIndicator(time: time)
        }
        gifPreviewView.playingStateChanged = { [weak self] isPlaying in
            self?.playButton.isSelected = isPlaying
        }
        
        view.addSubview(playButton)
        playButton.setImage(UIImage(named: "diyLivePhotoPlay")?.withRenderingMode(.alwaysTemplate), for: .normal)
        playButton.setImage(UIImage(named: "diyLivePhotoPause")?.withRenderingMode(.alwaysTemplate), for: .selected)
        playButton.imageView?.tintColor = .white
        playButton.isSelected = false
        playButton.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        playButton.addAction(.init(handler: { [weak self] _ in
            guard let self else { return }
            self.gifPreviewView.playOrPause()
        }), for: .touchUpInside)
        
        let gifDuration = gifImage.duration
        let maxDuration = min(6.0, gifDuration)
        let fps = ISTimeRangeSelectView.calcFps(displayWidth: view.bounds.width, maxDuration: maxDuration)
        
        let isIpad = UIDevice.current.userInterfaceIdiom == .pad
        let previewThumbSize = isIpad ? CGSizeMake(60, 80) : CGSizeMake(30, 40)
        let images = getGifPreviewImages(fps: fps)
        let horizonInset = isIpad ? 80.0 : 40.0
        let cropTimeRangeView = ISTimeRangeSelectView(duration: gifDuration, previewImages: images, fps: fps, horizonInset: horizonInset, previewThumbSize: previewThumbSize, defaultMinDuration: 0.3)
        cropTimeRangeView.didStopScroll = { [weak self] v in
            // 完全停止后, 触发播放器更新播放范围
            guard let startTime = self?.startTime, let endTime = self?.endTime else { return }
            self?.gifPreviewView.updatePlayerStartEndTime(startTime: startTime, endTime: endTime)
        }
        cropTimeRangeView.onStartTimeChanged = { [weak self] v in
            guard let self else { return }
            
            if self.gifPreviewView.isPlaying {
                self.gifPreviewView.pause()
            }
            self.gifPreviewView.seek(to: self.startTime)
        }
        cropTimeRangeView.onEndTimeChanged = { [weak self] v in
            guard let self else { return }
            
            if self.gifPreviewView.isPlaying {
                self.gifPreviewView.pause()
            }
            self.gifPreviewView.seek(to: self.endTime)
        }
        cropTimeRangeView.onStartTimeChangeEnded = { [weak self] v in
            guard let startTime = self?.startTime, let endTime = self?.endTime else { return }
            self?.gifPreviewView.updatePlayerStartEndTime(startTime: startTime, endTime: endTime)
        }
        cropTimeRangeView.onEndTimeChangeEnded = { [weak self] v in
            guard let startTime = self?.startTime, let endTime = self?.endTime else { return }
            self?.gifPreviewView.updatePlayerStartEndTime(startTime: startTime, endTime: endTime)
        }
        timeRangeView = cropTimeRangeView
        view.addSubview(cropTimeRangeView)
    }
    
    private func getGifPreviewImages(fps: Double) -> [UIImage] {
        let images = gifImage.images ?? []
        let duration = gifImage.duration
        let targetCount = Int(ceil(duration * fps))
        let imageCount = images.count
        
        var resultImages = [UIImage]()
        for i in 0..<targetCount {
            let index = Int(Double(i) / Double(targetCount) * Double(imageCount))
            if index >= 0 && index < images.count {
                resultImages.append(images[index])
            } else {
                break
            }
        }
        
        return resultImages
    }
    
    // MARK: Layout
    
    private func getGifPreviewViewBounds() -> CGRect {
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
        gifPreviewView.bounds = getGifPreviewViewBounds()
        gifPreviewView.center = CGPointMake(view.bounds.midX, navigationView.frame.maxY + (isIpad ? 50 : 30) + gifPreviewView.bounds.height * 0.5)
        
        let w = (isIpad ? 60.0 : 48.0) + 20.0
        playButton.bounds = CGRectMake(0, 0, w, w)
        playButton.center = CGPointMake(gifPreviewView.frame.midX, gifPreviewView.frame.maxY + playButton.bounds.height * 0.5)
        
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
        let cropRect = gifPreviewView.cropRect
        let selectedImages = gifPreviewView.selectedImages
        let duration = endTime - startTime
        guard selectedImages.count > 0, duration > 0 else { return }
        
        navigationView.hideProgress(hide: false)
        navigationView.progressView.progress = 0.1
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }

            var resultImgs = [UIImage]()
            for img in selectedImages {
                if let croppedCGImg = img.cgImage?.cropping(to: cropRect) {
                    let croppedImg = UIImage(cgImage: croppedCGImg)
                    resultImgs.append(croppedImg)
                    
                    let progress = max(0.1, Double(resultImgs.count) / Double(selectedImages.count))
                    DispatchQueue.main.async {
                        self.navigationView.progressView.progress = progress
                    }
                } else {
                    assert(false)
                }
            }
            
            DispatchQueue.main.async {
                self.navigationView.progressView.progress = 1.0
                self.cropDidFinished?(resultImgs, duration)
                self.close()
            }
        }
    }
}

class ISGifCropPreviewView: UIView, UIScrollViewDelegate {
    
    private var image: UIImage
    private var imagePixelSize: CGSize = .zero
    private var cropSize: CGSize
    
    private(set) var isPlaying: Bool = false
    
    private var containerScrollView = UIScrollView()
    private var (gifMaskView, gifMaskLayer) = (UIView(), CAShapeLayer())
    private var cropAreaView = ISCropAreaView()
    private var gifPreviewView = UIImageView()
    
    private var gifPlayTimer: Timer?
    private var startIndex: Int = 0
    private var endIndex: Int = 0
    private var currentIndex: Int = 0 {
        didSet {
            if let images = image.images, currentIndex >= 0, currentIndex < images.count {
                gifPreviewView.image = images[currentIndex]
            }
        }
    }
    
    var selectedImages: [UIImage] {
        var images = [UIImage]()
        if let imgs = image.images, startIndex <= endIndex, startIndex >= 0, endIndex < imgs.count {
            for i in startIndex...endIndex {
                images.append(imgs[i])
            }
        }
        return images
    }
    
    var currentTimeChanged: ((_ time: Double) -> Void)?
    var playingStateChanged: ((_ isPlaying: Bool) -> Void)?
    
    var cropRect: CGRect {
        var cropRect = cropAreaView.convert(cropAreaView.bounds, to: gifPreviewView)
        let gifPreviewSize = gifPreviewView.bounds.size
        cropRect.origin = CGPointMake(
            cropRect.minX / gifPreviewSize.width * imagePixelSize.width,
            cropRect.minY / gifPreviewSize.height * imagePixelSize.height
        )
        cropRect.size = CGSizeMake(
            cropRect.width / gifPreviewSize.width * imagePixelSize.width,
            cropRect.height / gifPreviewSize.height * imagePixelSize.height
        )
        return cropRect
    }
    
    init(image: UIImage, cropSize: CGSize) {
        assert(image.images != nil && image.duration > 0)
        self.image = image
        self.cropSize = cropSize
        super.init(frame: .zero)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("no imp: ISGifCropPreviewView")
    }
    
    private func setup() {
        addSubview(containerScrollView)
        containerScrollView.addSubview(gifPreviewView)
        gifMaskView.layer.addSublayer(gifMaskLayer)
        addSubview(gifMaskView)
        addSubview(cropAreaView)
        
        containerScrollView.delegate = self
        containerScrollView.showsHorizontalScrollIndicator = false
        containerScrollView.showsVerticalScrollIndicator = false
        gifMaskView.isUserInteractionEnabled = false
        cropAreaView.isUserInteractionEnabled = false
        
        imagePixelSize = CGSizeMake(image.size.width * image.scale, image.size.height * image.scale)
        
        startIndex = 0
        endIndex = max(0, ((image.images?.count ?? 0) - 1))
        currentIndex = 0
        
        isPlaying = false
        playingStateChanged?(false)
        
        gifMaskView.alpha = 0.75
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            UIView.animate(withDuration: 0.3) {
                self.cropAreaView.lineAlpha = 0
                self.gifMaskView.alpha = 1.0
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        containerScrollView.frame = bounds
        gifMaskView.frame = containerScrollView.frame
        gifMaskLayer.frame = gifMaskView.bounds
        
        let oldFrame = cropAreaView.frame
        let tempFrame = containerScrollView.frame.inset(by: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20))
        cropAreaView.frame = AVMakeRect(aspectRatio: cropSize, insideRect: tempFrame)
        
        if oldFrame != cropAreaView.frame {
            let path = UIBezierPath()
            path.append(.init(rect: gifMaskView.bounds.insetBy(dx: -10, dy: -10)))
            path.append(.init(rect: gifMaskView.convert(cropAreaView.bounds, from: cropAreaView)))
            gifMaskLayer.path = path.cgPath
            gifMaskLayer.fillRule = .evenOdd
            gifMaskLayer.fillColor = UIColor.black.cgColor
        }
        
        var newSize = ISMakeRectAspectFill(aspectRatio: imagePixelSize, insideRect: containerScrollView.bounds).size
        newSize = CGSizeMake(floor(newSize.width), floor(newSize.height))
        let newFrame = CGRect(origin: .zero, size: newSize)
        if containerScrollView.contentSize != newFrame.size {
            containerScrollView.contentSize = newFrame.size
            gifPreviewView.frame = newFrame
            
            let frame: CGRect = gifMaskView.convert(cropAreaView.bounds, from: cropAreaView)
            containerScrollView.contentInset = UIEdgeInsets(top: frame.minY, left: frame.minX, bottom: frame.minY, right: frame.minX)
            
            let minZoomScale = max(cropAreaView.bounds.width / newFrame.width, cropAreaView.bounds.height / newFrame.height)
            containerScrollView.minimumZoomScale = minZoomScale
            containerScrollView.maximumZoomScale = max(ceil(minZoomScale + 1), 5.0)
            DispatchQueue.main.async {
                self.containerScrollView.zoomScale = minZoomScale
                self.containerScrollView.contentOffset = CGPointMake(
                    (newFrame.width * minZoomScale - self.containerScrollView.bounds.width) * 0.5,
                    (newFrame.height * minZoomScale - self.containerScrollView.bounds.height) * 0.5
                )
            }
        }
    }
    
    func updatePlayerStartEndTime(startTime: Double, endTime: Double) {
        guard let images = image.images else { return }
        
        let duration = image.duration
        startIndex = max(0, Int(ceil((min(1.0, startTime / duration)) * Double(images.count - 1))))
        endIndex = min(images.count - 1, Int(floor((min(1.0, endTime / duration)) * Double(images.count - 1))))
        
        if currentIndex < startIndex || currentIndex > endIndex {
            currentIndex = startIndex
        }
    }
    
    func playOrPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func play() {
        guard isPlaying == false else { return }
        
        guard let count = image.images?.count, count > 0, image.duration > 0 else { return }
        let timer = Timer(timeInterval: image.duration / Double(count), repeats: true) { [weak self] _ in
            guard let self else { return }
            
            var index = self.currentIndex + 1
            if index > self.endIndex {
                index = self.startIndex
            }
            if self.currentIndex != index {
                self.currentIndex = index
                if let images = self.image.images {
                    self.currentTimeChanged?(Double(index) / Double(images.count - 1) * image.duration)
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.gifPlayTimer = timer
        isPlaying = true
        playingStateChanged?(isPlaying)
    }
    
    func pause() {
        if let timer = gifPlayTimer, timer.isValid {
            timer.invalidate()
            gifPlayTimer = nil
        }
        
        if isPlaying {
            isPlaying = false
            playingStateChanged?(isPlaying)
        }
    }
    
    func seek(to time: Double) {
        guard let images = image.images, time > 0 else { return }
        
        let duration = image.duration
        let index = Int(ceil((min(1.0, time / duration)) * Double(images.count - 1)))
        currentIndex = index
    }
    
    // MARK: UIScrollViewDelegate
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return gifPreviewView
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        UIView.animate(withDuration: 0.3) {
            self.gifMaskView.alpha = 0.75
            self.cropAreaView.lineAlpha = 1.0
        }
    }
    
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        UIView.animate(withDuration: 0.3) {
            self.gifMaskView.alpha = 0.75
            self.cropAreaView.lineAlpha = 1.0
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        UIView.animate(withDuration: 0.3, delay: 0.35) {
            self.gifMaskView.alpha = 1.0
            self.cropAreaView.lineAlpha = 0
        }
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        UIView.animate(withDuration: 0.3, delay: 0.35) {
            self.gifMaskView.alpha = 1.0
            self.cropAreaView.lineAlpha = 0
        }
    }
}
