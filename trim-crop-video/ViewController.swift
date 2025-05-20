//
//  ViewController.swift
//  trim-crop-video
//
//

import UIKit
import AVKit
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

class ViewController: UIViewController {

  @IBOutlet var croppingView: UIView!
  @IBOutlet var playButton: UIButton!
  @IBOutlet var resetButton: UIButton!
  @IBOutlet var exportButton: UIButton!
  @IBOutlet var playerView: UIView!
  var player: AVPlayer? {
    didSet {
      guard let duration = player?.currentItem?.duration else { return }
      endTime = duration
    }
  }
  var cropScaleComposition: AVVideoComposition? {
    didSet {
      self.exportButton.isEnabled = (cropScaleComposition != nil)
    }
  }
  var startTime: CMTime = .zero
  var endTime: CMTime = .zero
  var endTimeObserver: Any?

  @IBOutlet var startTimeSlider: UISlider!
  @IBOutlet var endTimeSlider: UISlider!
    
    var url: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("CropDone"), object: nil, queue: .main) { [weak self] note in
            if let self, let url = note.object as? URL {
                self.url = url
                self.loadCleanVideo()
            }
        }
    }
    
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    loadCleanVideo()
  }

  @IBAction func startTimeUpdated(_ sender: UISlider) {
    guard let videoDuration = self.player?.currentItem?.duration else { return }
    self.startTime = CMTimeMakeWithSeconds(Double(sender.value) * videoDuration.seconds, preferredTimescale: 600)
    self.player?.seek(to: self.startTime)
  }

  @IBAction func endTimeUpdated(_ sender: UISlider) {
    guard let videoDuration = self.player?.currentItem?.duration else { return }
    self.endTime = CMTimeMakeWithSeconds(Double(sender.value) * videoDuration.seconds, preferredTimescale: 600)
    self.player?.seek(to: self.endTime)
  }

  @IBAction func croppingViewZoom(_ sender: UIPinchGestureRecognizer) {
    let touch = sender.location(in: sender.view?.superview)

    if sender.numberOfTouches < 2 { return }
    self.croppingView.transform = CGAffineTransform(scaleX: sender.scale, y: sender.scale)
    self.croppingView.center = CGPoint(x: touch.x, y: touch.y)

  }
  @IBAction func croppingViewDrag(_ sender: UIPanGestureRecognizer) {
    let touch = sender.location(in: sender.view?.superview)

    self.croppingView.center = CGPoint(x: touch.x, y: touch.y)
  }



  fileprivate func configureCroppingView() {
    self.croppingView.frame = CGRect(x: 0, y: 0, width: 250, height: 250)
    self.croppingView.center = playerView.center
    self.croppingView.layer.borderWidth = 2
    self.croppingView.layer.borderColor = UIColor.red.cgColor
  }

  fileprivate func loadCleanVideo() {
    self.player = AVPlayer(url: url ?? Bundle.main.url(forResource: "grocery-train", withExtension: "mov")!)
    self.cropScaleComposition = nil
      
    let playerLayer = AVPlayerLayer(player: player)
    playerLayer.frame = playerView.layer.bounds
      playerLayer.videoGravity = .resizeAspect

    playerView.layer.addSublayer(playerLayer)

    configureCroppingView()

    self.playerView.addSubview(self.croppingView)
  }

  func prepareForCropping() {
    guard let playerItem = self.player?.currentItem else { return }
    let renderingSize = playerItem.presentationSize

    let xFactor = renderingSize.width / playerView.bounds.size.width
    let yFactor = renderingSize.height / playerView.bounds.size.height

      let theFrame = croppingView.frame
    let newX = theFrame.origin.x * xFactor
    let newW = theFrame.width * xFactor
    let newY = theFrame.origin.y * yFactor
    let newH = theFrame.height * yFactor
    var cropRect = CGRect(x: newX, y: newY, width: newW, height: newH)

    let originFlipTransform = CGAffineTransform(scaleX: 1, y: -1)
    let frameTranslateTransform = CGAffineTransform(translationX: 0, y: renderingSize.height)
    cropRect = cropRect.applying(originFlipTransform)
    cropRect = cropRect.applying(frameTranslateTransform)

    self.transformVideo(item: playerItem, cropRect: cropRect)
  }

  @IBAction func resetTapped(_ sender: Any) {
    self.croppingView.isHidden = false
    self.croppingView.removeFromSuperview()

    self.startTimeSlider.setValue(0, animated: true)
    self.endTimeSlider.setValue(1, animated: true)

    self.playerView.layer.sublayers?.removeAll()
    self.loadCleanVideo()
      
      //let url = Bundle.main.url(forResource: "grocery-train", withExtension: "mov")!
      let url = Bundle.main.url(forResource: "v1", withExtension: "MOV")!
      let vc = ISVideoCropViewController(url: url, cropSize: CGSizeMake(170, 170))
      vc.modalPresentationStyle = .fullScreen
      vc.cropDidFinished = { outputURL in
          NotificationCenter.default.post(name: NSNotification.Name("CropDone"), object: outputURL)
      }
      self.present(vc, animated: true)
      
  }
    @IBAction func togoGifCropVC(_ sender: UIButton) {
        let url = Bundle.main.url(forResource: "2", withExtension: "gif")!
        let image = UIImage.animatedImage(withGIFData: try! Data(contentsOf: url), cacheKey: "abc")!
        let vc = ISGifCropViewController(image: image, cropSize: CGSizeMake(170, 170))
        vc.modalPresentationStyle = .fullScreen
        vc.cropDidFinished = { images, duration in
            NotificationCenter.default.post(name: NSNotification.Name("GifCropDone"), object: (images, duration))
        }
        self.present(vc, animated: true)
    }
        
  @IBAction func playTapped(_ sender: UIButton) {
    self.croppingView.isHidden = true
    //self.prepareForCropping()
    player?.seek(to: startTime)
    self.endTimeObserver = player?.addBoundaryTimeObserver(forTimes: [NSValue(time: endTime)], queue: .main, using: {
      [weak self] in
      guard let self = self else { return }
      self.player?.pause()
      self.player?.removeTimeObserver(self.endTimeObserver!)
      self.croppingView.isHidden = false
    })
    player?.play()
  }

  fileprivate func addSpinner() {
    //Disable controls because this is a long process
    let spinner = UIActivityIndicatorView(style: .large)
    spinner.backgroundColor = .white
    spinner.tag = 10
    self.playerView.addSubview(spinner)
    spinner.center = self.playerView.center
    spinner.startAnimating()
  }

  fileprivate func removeSpinner() {
    let spinner = self.playerView.viewWithTag(10)
    spinner?.removeFromSuperview()
  }

  fileprivate func updateControlStatus(enabled: Bool) {
    if !enabled {
    addSpinner()
    } else {
      removeSpinner()
    }
    self.playButton.isEnabled = enabled
    self.startTimeSlider.isEnabled = enabled
    self.endTimeSlider.isEnabled = enabled
    self.resetButton.isEnabled = enabled
    self.exportButton.isEnabled = enabled
  }

  @IBAction func exportvideo(_ sender: UIButton) {
    guard let assetToExport = self.player?.currentItem?.asset else { return }
    guard let composition = self.cropScaleComposition else { return }
    guard let outputMovieURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("exported.mov") else { return }

    updateControlStatus(enabled: false)

    export(assetToExport, to: outputMovieURL, startTime: self.startTime, endTime: self.endTime, composition: composition)


  }

  func export(_ asset: AVAsset, to outputMovieURL: URL, startTime: CMTime, endTime: CMTime, composition: AVVideoComposition) {

    //Create trim range
    let timeRange = CMTimeRangeFromTimeToTime(start: startTime, end: endTime)

    //delete any old file
    do {
      try FileManager.default.removeItem(at: outputMovieURL)
    } catch {
      print("Could not remove file \(error.localizedDescription)")
    }

    //create exporter
    let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)

    //configure exporter
    exporter?.videoComposition = composition
    exporter?.outputURL = outputMovieURL
    exporter?.outputFileType = .mov
    exporter?.timeRange = timeRange

    //export!
    exporter?.exportAsynchronously(completionHandler: { [weak exporter] in
      DispatchQueue.main.async {
        if let error = exporter?.error {
          print("failed \(error.localizedDescription)")
        } else {
          self.shareVideoFile(outputMovieURL)
        }
      }

    })
  }
  fileprivate func calculateFilterIntensity(_ duration: CMTime, _ currentTime: CMTime) -> Float {
    let timeDiff = CMTimeGetSeconds(CMTimeSubtract(duration, currentTime))
    if timeDiff < 5 {
      return Float((5 - timeDiff) / 5.0)
    }
    return 0.0
  }

  func transformVideo(item: AVPlayerItem, cropRect: CGRect) {

    let cropScaleComposition = AVMutableVideoComposition(asset: item.asset, applyingCIFiltersWithHandler: { [weak self] request in

      guard let self = self else { return }

      let sepiaToneFilter = CIFilter.sepiaTone()
      let currentTime = request.compositionTime
      sepiaToneFilter.intensity = self.calculateFilterIntensity(self.endTime, currentTime)
      sepiaToneFilter.inputImage = request.sourceImage

      let cropFilter = CIFilter(name: "CICrop")!
      cropFilter.setValue(sepiaToneFilter.outputImage!, forKey: kCIInputImageKey)
      cropFilter.setValue(CIVector(cgRect: cropRect), forKey: "inputRectangle")


      let imageAtOrigin = cropFilter.outputImage!.transformed(by: CGAffineTransform(translationX: -cropRect.origin.x, y: -cropRect.origin.y))
      request.finish(with: imageAtOrigin, context: nil)
    })
    cropScaleComposition.renderSize = cropRect.size
    item.videoComposition = cropScaleComposition
    self.cropScaleComposition = cropScaleComposition
  }

  func shareVideoFile(_ file:URL) {

    updateControlStatus(enabled: true)

    // Create the Array which includes the files you want to share
    var filesToShare = [Any]()

    // Add the path of the file to the Array
    filesToShare.append(file)

    // Make the activityViewContoller which shows the share-view
    let activityViewController = UIActivityViewController(activityItems: filesToShare, applicationActivities: nil)

    // Show the share-view
    self.present(activityViewController, animated: true, completion: nil)
  }
}

