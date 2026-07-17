require 'xcodeproj'

project_path = 'XDREWiOS.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

target.build_configurations.each do |config|
  config.build_settings['INFOPLIST_KEY_NSCameraUsageDescription'] = "Aplikasi membutuhkan akses kamera untuk panggilan video."
  config.build_settings['INFOPLIST_KEY_NSMicrophoneUsageDescription'] = "Aplikasi membutuhkan akses mikrofon untuk panggilan suara dan video."
end

project.save
