Pod::Spec.new do |s|
  s.name             = 'PipecatClientIOSDaily'
  s.version          = '1.3.0'
  s.summary          = 'Pipecat iOS client library with Daily WebRTC transport (pipecat_flutter local fork).'
  s.description      = <<-DESC
  Local fork of PipecatClientIOSDaily 1.3.0 vendored inside pipecat_flutter, pinned
  alongside the local PipecatClientIOS fork.

  Patched beyond upstream (upstream exposes only a single weak delegate and implements
  only `inputsUpdated`, which is not enough to track Daily's two independent mic axes):
    util/DailyTransportObserver.swift  NEW - multi-observer protocol + weak box
    DailyTransport.swift               observer registry, plus the `publishingUpdated`
                                       and `subscriptionsUpdated` CallClientDelegate
                                       methods upstream does not implement
    util/DailyExtensions.swift         mergingCameraAndMicrophoneSettings also merges
                                       publishing.microphone.isPublishing

  Daily is pinned to 0.39.x rather than upstream's ~> 0.38.0 for the nameserver
  fallback, signalling-reconnect and release()-during-call fixes.
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
  s.dependency 'PipecatClientIOS', '~> 1.3.0'
  s.dependency 'Daily', '~> 0.39.0'
end