extension UIColor {
    static let bgOpacColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.07)
    static let bgShadowColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.33)
    static let bglightShadowColor = UIColor(red: 0.29, green: 0.29, blue: 0.29, alpha: 0.1)
    
    static let titleColor = UIColor(red: 41/255.0, green: 41/255.0, blue: 41/255.0, alpha: 1.0)
    
    static let titleGrayColor = UIColor(red: 115/255.0, green: 115/255.0, blue: 115/255.0, alpha: 1.0)
    
    static let placeHolderColor = UIColor(red: 158/255.0, green: 158/255.0, blue: 158/255.0, alpha: 1.0)
    static let tinctBlue = UIColor(red: 0/255.0, green: 140/255.0, blue: 255/255.0, alpha: 1.0)
    static let tinctGreen = UIColor(red: 52/255.0, green: 199/255.0, blue: 89/255.0, alpha: 1.0)
    static let tinctOrange = UIColor(red: 255/255.0, green: 130/255.0, blue: 43/255.0, alpha: 1.0)
    
    static let bgViewColor = UIColor(red: 242/255.0, green: 242/255.0, blue: 242/255.0, alpha: 1.0)
    static let selectBGColor = UIColor(red: 220/255.0, green: 220/255.0, blue: 220/255.0, alpha: 1.0)
    static let whiteBGColor = UIColor(red: 247/255.0, green: 247/255.0, blue: 247/255.0, alpha: 1.0)
    
    static let tinctBgColor = UIColor(red: 33/255.0, green: 35/255.0, blue: 63/255.0, alpha: 1.0)
    
    static let oldBgColor = UIColor(red: 245/255.0, green: 248/255.0, blue: 250/255.0, alpha: 1.0)
    static let bgColor = UIColor(red: 245/255.0, green: 248/255.0, blue: 250/255.0, alpha: 1.0)
    static let yzdBlue = UIColor(red: 0/255.0, green: 140/255.0, blue: 255/255.0, alpha: 1.0)
    
}

