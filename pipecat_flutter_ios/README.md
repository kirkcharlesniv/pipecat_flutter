# pipecat_flutter_ios

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]

The ios implementation of `pipecat_flutter`.

## Usage

This package is [endorsed][endorsed_link], which means you can simply use `pipecat_flutter`
normally. This package will be automatically included in your app when you do.

## Vendored PipecatClientIOS fork (required)

`pipecat_flutter_ios` ships with a local fork of `PipecatClientIOS` 1.2.0 under
[ios/vendored/PipecatClientIOS](ios/vendored/PipecatClientIOS). The fork adds
inbound switch cases for the modern function-call lifecycle messages
(`llm-function-call-started`, `llm-function-call-in-progress`,
`llm-function-call-stopped`) so iOS can decode them natively. The unpatched
upstream pod silently drops those frames. `PipecatClientIOSDaily` 1.2.0 is
shipped verbatim alongside so CocoaPods version resolution stays pinned.

Add the following snippet to your app's `ios/Podfile` inside the `target`
block so CocoaPods uses the local fork instead of the published pods:

```ruby
# Flutter creates `<app>/ios/.symlinks/plugins/pipecat_flutter_ios/` on
# every `flutter pub get` regardless of whether pipecat_flutter is installed
# from pub.dev or as a path dependency, so this path is portable across
# machines and CI.
pipecat_flutter_ios_root = File.expand_path(
  '.symlinks/plugins/pipecat_flutter_ios/ios',
  __dir__,
)
pod 'PipecatClientIOS',
  :path => "#{pipecat_flutter_ios_root}/vendored/PipecatClientIOS"
pod 'PipecatClientIOSDaily',
  :path => "#{pipecat_flutter_ios_root}/vendored/PipecatClientIOSDaily"
```

Run `flutter pub get` (which refreshes `.symlinks/plugins/`) before
`pod install` from your app's `ios/` directory. Do not hard-code a path to
your local pipecat_flutter checkout — that breaks for every other dev and
CI machine.

[endorsed_link]: https://flutter.dev/docs/development/packages-and-plugins/developing-packages#endorsed-federated-plugin
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis