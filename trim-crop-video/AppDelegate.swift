//
//  AppDelegate.swift
//  trim-crop-video
//
//

import UIKit
import AVFoundation

@main
class AppDelegate: UIResponder, UIApplicationDelegate {



  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // Override point for customization after application launch.
      
      try? AVAudioSession.sharedInstance().setCategory(.ambient)
      try? AVAudioSession.sharedInstance().setActive(true)
      
    return true
  }

  // MARK: UISceneSession Lifecycle

  func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
  }

  func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
  }


}



func ISMakeRectAspectFill(aspectRatio size: CGSize, insideRect rect: CGRect) -> CGRect {
    let w0 = size.width, h0 = size.height // 目标宽高比
    let w1 = rect.size.width, h1 = rect.size.height // 可用宽高
    
    if h0 == 0 || h1 == 0 {
        return .zero
    }
    
    let rw = w0 / w1, rh = h0 / h1
    // 取比值小的为参考边
    let r = if rw < rh {
        // [宽]比值小, 以[宽]为参考
        rw
    } else {
        // [高]比值小, 以[高]为参考
        rh
    }
    let targetSize = CGSizeMake(w0 / r, h0 / r)
    return CGRectMake(
        rect.origin.x + (rect.size.width - targetSize.width) / 2,
        rect.origin.y + (rect.size.height - targetSize.height) / 2,
        targetSize.width,
        targetSize.height
    )
}

var screenScale: CGFloat = {
  #if os(iOS) || os(tvOS)
  if #available(iOS 13.0, tvOS 13.0, *) {
    return max(UITraitCollection.current.displayScale, 1)
  } else {
    return UIScreen.main.scale
  }
  #else // if os(visionOS)
  // We intentionally don't check `#if os(visionOS)`, because that emits
  // a warning when building on Xcode 14 and earlier.
  return 1.0
  #endif
}()


extension UIImage {
    func resizeImageTo(size: CGSize, scale: CGFloat = 0.0) -> UIImage? {
        if size.width <= 0 || size.height <= 0 {
            return nil
        }
        
        let format = UIGraphicsImageRendererFormat()
        if scale != 0 {
            format.scale = scale
        }
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            self.draw(in: CGRect(origin: CGPoint.zero, size: size))
        }
    }
}
