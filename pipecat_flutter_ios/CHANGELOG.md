## 4.0.0

- **BREAKING**: Emit the RTVI 2.0 fields on `BotOutputEvent` and stop forwarding `spoken` as `isSpoken`.
- feat: Rebase the vendored `PipecatClientIOS` / `PipecatClientIOSDaily` forks onto upstream 1.3.0. Advertises RTVI `2.0.0`. Picks up the upstream `DailyTransport` memory-leak fix.
- feat: Daily pod 0.37.0 -> 0.39.x.
- chore: Drop the local `dailyCallClient` accessor; upstream has exposed it since 0.3.6. The multi-observer patch (`DailyTransportObserver`, plus the `publishingUpdated`/`subscriptionsUpdated` delegate methods upstream still does not implement) is re-applied unchanged.
- fix: `podspec` version now tracks `pubspec.yaml` (was stuck at 3.0.4).

## 3.1.0

- feat: Emit an `InputStatusUpdatedEvent` whenever the local microphone's observed sending state (`inputs.microphone` ∧ `publishing.microphone`) changes — including poll-driven reconcile convergence that no Daily transport callback would surface — so the client's mic indicator can never lag the real capture state.
- fix: Re-emit the input state on connect success and again shortly after (+300 ms / +1 s), so late UI subscribers and post-connect publishing settling are always reflected after a (re)connect. Fixes a stale "muted" mic indicator while audio is live after reconnecting to a new room.
- test: Cover the new sending-state change notification in the `LocalMicStateController` tests.

## 3.0.4

- fix: Replace the previous microphone reconcile logic with a listener-driven state machine that treats Daily `inputs.microphone` plus `publishing.microphone` as the only source of truth.
- fix: Observe Daily state through transport delegate fan-out instead of direct `CallClient` state observation, avoiding drift between mute commands and native callbacks.
- fix: Align the vendored `Daily` CocoaPods dependency to `0.37.0`.
- test: Add native controller tests covering ordered transitions, rapid retoggles, drift recovery, and polling fallback.
- docs: Pin the example app `Podfile` to the vendored `PipecatClientIOS` and `PipecatClientIOSDaily` pods so the local transport copy and Daily `0.37.0` are actually used.

## 3.0.3

- fix: Compile the pod in Swift 5.0 language mode (`s.swift_version = '5.0'`)
  instead of 6.1. The pigeon-generated `PipecatApi.g.swift` references Flutter
  framework globals (the method codec and `FlutterEndOfEventStream`) that are
  not `Sendable`; Swift 6 strict concurrency rejects them as hard errors.
  Reverted the generated-file post-processing from 3.0.1/3.0.2 since Swift 5
  mode compiles pigeon's output as-is, keeping the generated file pristine.
  This mirrors the language mode the vendored `PipecatClientIOS` pod uses.

## 3.0.2

- fix (superseded by 3.0.3): annotated the codec as `nonisolated(unsafe) let`
  to satisfy Swift 6 strict concurrency. Insufficient — the pigeon event
  channel code also references the non-`Sendable` `FlutterEndOfEventStream`.

## 3.0.1

- fix (superseded by 3.0.3): post-processed the pigeon-generated codec from
  `var` to `let`. Incomplete — `FlutterStandardMethodCodec` is not `Sendable`.
- docs: Replace the hardcoded sibling-checkout `Podfile` snippet in the README
  with one that uses Flutter's portable `.symlinks/plugins/pipecat_flutter_ios`
  path. The previous snippet only worked on the package author's machine.

## 3.0.0

- **BREAKING**: Drop `LlmFunctionCallEvent` emission. Apps should migrate to
  the new `LlmFunctionCall{Started,InProgress,Stopped}Event` lifecycle exposed
  by `pipecat_flutter` 3.0.0.
- feat: Vendor a patched `PipecatClientIOS` 1.2.0 fork under
  `ios/vendored/PipecatClientIOS` that adds inbound switch cases for
  `llm-function-call-started` / `-in-progress` / `-stopped`, plus matching
  `PipecatClientDelegate` callbacks. `PipecatClientIOSDaily` 1.2.0 is shipped
  verbatim under `ios/vendored/PipecatClientIOSDaily` to keep CocoaPods
  resolution pinned. Consuming apps must add two local-path `pod` lines to
  their `Podfile` — see this package's README for the exact snippet.
- feat: Plugin implements the three new delegate methods on
  `PipecatClientDelegate` and forwards them as the corresponding Flutter
  lifecycle events. The legacy `onLLMFunctionCall` callback is a no-op now.

## 2.4.1

- fix: Make local microphone mute state authoritative and self-healing against Daily input and publishing state.
- fix: Observe Daily input and publishing changes directly to prevent mute-state drift.
- fix: Force local audio levels and user-speaking events to silence while the local microphone is muted.

## 2.4.0

- fix: Store bot participant ID on `onBotConnected` instead of fragile `remote.keys.first` lookup at mute time.
- fix: Pass stored participant ID to `DailyHelper.muteRemoteParticipantAudio` instead of re-querying.
- fix: Return `BOT_NOT_CONNECTED` error if `muteBotAudio` called before bot joins.
- fix: Clear `botDailyParticipantId` in all session cleanup and epoch reset paths.

## 2.3.1

- fix: Pigeon errors.

## 2.3.0

- feat: Add transport diagnostics.
- feat: Add sub-phases connection statuses.

## 2.2.0

- chore: Bump package version to `2.2.0`.

## 2.1.0

- feat: Implement `client-message`

## 2.0.2

- feat: send LLM tool call result
- fix: missing argument for parameter

## 2.0.0

- Refactor: single canonical stream

## 0.2.0+3

- Update `pipecat_flutter_platform_interface` dependency constraint to `^0.2.0`.

## 0.2.0+2

- Integrate `sendText`

## 0.1.0+1

- Swift 6
- Integrates `PipecatClientIOS` version 1.2
- Integrates `PipecatClientIOSDaily` version 1.2
