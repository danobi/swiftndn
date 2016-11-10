#
# Be sure to run `pod lib lint swiftndn.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'swiftndn'
  s.version          = '0.0.1'
  s.summary          = 'NDN client library for the Swift language'
  s.description      = <<-DESC
This is a basic NDN client library targeting the swift language for iOS/OSX
                       DESC
  s.homepage         = 'https://github.com/danobi/swiftndn'
  s.license          = { :type => 'Proprietary', :file => 'LICENSE' }
  s.author           = { 'Wentao Shang' => 'wentao@cs.ucla.edu', 'Jongdeog Lee' => 'jdlee700@illinois.edu', 'Daniel Xu' => 'dlxu2@yahoo.com' }
  s.source           = { :git => 'https://github.com/danobi/swiftndn.git', :tag => s.version.to_s }
  s.ios.deployment_target = '8.0'
  s.source_files = 'swiftndn/Classes/**/*'
end
