Pod::Spec.new do |s|
  s.name             = 'PipecatClientIOS'
  s.version          = '1.3.0'
  s.summary          = 'Pipecat iOS client library (pipecat_flutter local fork).'
  s.description      = <<-DESC
  Local fork of PipecatClientIOS 1.3.0 vendored inside pipecat_flutter. Adds inbound
  switch cases for the modern function-call lifecycle messages
  (llm-function-call-started / -in-progress / -stopped) so iOS clients can decode them
  natively; upstream still only decodes the deprecated `llm-function-call`.

  The patch touches exactly four files and is purely additive:
    transport/RTVIMessageInbound.swift   3 MessageType constants
    types/LLMFunctionCallData.swift      3 Codable payload structs
    PipecatClientDelegate.swift          3 protocol methods + default no-op extensions
    PipecatClient.swift                  3 inbound switch cases
  All other sources are verbatim from upstream 1.3.0.
                       DESC
  s.homepage         = 'https://github.com/pipecat-ai/pipecat-client-ios'
  s.documentation_url = 'https://docs.pipecat.ai/client/ios/introduction'
  s.license          = { :type => 'BSD-2', :file => 'LICENSE' }
  s.authors          = { 'Daily.co' => 'help@daily.co' }
  s.source           = { :path => '.' }
  s.platform         = :ios, '13.0'
  s.source_files     = 'Sources/**/*.{swift,h,m}'
  s.exclude_files    = 'Sources/Exclude'
  s.swift_version    = '5.5'
end
