require_relative './mobile_sdk/SalesforceMobileSDK-iOS/mobilesdk_pods'

platform :ios, '17.0'

project 'HoopMeInApp.xcodeproj'
target 'HoopMeInApp' do
  source 'https://cdn.cocoapods.org/'
  use_frameworks!
  pod 'FSPagerView'
  pod 'MaterialComponents/TextControls+FilledTextAreas'
  pod 'MaterialComponents/TextControls+FilledTextFields'
  pod 'MaterialComponents/TextControls+OutlinedTextAreas'
  pod 'MaterialComponents/TextControls+OutlinedTextFields'
  pod 'DatePicker'
  pod 'DropDown'
  pod 'Toast-Swift', '~> 5.0.0'
  pod 'Alamofire'
  pod 'IQKeyboardManagerSwift'
  pod 'SideMenu'
  pod 'SDWebImage'
  pod 'FSCalendar'
  pod 'SQLite.swift'
  pod 'SSDateTimePicker', :git => 'https://github.com/SimformSolutionsPvtLtd/SSDateTimePicker.git'
  use_mobile_sdk!
end

# SQLCipher macros on the app aggregate xcconfig break Swift system SQLite3.pcm (sqlite3ext.h) on Xcode 16+ / iOS 26 SDK.
def strip_sqlcipher_flags_from_hoopmein_aggregate_xcconfigs(installer)
  support = File.join(installer.sandbox.root, 'Target Support Files', 'Pods-HoopMeInApp')
  Dir.glob(File.join(support, 'Pods-HoopMeInApp*.xcconfig')).each do |xcconfig_path|
    next unless File.file?(xcconfig_path)
    original = File.read(xcconfig_path)
    patched = original.dup
    patched.gsub!(' SQLITE_HAS_CODEC=1', '')
    patched.gsub!(' _SQLITE3_H_=1', '')
    patched.gsub!(' _FTS5_H=1', '')
    patched.gsub!(' _SQLITE3RTREE_H_=1', '')
    patched.sub!(/^OTHER_CFLAGS = .+$/, 'OTHER_CFLAGS = ')
    File.write(xcconfig_path, patched) if patched != original
  end
end

post_install do |installer|
  # Comment the following if you do not want the SDK to emit signpost events for instrumentation. Signposts are  enabled for non release version of the app.
  signposts_post_install(installer)

  mobile_sdk_post_install(installer)
  strip_sqlcipher_flags_from_hoopmein_aggregate_xcconfigs(installer)

  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      current = config.build_settings['IPHONEOS_DEPLOYMENT_TARGET']
      next if current.nil?
      if current.to_f < 12.0
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
      end
    end
  end
end
