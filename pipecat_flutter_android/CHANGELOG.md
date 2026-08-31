## 4.0.0

- **BREAKING**: Emit the RTVI 2.0 fields on `BotOutputEvent` and stop forwarding `spoken` as `isSpoken`.
- feat: Rebase the vendored `pipecat-client-android` fork onto upstream 1.2.0. Advertises RTVI `2.0.0`. The lifecycle patch (3 message types, 3 payload classes, 3 callbacks, 3 dispatch branches) is re-applied unchanged; `BotOutputData` is now upstream verbatim.
- feat: `ai.pipecat:daily-transport` 1.1.0 -> 1.2.1 and `co.daily:client` 0.37.0 -> 0.39.1.
- **BREAKING**: `minSdkVersion` 19 -> 24 and `jvmTarget` 1.8 -> 11, required by the new artifacts. `compileSdk` 34 -> 36.

## 3.2.0

- feat: Emit an `InputStatusUpdatedEvent` whenever the local microphone's observed sending state (`inputs.microphone` ∧ `publishing.microphone`) changes — including poll-driven reconcile convergence that no Daily `CallClientListener` callback would surface — so the client's mic indicator can never lag the real capture state.
- fix: Re-emit the input state on connect success and again shortly after (+300 ms / +1 s), so late UI subscribers and post-connect publishing settling are always reflected after a (re)connect. Fixes a stale "muted" mic indicator while audio is live after reconnecting to a new room.
- test: Cover the new sending-state change notification in `LocalMicStateControllerTest`.

## 3.1.0

- feat: Vendor `pipecat-client-android` as a local source fork under `android/vendored/pipecat-client-android/` and patch it with native `llm-function-call-started`, `llm-function-call-in-progress`, and `llm-function-call-stopped` RTVI message handling — mirroring the iOS vendored SDK approach.
- feat: Implement `onLLMFunctionCallStarted`, `onLLMFunctionCallInProgress`, and `onLLMFunctionCallStopped` callbacks in the plugin; each emits the corresponding typed Flutter timeline event with canonical-JSON argument and result payloads.
- chore: Android clients no longer depend on the Dart-side compat-bridge synthesizer for tool-call events; both platforms now emit lifecycle events natively.

## 3.0.1

- fix: Replace the previous local-mic reconcile loop with a listener-driven state machine keyed to Daily `inputs.microphone` and `publishing.microphone`.
- fix: Make mute/unmute completion wait for fully observed Daily convergence, with bounded polling fallback and `MIC_RECONCILE_ERROR` on failure.
- test: Add native controller unit coverage for ordered transitions, rapid retoggles, drift recovery, and polling fallback.

## 3.0.0

- **BREAKING**: Drop `LlmFunctionCallEvent` emission. Migrate to the new
  `LlmFunctionCall{Started,InProgress,Stopped}Event` lifecycle exposed by
  `pipecat_flutter` 3.0.0.
- chore: `onLLMFunctionCall` is a no-op pending an Android-side SDK patch
  mirroring iOS. Until then, Android clients receive tool calls via the
  Dart-side compat-bridge synthesizer in `pipecat_flutter` (the bot runner's
  `rtvi_tool_call_server_message_v1` envelope).

## 2.4.1

- fix: Make local microphone mute state authoritative and self-healing against Daily input and publishing state.
- fix: Force local audio levels and user-speaking events to silence while the local microphone is muted.

## 2.4.0

- fix: Replace broken `updateRemoteParticipants` bot audio muting with correct `updateSubscriptionsForParticipants` (local subscription control).
- fix: Store bot participant ID on `onBotConnected` instead of fragile runtime lookup.
- fix: Set `isBotAudioMuted` only after async subscription call succeeds.
- feat: Register `CallClientListener` for reactive `onInputsUpdated` and `onSubscriptionsUpdated` track events.
- fix: Return `BOT_NOT_CONNECTED` error if `muteBotAudio` called before bot joins.

## 2.3.0

- feat: Add transport diagnostics.
- feat: Add sub-phases connection statuses.

## 2.2.0

- chore: Bump package version to `2.2.0`.

## 2.1.0

- feat: Implement `client-message`

## 2.0.5

- Fix: Delay call of release() on failed connection

## 2.0.4

- Fix: SIGSEGV

## 2.0.3

- Fix: type mismatch for LLMFunctionCallData.args after pipecat client SDK update (Value? → JsonElement)

## 2.0.2

- feat: send LLM tool call result
- fix: missing argument for parameter

## 2.0.1

- Fix: failed to build in Android

## 2.0.0

- Refactor: single canonical stream

## 0.2.0+3

- Update `pipecat_flutter_platform_interface` dependency constraint to `^0.2.0`.

## 0.2.0+2

- Integrate `sendText`

## 0.1.0+1

- Integrates `ai.pipecat:daily-transport:1.1.0`
