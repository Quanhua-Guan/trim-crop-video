source 'https://github.com/CocoaPods/Specs.git'

platform :ios, '14.0'
# https://bytedance.larkoffice.com/docx/GrhGdNew5oSvkuxLWxwcFJHLn56 自动拉取 adapter 的方法
#plugin 'cocoapods-byte-csjm'
use_frameworks!
inhibit_all_warnings!
#
#use_gm_adapterw_update! # 设置为自动更新adapter版本号

target :"trim-crop-video"  do
  
 pod 'QGProgressView'

 post_install do |installer|
   installer.pods_project.targets.each do |target|
     target.build_configurations.each do |config|
       config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'No'
       config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
       config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "14.0"
     end
   end
 end
 
 
end


