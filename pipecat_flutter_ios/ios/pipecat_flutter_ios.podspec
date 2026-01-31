#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'pipecat_flutter_ios'
  s.version          = '0.0.1'
  s.summary          = 'An iOS implementation of the pipecat_flutter plugin.'
  s.description      = <<-DESC
  An iOS implementation of the pipecat_flutter plugin.
                       DESC
  s.homepage         = 'http://pipecat.ai'
  s.license          = { :type => 'BSD', :file => '../LICENSE' }
  s.author           = { 'Kirk Charles Niverba' => 'kirkniverba@icloud.com' }
  s.source           = { :path => '.' }
  s.source_files = 'pipecat_flutter_ios/Sources/pipecat_flutter_ios/**/*.{swift,h,m}'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '6.1'
  
  s.dependency 'PipecatClientIOS', '~> 1.2'
  s.dependency 'PipecatClientIOSDaily', '~> 1.2'
end
