@preconcurrency import Flutter
import Daily
import PipecatClientIOS
import PipecatClientIOSDaily
import UIKit

@MainActor
public class PipecatFlutterPlugin: NSObject, FlutterPlugin, @preconcurrency PipecatHostApi, @preconcurrency PipecatClientDelegate {
  private var client: PipecatClient?
  private var timelineHandler: TimelineEventStreamHandler?
  private var localAudioHandler: LocalAudioLevelHandler?
  private var remoteAudioHandler: RemoteAudioLevelHandler?

  private var isBotAudioMuted: Bool = false
  private var botDailyParticipantId: ParticipantID? = nil

  private var activeSessionEpoch: Int64 = 0
  private var sequenceCounter: Int64 = 0
  private var disconnectedEpoch: Int64 = -1
  private var lastConnectionState: ConnectionState?
  private var lastSpeakingState: SpeakingState?
  private let userMuteCompatBridge = "rtvi_user_mute_v1"

  private func callbackError(
    code: String,
    message: String?,
    details: Sendable? = nil
  ) -> any Swift.Error {
    PigeonError(code: code, message: message, details: details) as any Swift.Error
  }

  nonisolated public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    MainActor.assumeIsolated {
      let instance = PipecatFlutterPlugin()
      PipecatHostApiSetup.setUp(binaryMessenger: messenger, api: instance)

      let timelineHandler = TimelineEventStreamHandler()
      instance.timelineHandler = timelineHandler
      TimelineEventsStreamHandler.register(with: messenger, streamHandler: timelineHandler)

      let localHandler = LocalAudioLevelHandler()
      instance.localAudioHandler = localHandler
      LocalAudioLevelStreamHandler.register(with: messenger, streamHandler: localHandler)

      let remoteHandler = RemoteAudioLevelHandler()
      instance.remoteAudioHandler = remoteHandler
      RemoteAudioLevelStreamHandler.register(with: messenger, streamHandler: remoteHandler)
    }
  }

  func startAndConnect(
    parameters: StartBotParams,
    completion: @escaping (Result<Void, Swift.Error>) -> Void
  ) {
    if client != nil {
      completion(
        .failure(
          callbackError(
            code: "ALREADY_CONNECTED",
            message: "Client already exists. Disconnect first."
          )
        )
      )
      return
    }

    let sessionEpoch = beginNewSessionEpoch()
    emitTimelineEvent(
      event: ConnectionStateEvent(state: .connecting),
      sessionEpoch: sessionEpoch
    )

    let options = PipecatClientOptions(
      transport: DailyTransport(),
      enableMic: parameters.shouldEnableMicrophone,
      enableCam: parameters.shouldEnableCamera
    )
    let newClient = PipecatClient(options: options)
    newClient.delegate = self
    client = newClient

    let connectionParams = DailyTransportConnectionParams(
      roomUrl: parameters.url,
      token: parameters.token
    )

    newClient.connect(transportParams: connectionParams) { [weak self] result in
      DispatchQueue.main.async {
        guard let self else { return }
        guard self.isCurrentEpoch(sessionEpoch) else { return }

        switch result {
        case .success:
          self.updateInputState(sessionEpoch: sessionEpoch)
          completion(.success(()))
        case .failure(let err):
          self.cleanupFailedConnect(sessionEpoch: sessionEpoch)
          completion(
            .failure(
              self.callbackError(
                code: "CONNECT_ERROR",
                message: err.localizedDescription
              )
            )
          )
        }
      }
    }
  }

  func disconnect(completion: @escaping (Result<Void, Swift.Error>) -> Void) {
    let sessionEpoch = activeSessionEpoch
    guard let currentClient = client else {
      isBotAudioMuted = false
      botDailyParticipantId = nil
      if sessionEpoch > 0 {
        emitDisconnectedIfNeeded(sessionEpoch: sessionEpoch)
      }
      completion(.success(()))
      return
    }

    currentClient.delegate = nil
    currentClient.disconnect { [weak self] result in
      DispatchQueue.main.async {
        guard let self else { return }
        switch result {
        case .success:
          if self.client === currentClient {
            self.client = nil
          }
          self.isBotAudioMuted = false
          self.botDailyParticipantId = nil
          self.emitDisconnectedIfNeeded(sessionEpoch: sessionEpoch)
          completion(.success(()))
        case .failure(let error):
          completion(
            .failure(
              self.callbackError(
                code: "DISCONNECT_ERROR",
                message: error.localizedDescription
              )
            )
          )
        }
      }
    }
  }

  func toggleMicrophone(
    isEnabled: Bool,
    completion: @escaping (Result<Void, Swift.Error>) -> Void
  ) {
    guard let client else {
      completion(
        .failure(
          callbackError(code: "NO_CLIENT", message: "Client not available")
        )
      )
      return
    }

    let sessionEpoch = activeSessionEpoch
    client.enableMic(enable: isEnabled) { [weak self] result in
      DispatchQueue.main.async {
        guard let self else { return }
        switch result {
        case .success:
          self.updateInputState(sessionEpoch: sessionEpoch)
          completion(.success(()))
        case .failure(let error):
          completion(
            .failure(
              self.callbackError(
                code: "MIC_ERROR",
                message: error.localizedDescription
              )
            )
          )
        }
      }
    }
  }

  func toggleCamera(
    isEnabled: Bool,
    completion: @escaping (Result<Void, Swift.Error>) -> Void
  ) {
    guard let client else {
      completion(
        .failure(
          callbackError(code: "NO_CLIENT", message: "Client not available")
        )
      )
      return
    }

    let sessionEpoch = activeSessionEpoch
    client.enableCam(enable: isEnabled) { [weak self] result in
      DispatchQueue.main.async {
        guard let self else { return }
        switch result {
        case .success:
          self.updateInputState(sessionEpoch: sessionEpoch)
          completion(.success(()))
        case .failure(let error):
          completion(
            .failure(
              self.callbackError(
                code: "CAMERA_ERROR",
                message: error.localizedDescription
              )
            )
          )
        }
      }
    }
  }

  func muteBotAudio(isMuted: Bool, completion: @escaping (Result<Void, Swift.Error>) -> Void) {
    guard let client,
      let dailyTransport = client.transport as? DailyTransport
    else {
      completion(
        .failure(
          callbackError(
            code: "NO_CLIENT",
            message: "Client or transport not available"
          )
        )
      )
      return
    }

    guard let botId = botDailyParticipantId else {
      completion(
        .failure(
          callbackError(
            code: "BOT_NOT_CONNECTED",
            message: "Bot participant not connected"
          )
        )
      )
      return
    }

    Task { @MainActor in
      do {
        try await muteRemoteParticipantAudio(transport: dailyTransport, botParticipantId: botId, muted: isMuted)
        self.isBotAudioMuted = isMuted
        self.updateInputState(sessionEpoch: self.activeSessionEpoch)
        completion(.success(()))
      } catch {
        completion(
          .failure(
            self.callbackError(
              code: "MUTE_ERROR",
              message: error.localizedDescription
            )
          )
        )
      }
    }
  }

  func sendText(parameters: SendTextParams, completion: @escaping (Result<Void, Swift.Error>) -> Void) {
    guard let client else {
      completion(
        .failure(
          callbackError(code: "NO_CLIENT", message: "Client not available")
        )
      )
      return
    }

    do {
      try client.sendText(
        content: parameters.content,
        options: SendTextOptions(
          runImmediately: parameters.runImmediately,
          audioResponse: parameters.audioResponse
        )
      )
      completion(.success(()))
    } catch {
      completion(
        .failure(
          callbackError(
            code: "SEND_TEXT_ERROR",
            message: error.localizedDescription
          )
        )
      )
    }
  }

  func sendLlmFunctionCallResult(
    parameters: SendLlmFunctionCallResultParams,
    completion: @escaping (Result<Void, Swift.Error>) -> Void
  ) {
    guard let dailyTransport = client?.transport as? DailyTransport else {
      completion(
        .failure(
          callbackError(
            code: "NO_TRANSPORT",
            message: "Transport not available"
          )
        )
      )
      return
    }

    do {
      let argumentsValue = try decodeRtviValue(from: parameters.argumentsJson)
      let resultValue = try decodeRtviValue(from: parameters.resultJson)
      let resultData: Value = [
        "function_name": .string(parameters.functionName),
        "tool_call_id": .string(parameters.toolCallId),
        "arguments": argumentsValue,
        "result": resultValue,
      ]

      let message = RTVIMessageOutbound(
        type: RTVIMessageOutbound.MessageType.LLM_FUNCTION_CALL_RESULT,
        data: resultData
      )
      try dailyTransport.sendMessage(message: message)
      completion(.success(()))
    } catch {
      completion(
        .failure(
          callbackError(
            code: "SEND_FUNCTION_RESULT_ERROR",
            message: error.localizedDescription
          )
        )
      )
    }
  }

  func sendClientMessage(
    parameters: SendClientMessageParams,
    completion: @escaping (Result<Void, Swift.Error>) -> Void
  ) {
    guard let dailyTransport = client?.transport as? DailyTransport else {
      completion(
        .failure(
          callbackError(
            code: "NO_TRANSPORT",
            message: "Transport not available"
          )
        )
      )
      return
    }

    do {
      let dataValue = try decodeRtviValue(from: parameters.dataJson)
      let message = RTVIMessageOutbound.clientMessage(
        msgType: parameters.msgType,
        data: dataValue
      )
      try dailyTransport.sendMessage(message: message)
      completion(.success(()))
    } catch {
      completion(
        .failure(
          callbackError(
            code: "SEND_CLIENT_MESSAGE_ERROR",
            message: error.localizedDescription
          )
        )
      )
    }
  }

  func sendClientRequest(
    parameters: SendClientRequestParams,
    completion: @escaping (Result<SendClientRequestResult, Swift.Error>) -> Void
  ) {
    guard let client else {
      completion(
        .failure(
          callbackError(
            code: "NO_CLIENT",
            message: "Client not available"
          )
        )
      )
      return
    }

    do {
      let dataValue = try decodeRtviValue(from: parameters.dataJson)
      client.sendClientRequest(
        msgType: parameters.msgType,
        data: dataValue
      ) { [weak self] result in
        DispatchQueue.main.async {
          guard let self else { return }

          switch result {
          case .success(let response):
            completion(
              .success(
                SendClientRequestResult(
                  msgType: response.t,
                  dataJson: self.canonicalJSONString(from: response.d) ?? "null"
                )
              )
            )
          case .failure(let error):
            completion(.failure(self.mapClientRequestError(error)))
          }
        }
      }
    } catch {
      completion(
        .failure(
          callbackError(
            code: "SEND_CLIENT_REQUEST_ERROR",
            message: error.localizedDescription
          )
        )
      )
    }
  }

  // MARK: - PipecatClientDelegate

  public func onConnected() {
    guard isSessionActive else { return }
    emitTimelineEvent(
      event: ConnectionStateEvent(state: .connected),
      sessionEpoch: activeSessionEpoch
    )
    updateInputState(sessionEpoch: activeSessionEpoch)
  }

  public func onDisconnected() {
    guard isSessionActive else { return }
    emitDisconnectedIfNeeded(sessionEpoch: activeSessionEpoch)
  }

  public func onTransportStateChanged(state: TransportState) {
    guard isSessionActive else { return }

    let connectionState = mapTransportState(state: state)
    if connectionState == .disconnected {
      emitDisconnectedIfNeeded(sessionEpoch: activeSessionEpoch)
    } else {
      emitTimelineEvent(
        event: ConnectionStateEvent(state: connectionState),
        sessionEpoch: activeSessionEpoch
      )
    }
    updateInputState(sessionEpoch: activeSessionEpoch)

    // Emit raw sub-state so Dart can record fine-grained timing and
    // show granular progress messages without pigeon API changes.
    let subStateJson = "{\"type\":\"transport.sub_state\",\"state\":\"\(state)\"}"
    emitTimelineEvent(
      event: ServerMessageEvent(rawJson: subStateJson),
      sessionEpoch: activeSessionEpoch
    )
    emitTransportDiagnosticIfNeeded(state: state)
  }

  public func onError(message: PipecatClientIOS.RTVIMessageInbound) {
    guard isSessionActive else { return }
    let errorMessage = String(describing: message.data ?? "Unknown error")
    emitTimelineEvent(
      event: BackendErrorEvent(message: errorMessage),
      sessionEpoch: activeSessionEpoch
    )
  }

  public func onBotConnected(participant: PipecatClientIOS.Participant) {
    guard isSessionActive else { return }
    if let callClient = (client?.transport as? DailyTransport)?.dailyCallClient {
      botDailyParticipantId = callClient.participants.remote.keys.first
    }
    emitTimelineEvent(
      event: BotConnectionEvent(
        state: .connected,
        participantId: participantIdentifier(from: participant),
        participantName: participant.name
      ),
      sessionEpoch: activeSessionEpoch
    )
  }

  public func onBotReady(botReadyData: BotReadyData) {
    guard isSessionActive else { return }
    emitTimelineEvent(
      event: BotReadyEvent(
        version: botReadyData.version,
        aboutJson: canonicalJSONString(from: botReadyData.about)
      ),
      sessionEpoch: activeSessionEpoch
    )
  }

  public func onBotDisconnected(participant: PipecatClientIOS.Participant) {
    guard isSessionActive else { return }
    botDailyParticipantId = nil
    isBotAudioMuted = false
    emitTimelineEvent(
      event: BotConnectionEvent(
        state: .disconnected,
        participantId: participantIdentifier(from: participant),
        participantName: participant.name
      ),
      sessionEpoch: activeSessionEpoch
    )
  }

  public func onMetrics(data: PipecatMetrics) {
    guard isSessionActive else { return }
    let payload = metricsPayload(from: data)
    emitTimelineEvent(
      event: MetricsEvent(
        processing: metricSamples(from: payload["processing"] as? [[String: Any]]),
        ttfb: metricSamples(from: payload["ttfb"] as? [[String: Any]]),
        rawJson: canonicalJSONString(fromJSON: payload)
      ),
      sessionEpoch: activeSessionEpoch
    )
  }

  public func onServerMessage(data: Any) {
    guard isSessionActive else { return }
    let rawJson = canonicalJSONString(fromAny: data)
    emitTimelineEvent(
      event: ServerMessageEvent(rawJson: rawJson),
      sessionEpoch: activeSessionEpoch
    )
    if let userMuteEvent = parseUserMuteEvent(fromAny: data) {
      emitTimelineEvent(
        event: userMuteEvent,
        sessionEpoch: activeSessionEpoch
      )
    }
  }

  public func onUserStartedSpeaking() {
    guard isSessionActive else { return }
    emitTimelineEvent(
      event: SpeakingEvent(state: .userStartedSpeaking),
      sessionEpoch: activeSessionEpoch
    )
  }

  public func onUserStoppedSpeaking() {
    guard isSessionActive else { return }
    emitTimelineEvent(
      event: SpeakingEvent(state: .userStoppedSpeaking),
      sessionEpoch: activeSessionEpoch
    )
  }

  public func onBotStartedSpeaking() {
    guard isSessionActive else { return }
    emitTimelineEvent(
      event: SpeakingEvent(state: .botStartedSpeaking),
      sessionEpoch: activeSessionEpoch
    )
  }

  public func onBotStoppedSpeaking() {
    guard isSessionActive else { return }
    emitTimelineEvent(
      event: SpeakingEvent(state: .botStoppedSpeaking),
      sessionEpoch: activeSessionEpoch
    )
  }

  public func onUserTranscript(data: PipecatClientIOS.Transcript) {
    guard isSessionActive else { return }
    emitTimelineEvent(
      event: UserTranscriptionEvent(
        text: data.text,
        isFinal: data.final ?? false,
        timestamp: data.timestamp ?? "",
        userId: data.userId ?? ""
      ),
      sessionEpoch: activeSessionEpoch
    )
  }

  public func onBotLlmText(data: PipecatClientIOS.BotLLMText) {
    guard isSessionActive else { return }
    emitTimelineEvent(
      event: BotLLMText(text: data.text),
      sessionEpoch: activeSessionEpoch
    )
  }

  public func onBotTtsText(data: PipecatClientIOS.BotTTSText) {
    guard isSessionActive else { return }
    emitTimelineEvent(
      event: BotTTSText(text: data.text),
      sessionEpoch: activeSessionEpoch
    )
  }

  public func onLLMFunctionCall(
    functionCallData: LLMFunctionCallData,
    onResult: ((Value) async -> Void)
  ) async {
    guard isSessionActive else { return }
    emitTimelineEvent(
      event: LlmFunctionCallEvent(
        functionName: functionCallData.functionName,
        toolCallId: functionCallData.toolCallID,
        argumentsJson: canonicalJSONString(from: functionCallData.args) ?? "{}"
      ),
      sessionEpoch: activeSessionEpoch
    )
  }

  public func onBotLlmStarted() {
    guard isSessionActive else { return }
    emitTimelineEvent(
      event: ServerInsightEvent(type: .botLlmStarted),
      sessionEpoch: activeSessionEpoch
    )
  }

  public func onBotLlmStopped() {
    guard isSessionActive else { return }
    emitTimelineEvent(
      event: ServerInsightEvent(type: .botLlmStopped),
      sessionEpoch: activeSessionEpoch
    )
  }

  public func onBotTtsStarted() {
    guard isSessionActive else { return }
    emitTimelineEvent(
      event: ServerInsightEvent(type: .botTtsStarted),
      sessionEpoch: activeSessionEpoch
    )
  }

  public func onBotTtsStopped() {
    guard isSessionActive else { return }
    emitTimelineEvent(
      event: ServerInsightEvent(type: .botTtsStopped),
      sessionEpoch: activeSessionEpoch
    )
  }

  public func onMicUpdated(mic: MediaDeviceInfo?) {
    updateInputState(sessionEpoch: activeSessionEpoch)
  }

  public func onBotOutput(data: PipecatClientIOS.BotOutputData) {
    guard isSessionActive else { return }
    emitTimelineEvent(
      event: BotOutputEvent(
        text: data.text,
        isSpoken: data.spoken,
        aggregatedBy: data.aggregatedBy.rawValue
      ),
      sessionEpoch: activeSessionEpoch
    )
  }

  public func onLocalAudioLevel(level: Float) {
    guard isSessionActive else { return }
    localAudioHandler?.sendLevel(Double(level))
  }

  public func onRemoteAudioLevel(level: Float, participant: PipecatClientIOS.Participant) {
    guard isSessionActive else { return }
    remoteAudioHandler?.sendLevel(Double(level))
  }

  // MARK: - Timeline + session helpers

  private var isSessionActive: Bool {
    return client != nil && activeSessionEpoch > 0
  }

  private func beginNewSessionEpoch() -> Int64 {
    activeSessionEpoch += 1
    sequenceCounter = 0
    disconnectedEpoch = -1
    lastConnectionState = nil
    lastSpeakingState = nil
    botDailyParticipantId = nil
    return activeSessionEpoch
  }

  private func isCurrentEpoch(_ sessionEpoch: Int64) -> Bool {
    return sessionEpoch > 0 && sessionEpoch == activeSessionEpoch
  }

  private func cleanupFailedConnect(sessionEpoch: Int64) {
    guard isCurrentEpoch(sessionEpoch) else { return }
    client?.delegate = nil
    client = nil
    isBotAudioMuted = false
    botDailyParticipantId = nil
    emitDisconnectedIfNeeded(sessionEpoch: sessionEpoch)
  }

  private func emitDisconnectedIfNeeded(sessionEpoch: Int64) {
    guard sessionEpoch > 0 else { return }
    guard disconnectedEpoch != sessionEpoch else { return }

    emitTimelineEvent(
      event: ConnectionStateEvent(state: .disconnected),
      sessionEpoch: sessionEpoch
    )
  }

  private func emitTimelineEvent(event: PipecatEvent, sessionEpoch: Int64) {
    guard isCurrentEpoch(sessionEpoch) else { return }

    if let connectionEvent = event as? ConnectionStateEvent {
      if lastConnectionState == connectionEvent.state {
        return
      }
      lastConnectionState = connectionEvent.state
      if connectionEvent.state == .disconnected {
        disconnectedEpoch = sessionEpoch
        lastSpeakingState = nil
      }
    }

    if let speakingEvent = event as? SpeakingEvent {
      if lastSpeakingState == speakingEvent.state {
        return
      }
      lastSpeakingState = speakingEvent.state
    }

    sequenceCounter += 1
    let timelineEvent = TimelineEvent(
      sequence: sequenceCounter,
      sessionEpoch: sessionEpoch,
      emittedAtMs: Int64(Date().timeIntervalSince1970 * 1000),
      event: event
    )
    timelineHandler?.sendEvent(timelineEvent)
  }

  private func updateInputState(sessionEpoch: Int64) {
    guard isCurrentEpoch(sessionEpoch),
      let transport = client?.transport as? DailyTransport
    else { return }

    emitTimelineEvent(
      event: InputStatusUpdatedEvent(
        isCurrentMicrophoneEnabled: transport.isMicEnabled(),
        isCurrentCameraEnabled: transport.isCamEnabled(),
        isBotAudioMuted: isBotAudioMuted
      ),
      sessionEpoch: sessionEpoch
    )
  }

  private func mapTransportState(state: TransportState) -> ConnectionState {
    switch state {
    case .initializing, .initialized, .connecting, .authenticating, .authenticated:
      return .connecting
    case .ready, .connected:
      return .connected
    case .disconnected, .error:
      return .disconnected
    default:
      return .disconnected
    }
  }

  private func participantIdentifier(from participant: PipecatClientIOS.Participant) -> String {
    if let participantId = reflectedString(named: "id", from: participant.id), !participantId.isEmpty {
      return participantId
    }
    if let name = participant.name, !name.isEmpty {
      return name
    }
    return "unknown"
  }

  private func metricsPayload(from metrics: PipecatMetrics) -> [String: Any] {
    var payload: [String: Any] = [:]
    if let processing = metricSampleObjects(from: reflectedProperty(named: "processing", from: metrics)) {
      payload["processing"] = processing
    }
    if let ttfb = metricSampleObjects(from: reflectedProperty(named: "ttfb", from: metrics)) {
      payload["ttfb"] = ttfb
    }
    if let characters = metricSampleObjects(from: reflectedProperty(named: "characters", from: metrics)) {
      payload["characters"] = characters
    }
    return payload
  }

  private func metricSamples(from entries: [[String: Any]]?) -> [PipecatMetricSample]? {
    guard let entries else { return nil }
    let samples = entries.compactMap { entry -> PipecatMetricSample? in
      guard let processor = entry["processor"] as? String else { return nil }
      let rawValue = entry["value"]
      let value: Double?
      if let doubleValue = rawValue as? Double {
        value = doubleValue
      } else if let intValue = rawValue as? Int {
        value = Double(intValue)
      } else if let number = rawValue as? NSNumber {
        value = number.doubleValue
      } else {
        value = nil
      }
      guard let value else { return nil }
      return PipecatMetricSample(processor: processor, value: value)
    }

    return samples.isEmpty ? nil : samples
  }

  private func metricSampleObjects(from rawList: Any?) -> [[String: Any]]? {
    guard let rawList,
      let list = unwrapOptional(rawList),
      let entries = list as? [Any]
    else { return nil }

    let objects = entries.compactMap { entry -> [String: Any]? in
      guard let processor = reflectedString(named: "processor", from: entry),
        let value = reflectedDouble(named: "value", from: entry)
      else { return nil }
      return ["processor": processor, "value": value]
    }

    return objects.isEmpty ? nil : objects
  }

  private func reflectedProperty(named propertyName: String, from object: Any) -> Any? {
    for child in Mirror(reflecting: object).children where child.label == propertyName {
      return child.value
    }
    return nil
  }

  private func reflectedString(named propertyName: String, from object: Any) -> String? {
    guard let value = reflectedProperty(named: propertyName, from: object),
      let unwrappedValue = unwrapOptional(value)
    else { return nil }
    return unwrappedValue as? String
  }

  private func reflectedDouble(named propertyName: String, from object: Any) -> Double? {
    guard let value = reflectedProperty(named: propertyName, from: object),
      let unwrappedValue = unwrapOptional(value)
    else { return nil }

    if let doubleValue = unwrappedValue as? Double {
      return doubleValue
    }
    if let intValue = unwrappedValue as? Int {
      return Double(intValue)
    }
    if let number = unwrappedValue as? NSNumber {
      return number.doubleValue
    }
    return nil
  }

  private func unwrapOptional(_ value: Any) -> Any? {
    let mirror = Mirror(reflecting: value)
    guard mirror.displayStyle == .optional else { return value }
    return mirror.children.first?.value
  }

  private func decodeRtviValue(from json: String) throws -> Value {
    let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
    let candidate = trimmed.isEmpty ? "{}" : trimmed
    guard let data = candidate.data(using: .utf8) else {
      throw PigeonError(code: "INVALID_JSON", message: "Invalid UTF-8 JSON", details: nil)
    }
    return try JSONDecoder().decode(Value.self, from: data)
  }

  private func canonicalJSONString(from value: Value?) -> String? {
    guard let value else { return nil }
    let foundation = foundationObject(fromValue: value)
    return canonicalJSONString(fromJSON: foundation)
  }

  private func canonicalJSONString(fromAny data: Any) -> String {
    if let value = data as? Value {
      return canonicalJSONString(from: value) ?? "null"
    }

    if let dictionary = data as? [String: Any] {
      return canonicalJSONString(fromJSON: dictionary)
    }

    if let array = data as? [Any] {
      return canonicalJSONString(fromJSON: array)
    }

    return jsonQuoted(String(describing: data))
  }

  private func parseUserMuteEvent(fromAny data: Any) -> UserMuteEvent? {
    let payload: [String: Any]
    if let value = data as? Value {
      guard let mapped = foundationObject(fromValue: value) as? [String: Any] else {
        return nil
      }
      payload = mapped
    } else if let dictionary = data as? [String: Any] {
      payload = dictionary
    } else {
      return nil
    }

    guard
      let compat = payload["compat"] as? [String: Any],
      let bridge = compat["bridge"] as? String,
      bridge == userMuteCompatBridge
    else {
      return nil
    }

    let userMute = (payload["user_mute"] as? [String: Any])
      ?? (payload["userMute"] as? [String: Any])
    guard
      let userMute,
      let statusRaw = userMute["status"] as? String
    else {
      return nil
    }

    let state: UserMuteState
    switch statusRaw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "started":
      state = .started
    case "stopped":
      state = .stopped
    default:
      return nil
    }

    return UserMuteEvent(state: state)
  }

  private func foundationObject(fromValue value: Value) -> Any {
    switch value {
    case .boolean(let boolValue):
      return NSNumber(value: boolValue)
    case .number(let number):
      return NSNumber(value: number)
    case .string(let string):
      return string
    case .array(let values):
      return values.map { value -> Any in
        guard let value else { return NSNull() }
        return foundationObject(fromValue: value)
      }
    case .object(let object):
      var mapped: [String: Any] = [:]
      for (key, nested) in object {
        if let nested {
          mapped[key] = foundationObject(fromValue: nested)
        } else {
          mapped[key] = NSNull()
        }
      }
      return mapped
    }
  }

  private func canonicalJSONString(fromJSON value: Any) -> String {
    if value is NSNull {
      return "null"
    }

    if let dictionary = value as? [String: Any] {
      let keys = dictionary.keys.sorted()
      let body = keys.map { key in
        "\(jsonQuoted(key)):\(canonicalJSONString(fromJSON: dictionary[key] ?? NSNull()))"
      }.joined(separator: ",")
      return "{\(body)}"
    }

    if let array = value as? [Any] {
      let body = array.map { canonicalJSONString(fromJSON: $0) }.joined(separator: ",")
      return "[\(body)]"
    }

    if let stringValue = value as? String {
      return jsonQuoted(stringValue)
    }

    if let number = value as? NSNumber {
      if CFGetTypeID(number) == CFBooleanGetTypeID() {
        return number.boolValue ? "true" : "false"
      }
      let doubleValue = number.doubleValue
      if !doubleValue.isFinite {
        return "null"
      }
      if floor(doubleValue) == doubleValue {
        return String(Int64(doubleValue))
      }
      return String(doubleValue)
    }

    return jsonQuoted(String(describing: value))
  }

  private func jsonQuoted(_ string: String) -> String {
    if let data = try? JSONSerialization.data(withJSONObject: [string], options: []),
      let encoded = String(data: data, encoding: .utf8),
      encoded.count >= 2
    {
      return String(encoded.dropFirst().dropLast())
    }
    return "\"\""
  }

  private func emitTransportDiagnosticIfNeeded(state: TransportState) {
    let stage = String(describing: state).lowercased()
    guard stage == "connected" || stage == "ready" else { return }
    guard let dailyTransport = client?.transport as? DailyTransport else { return }

    let payload = transportDiagnosticPayload(
      stage: stage,
      transport: dailyTransport
    )
    emitTimelineEvent(
      event: ServerMessageEvent(rawJson: canonicalJSONString(fromJSON: payload)),
      sessionEpoch: activeSessionEpoch
    )
  }

  private func transportDiagnosticPayload(
    stage: String,
    transport: DailyTransport
  ) -> [String: Any] {
    let callClient = transport.dailyCallClient
    var payload: [String: Any] = [
      "type": "transport.diagnostic",
      "source": "daily_ios",
      "stage": stage,
      "transport_state": stage,
      "captured_at_ms": Int64(Date().timeIntervalSince1970 * 1000),
    ]

    if let callClient {
      payload["call_state"] = callClient.callState.rawValue
      payload["participant_counts"] = [
        "hidden": callClient.participantCounts.hidden,
        "present": callClient.participantCounts.present,
      ]
      if let networkStats = callClient.networkStatistics {
        let latest: [String: Any] = [
          "receive_bits_per_second": networkStats.stats.latest.receiveBitsPerSecond ?? NSNull(),
          "send_bits_per_second": networkStats.stats.latest.sendBitsPerSecond ?? NSNull(),
          "timestamp": networkStats.stats.latest.timestamp ?? NSNull(),
          "video_recv_bits_per_second": networkStats.stats.latest.videoRecvBitsPerSecond ?? NSNull(),
          "video_send_bits_per_second": networkStats.stats.latest.videoSendBitsPerSecond ?? NSNull(),
          "video_recv_packet_loss": networkStats.stats.latest.videoRecvPacketLoss ?? NSNull(),
          "video_send_packet_loss": networkStats.stats.latest.videoSendPacketLoss ?? NSNull(),
          "total_recv_packet_loss": networkStats.stats.latest.totalRecvPacketLoss ?? NSNull(),
          "total_send_packet_loss": networkStats.stats.latest.totalSendPacketLoss ?? NSNull(),
        ]
        let networkPayload: [String: Any] = [
          "quality": networkStats.quality,
          "threshold": networkStats.threshold.rawValue,
          "previous_threshold": networkStats.previousThreshold?.rawValue ?? NSNull(),
          "latest": latest,
          "worst_video_receive_packet_loss":
            networkStats.stats.worstVideoReceivePacketLoss ?? NSNull(),
          "worst_video_send_packet_loss":
            networkStats.stats.worstVideoSendPacketLoss ?? NSNull(),
        ]
        payload["network"] = networkPayload
      }
    }

    return payload
  }

  private func mapClientRequestError(_ error: AsyncExecutionError) -> any Swift.Error {
    let rootError = rootRtviError(error)
    if rootError is ResponseTimeoutError {
      return PigeonError(
        code: "SEND_CLIENT_REQUEST_TIMEOUT",
        message: rootError.localizedDescription,
        details: nil
      )
    }

    if rootError is BotResponseError {
      return PigeonError(
        code: "SEND_CLIENT_REQUEST_ERROR_RESPONSE",
        message: rootError.localizedDescription,
        details: nil
      )
    }

    return PigeonError(
      code: "SEND_CLIENT_REQUEST_ERROR",
      message: error.localizedDescription,
      details: nil
    )
  }

  private func rootRtviError(_ error: RTVIError) -> RTVIError {
    var current: RTVIError = error
    while let nested = current.underlyingError as? RTVIError {
      current = nested
    }
    return current
  }
}
