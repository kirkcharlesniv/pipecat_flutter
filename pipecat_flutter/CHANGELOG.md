## 2.4.1

- fix: Make local microphone mute state authoritative and self-healing against Daily input and publishing state.
- fix: Keep local audio visualizer and user-speaking events silent while the local microphone is muted.
- docs: Clarify local microphone control versus bot-audio subscription muting.

## 2.4.0

- fix: Android bot audio muting now uses correct subscription API.
- fix: iOS and Android bot participant ID stored on connect for stable mute targeting.
- feat: Android reactive track state via `CallClientListener`.

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

- Update federated dependency constraints to `^0.2.0`.

## 0.2.0+2

- Integrate `sendText`

## 0.1.0+1

- Integrates native SDK
