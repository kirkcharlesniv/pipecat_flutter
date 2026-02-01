@preconcurrency import Flutter
import PipecatClientIOS
import PipecatClientIOSDaily
import UIKit

@MainActor
public class PipecatFlutterPlugin: NSObject, FlutterPlugin, @preconcurrency PipecatHostApi, @preconcurrency PipecatClientDelegate {
  private var client: PipecatClient?
  private var eventStreamHandler: PipecatEventStreamHandler?
  private var localAudioHandler: LocalAudioLevelHandler?
  private var remoteAudioHandler: RemoteAudioLevelHandler?
  private var botOutputHandler: BotOutputHandler?
  private var userTranscriptionHandler: UserTranscriptionHandler?

  nonisolated public static func register(with registrar: FlutterPluginRegistrar) {
      let messenger = registrar.messenger()
      MainActor.assumeIsolated {
          let instance = PipecatFlutterPlugin()
          PipecatHostApiSetup.setUp(binaryMessenger: messenger, api: instance)
          
          let streamHandler = PipecatEventStreamHandler()
          instance.eventStreamHandler = streamHandler
          EventsStreamHandler.register(
            with: messenger, streamHandler: streamHandler
          )
        
        // Local audio levels
        let localHandler = LocalAudioLevelHandler()
        instance.localAudioHandler = localHandler
        LocalAudioLevelStreamHandler.register(with: messenger, streamHandler: localHandler)
        
        // Remote audio levels
        let remoteHandler = RemoteAudioLevelHandler()
        instance.remoteAudioHandler = remoteHandler
        RemoteAudioLevelStreamHandler.register(with: messenger, streamHandler: remoteHandler)
        
        let botOutputHandler = BotOutputHandler()
        instance.botOutputHandler = botOutputHandler
        BotOutputStreamHandler.register(with: messenger, streamHandler: botOutputHandler)
        
        let userTranscriptionHandler = UserTranscriptionHandler()
        instance.userTranscriptionHandler = userTranscriptionHandler
        UserTranscriptionsStreamHandler.register(with: messenger, streamHandler: userTranscriptionHandler)
      }
  }
  
  func startAndConnect(
    parameters: StartBotParams,
    completion: @escaping (Result<Void, any Error>) -> Void
  ) {
    if client != nil {
      completion(.failure(PigeonError(
        code: "ALREADY_CONNECTED",
        message: "Client already exists. Disconnect first.",
        details: nil
      )))
      return
    }
    
    let options = PipecatClientOptions(
      transport: DailyTransport(),
      enableMic: parameters.shouldEnableMicrophone,
      enableCam: parameters.shouldEnableCamera
    )
    client = PipecatClient(options: options)
    
    // Set the delegate to receive events
    client?.delegate = self

    let connectionParams = DailyTransportConnectionParams(
        roomUrl: parameters.url,
        token: parameters.token
    )
    
    client?.connect(transportParams: connectionParams) { result in
      DispatchQueue.main.async {
        switch result {
        case .success:
          completion(.success(()))
        case .failure(let err):
          completion(.failure(err))
        }
      }
    }
  }
  
  func disconnect(completion: @escaping (Result<Void, any Error>) -> Void) {
    client?.delegate = nil
    client?.disconnect { result in
      switch result {
      case .success:
        self.client = nil
        completion(.success(()))
      case .failure(let error):
        completion(.failure(PigeonError(
          code: "DISCONNECT_ERROR",
          message: error.localizedDescription,
          details: nil
        )))
      }
    }
  }

  func toggleMicrophone(
    isEnabled: Bool,
    completion: @escaping (Result<Void, any Error>) -> Void
  ) {
    client?.enableMic(enable: isEnabled) { result in
      switch result {
      case .success:
        completion(.success(()))
      case .failure(let error):
        completion(.failure(PigeonError(
          code: "MIC_ERROR",
          message: error.localizedDescription,
          details: nil
        )))
      }
    }
  }

