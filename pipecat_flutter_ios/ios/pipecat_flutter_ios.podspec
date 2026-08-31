#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'pipecat_flutter_ios'
  s.version          = '4.0.0'
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
  # Swift 5 language mode: the pigeon-generated PipecatApi.g.swift references
  # Flutter framework globals (the method codec, FlutterEndOfEventStream) that
  # are not Sendable, which Swift 6 strict-concurrency rejects as hard errors.
  # The plugin does not rely on Swift 6 language features, so compile in 5.0
  # mode. This mirrors the language mode the vendored PipecatClientIOS pod uses.
  s.swift_version = '5.0'
  
  s.dependency 'PipecatClientIOS', '~> 1.3'
  s.dependency 'PipecatClientIOSDaily', '~> 1.3'
end