extension String {
    func localized() -> String {
        return NSLocalizedString(self, comment: "")
    }
    
    var L: String {
        return NSLocalizedString(self, comment: "")
    }
    
    func localized(arguments: CVarArg...) -> String {
        if arguments.count == 0 {
            return NSLocalizedString(self, comment: "")
        }
        else {
            return String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
        }
    }
}

private var gifCache: NSCache<NSString, UIImage> = {
    let c = NSCache<NSString, UIImage>()
    c.totalCostLimit = 15 * 1024 * 1024
    return c
}()

extension UIImage {
    var image: Image {
        Image(uiImage: self)
    }
    
    static func animatedImage(withGIFData data: Data, cacheKey: String? = nil) -> UIImage? {
        if let cacheKey = cacheKey {
            if let cacheImage = gifCache.object(forKey: cacheKey as NSString) {
                return cacheImage
            }
        }
        
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        
        let frameCount = CGImageSourceGetCount(source)
        var frames: [UIImage] = []
        var gifDuration = 0.0
        
        for i in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil),
               let gifInfo = (properties as NSDictionary)[kCGImagePropertyGIFDictionary as String] as? NSDictionary,
               let frameDuration = (gifInfo[kCGImagePropertyGIFDelayTime as String] as? NSNumber)
            {
                gifDuration += frameDuration.doubleValue
            }
                        
            let frameImage = UIImage(cgImage: cgImage)
            frames.append(frameImage)
        }
        
        let animatedImage = UIImage.animatedImage(with: frames, duration: gifDuration)
        if let animatedImage = animatedImage, let cacheKey = cacheKey {
            gifCache.setObject(animatedImage, forKey: cacheKey as NSString)
        }
        return animatedImage
    }
}