  func toggleCamera(
    isEnabled: Bool,
    completion: @escaping (Result<Void, any Error>) -> Void
  ) {
    client?.enableCam(enable: isEnabled) { result in
      switch result {
      case .success:
        completion(.success(()))
      case .failure(let error):
        completion(.failure(PigeonError(
          code: "CAMERA_ERROR",
          message: error.localizedDescription,
          details: nil
        )))
      }
    }
  }
  
  // MARK: - PipecatClientDelegate
  
  public func onConnected() {
    eventStreamHandler?.sendEvent(ConnectionStateEvent(state: .connected))
  }
  
  public func onDisconnected() {
    eventStreamHandler?.sendEvent(ConnectionStateEvent(state: .disconnected))
  }
  
  public func onTransportStateChanged(state: TransportState) {
    // Map TransportState to your ConnectionState if needed
    let connectionState: ConnectionState
    switch state {
    case .initializing, .initialized, .connecting, .authenticating, .authenticated:
      connectionState = .connecting
    case .ready, .connected:
      connectionState = .connected
    case .disconnected, .error:
      connectionState = .disconnected
    default:
      connectionState = .disconnected
    }
    
    eventStreamHandler?.sendEvent(ConnectionStateEvent(state: connectionState))
  }
  
  public func onError(message: RTVIMessageInbound) {
    let errorMessage = String(describing: message.data ?? "Unknown error")
    eventStreamHandler?.sendEvent(BackendErrorEvent(message: errorMessage))
  }
  
  public func onUserStartedSpeaking() {
    eventStreamHandler?.sendEvent(SpeakingEvent(state: .userStartedSpeaking))
  }
  
  public func onUserStoppedSpeaking() {
    eventStreamHandler?.sendEvent(SpeakingEvent(state: .userStoppedSpeaking))
  }
  
  public func onBotStartedSpeaking() {
    eventStreamHandler?.sendEvent(SpeakingEvent(state: .botStartedSpeaking))
  }
  
  public func onBotStoppedSpeaking() {
    eventStreamHandler?.sendEvent(SpeakingEvent(state: .botStoppedSpeaking))
  }
  
  public func onUserTranscript(data: Transcript) {
    userTranscriptionHandler?.sendEvent(UserTranscriptionEvent(
      text: data.text,
      isFinal: data.final ?? false,
      timestamp: data.timestamp ?? "",
      userId: data.userId ?? ""
    ))
  }
  
  public func onBotLlmText(data: PipecatClientIOS.BotLLMText) {
    // Note: BotLLMText from PipecatClientIOS vs your Pigeon-generated one
    eventStreamHandler?.sendEvent(BotLLMText(text: data.text))
  }
  
  public func onBotTtsText(data: PipecatClientIOS.BotTTSText) {
    // Note: BotTTSText from PipecatClientIOS vs your Pigeon-generated one
    eventStreamHandler?.sendEvent(BotTTSText(text: data.text))
  }
  
  public func onBotLlmStarted() {
    eventStreamHandler?.sendEvent(ServerInsightEvent(type: .botLlmStarted))
  }
  
  public func onBotLlmStopped() {
    eventStreamHandler?.sendEvent(ServerInsightEvent(type: .botLlmStopped))
  }
  
  public func onBotTtsStarted() {
    eventStreamHandler?.sendEvent(ServerInsightEvent(type: .botTtsStarted))
  }
  
  public func onBotTtsStopped() {
    eventStreamHandler?.sendEvent(ServerInsightEvent(type: .botTtsStopped))
  }
  
  public func onBotOutput(data: BotOutputData) {
    botOutputHandler?.sendEvent(BotOutputEvent(
      text: data.text,
      isSpoken: data.spoken,
      aggregatedBy: data.aggregatedBy.rawValue
    ))
  }
  
  public func onLocalAudioLevel(level: Float) {
    localAudioHandler?.sendLevel(Double(level))
  }
  
  // TODO: Send participant details
  public func onRemoteAudioLevel(level: Float, participant: Participant) {
    remoteAudioHandler?.sendLevel(Double(level))
  }
}
