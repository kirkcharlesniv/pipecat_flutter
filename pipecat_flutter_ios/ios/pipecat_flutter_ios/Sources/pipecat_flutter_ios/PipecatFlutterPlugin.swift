@preconcurrency import Flutter
import PipecatClientIOS
import PipecatClientIOSDaily
import UIKit

@MainActor
public class PipecatFlutterPlugin: NSObject, FlutterPlugin, @preconcurrency PipecatHostApi {
  private var client: PipecatClient?
//  private var eventSink: PigeonEventSink<PipecatEvent>?

  nonisolated public static func register(with registrar: FlutterPluginRegistrar) {
      let messenger = registrar.messenger()
      MainActor.assumeIsolated {
          let instance = PipecatFlutterPlugin()
          PipecatHostApiSetup.setUp(binaryMessenger: messenger, api: instance)
      }
  }
  
  func startAndConnect(
    parameters: StartBotParams,
    completion: @escaping (Result<Void, any Error>) -> Void
  ) {
    let options = PipecatClientOptions(
      transport: DailyTransport(),
      enableMic: parameters.shouldEnableMicrophone,
      enableCam: parameters.shouldEnableCamera,
    )
    client = PipecatClient(options: options)

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

    // Convert dictionary to array of dictionaries format
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
        // TODO: Send connection state event to Flutter
        completion(.success(()))
      case .failure(let err):
        // TODO: Send error and disconnection events to Flutter
        completion(.failure(err))
      }
    }
  }
  
  func disconnect(completion: @escaping (Result<Void, any Error>) -> Void) {
    client?.disconnect { result in
      switch result {
      case .success:
        // TODO: Send connection state event to Flutter
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
        completion(
          .failure(
            PigeonError(
              code: "MIC_ERROR",
              message: error.localizedDescription,
              details: nil
            )
          )
        )
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
        completion(
          .failure(
            PigeonError(
              code: "CAMERA_ERROR",
              message: error.localizedDescription,
              details: nil
            )
          )
        )
      }
    }
  }
}
