Pod::Spec.new do |s|
  s.name             = 'PipecatClientIOSDaily'
  s.version          = '1.2.0'
  s.summary          = 'Pipecat iOS client library with Daily WebRTC transport (pipecat_flutter local copy).'
  s.description      = <<-DESC
  Verbatim copy of PipecatClientIOSDaily 1.2.0 sources, vendored inside pipecat_flutter
  so CocoaPods resolution stays pinned alongside the local PipecatClientIOS fork and
  Daily SDK alignment used by this repo.
                       DESC
  s.homepage         = 'https://github.com/pipecat-ai/pipecat-client-ios-daily'
  s.documentation_url = 'https://docs.pipecat.ai/client/ios/introduction'
  s.license          = { :type => 'BSD-2', :file => 'LICENSE' }
  s.authors          = { 'Daily.co' => 'help@daily.co' }
  s.source           = { :path => '.' }
  s.platform         = :ios, '13.0'
  s.source_files     = 'Sources/**/*.{swift,h,m}'
  s.exclude_files    = 'Sources/Exclude'
  s.swift_version    = '5.5'
  s.dependency 'PipecatClientIOS', '~> 1.2.0'
  s.dependency 'Daily', '~> 0.37.0'
end
