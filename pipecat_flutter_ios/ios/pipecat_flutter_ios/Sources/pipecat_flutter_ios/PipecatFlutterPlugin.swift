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
      }
  }
  
  func startAndConnect(
    parameters: StartBotParams,
    completion: @escaping (Result<Void, any Error>) -> Void
  ) {
    let options = PipecatClientOptions(
      transport: DailyTransport(),
      enableMic: parameters.shouldEnableMicrophone,
      enableCam: parameters.shouldEnableCamera
    )
    client = PipecatClient(options: options)
    
    // Set the delegate to receive events
    client?.delegate = self

    let base = parameters.url.trimmingCharacters(
      in: CharacterSet(charactersIn: "/")
    )
    let path =
      parameters.connectPath.hasPrefix("/")
      ? parameters.connectPath : "/" + parameters.connectPath
    guard let endpoint = URL(string: base + path) else {
      completion(
        .failure(
          NSError(
            domain: "pipecat_flutter",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]
          )
        )
      )
      return
    }

    var headersDict = parameters.headers ?? [:]
    headersDict["Authorization"] = parameters.token

    let headersArray = headersDict.map { [$0.key: $0.value] }

    let timeInterval: TimeInterval? = parameters.timeoutInMilliseconds.map {
      Double($0) / 1000.0
    }

    let startBotParams = APIRequest(
      endpoint: endpoint,
      headers: headersArray,
      timeout: timeInterval
    )

    client?.startBotAndConnect(startBotParams: startBotParams) {
      (result: Result<DailyTransportConnectionParams, AsyncExecutionError>) in
      switch result {
      case .success(_):
        completion(.success(()))
      case .failure(let err):
        completion(.failure(err))
      }
    }
  }
  
  func disconnect(completion: @escaping (Result<Void, any Error>) -> Void) {
    client?.disconnect { result in
      switch result {
      case .success:
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
    eventStreamHandler?.sendEvent(UserTranscriptionEvent(
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
    eventStreamHandler?.sendEvent(BotOutputEvent(
      text: data.text,
      isSpoken: String(data.spoken),
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
