import XCTest
@testable import LocalMicStateControllerSupport

@MainActor
final class LocalMicStateControllerTests: XCTestCase {
  func testEnableWaitsForObservedInputThenPublishing() {
    let delegate = FakeDelegate(
      snapshot: LocalMicSnapshot(inputEnabled: false, publishingEnabled: false)
    )
    let controller = LocalMicStateController(delegate: delegate)
    var completion: Result<Void, Swift.Error>?

    controller.updateDesiredEnabled(true) { completion = $0 }

    XCTAssertEqual(delegate.operations, ["input:true"])
    XCTAssertNil(completion)

    delegate.completeNextRequest(.success(()))
    XCTAssertEqual(delegate.activeScheduledCount, 1)

    controller.observeSnapshot(LocalMicSnapshot(inputEnabled: true, publishingEnabled: false))
    XCTAssertEqual(delegate.operations, ["input:true", "publish:true"])
    XCTAssertFalse(controller.currentMicEnabled(fallback: true))

    delegate.completeNextRequest(.success(()))
    controller.observeSnapshot(LocalMicSnapshot(inputEnabled: true, publishingEnabled: true))

    XCTAssertTrue(completion?.isSuccess == true)
    XCTAssertFalse(controller.isTransitioning)
    XCTAssertTrue(controller.isSendingAudio)
  }

  func testDisableWaitsForObservedPublishingThenInput() {
    let delegate = FakeDelegate(
      snapshot: LocalMicSnapshot(inputEnabled: true, publishingEnabled: true)
    )
    let controller = LocalMicStateController(delegate: delegate)
    var completion: Result<Void, Swift.Error>?

    controller.updateDesiredEnabled(false) { completion = $0 }

    XCTAssertEqual(delegate.operations, ["publish:false"])
    XCTAssertNil(completion)

    delegate.completeNextRequest(.success(()))
    controller.observeSnapshot(LocalMicSnapshot(inputEnabled: true, publishingEnabled: false))
    XCTAssertEqual(delegate.operations, ["publish:false", "input:false"])
    XCTAssertFalse(controller.currentMicEnabled(fallback: true))

    delegate.completeNextRequest(.success(()))
    controller.observeSnapshot(LocalMicSnapshot(inputEnabled: false, publishingEnabled: false))

    XCTAssertTrue(completion?.isSuccess == true)
    XCTAssertFalse(controller.isTransitioning)
    XCTAssertFalse(controller.isSendingAudio)
  }

  func testRapidToggleRestartsFromLatestObservedSnapshot() {
    let delegate = FakeDelegate(
      snapshot: LocalMicSnapshot(inputEnabled: true, publishingEnabled: false)
    )
    let controller = LocalMicStateController(delegate: delegate)
    var firstCompletion: Result<Void, Swift.Error>?
    var secondCompletion: Result<Void, Swift.Error>?

    controller.updateDesiredEnabled(false) { firstCompletion = $0 }
    XCTAssertEqual(delegate.operations, ["input:false"])

    controller.updateDesiredEnabled(true) { secondCompletion = $0 }

    XCTAssertTrue(firstCompletion?.isSuccess == true)
    XCTAssertEqual(delegate.operations, ["input:false", "publish:true"])
    XCTAssertNil(secondCompletion)

    delegate.completeNextRequest(.success(()))
    XCTAssertNil(secondCompletion)

    delegate.completeNextRequest(.success(()))
    controller.observeSnapshot(LocalMicSnapshot(inputEnabled: true, publishingEnabled: true))

    XCTAssertTrue(secondCompletion?.isSuccess == true)
    XCTAssertTrue(controller.isSendingAudio)
  }

  func testPollingReappliesOnceThenFails() {
    let delegate = FakeDelegate(
      snapshot: LocalMicSnapshot(inputEnabled: false, publishingEnabled: false)
    )
    let controller = LocalMicStateController(
      delegate: delegate,
      config: LocalMicStateControllerConfig(pollInterval: 0.001, maxPollAttempts: 2)
    )
    var completion: Result<Void, Swift.Error>?

    controller.updateDesiredEnabled(true) { completion = $0 }
    XCTAssertEqual(delegate.operations, ["input:true"])

    delegate.completeNextRequest(.success(()))
    delegate.runNextScheduledAction()
    delegate.runNextScheduledAction()
    XCTAssertEqual(delegate.operations, ["input:true", "input:true"])

    delegate.completeNextRequest(.success(()))
    delegate.runNextScheduledAction()
    delegate.runNextScheduledAction()

    guard case .failure(let error)? = completion else {
      return XCTFail("Expected MIC_RECONCILE_ERROR failure.")
    }
    let micError = error as? LocalMicStateControllerError
    XCTAssertEqual(micError?.code, "MIC_RECONCILE_ERROR")
    XCTAssertFalse(controller.isTransitioning)
  }

  func testObservedDriftSelfHealsWhileIdle() {
    let delegate = FakeDelegate(
      snapshot: LocalMicSnapshot(inputEnabled: true, publishingEnabled: true)
    )
    let controller = LocalMicStateController(delegate: delegate)

    controller.observeSnapshot(LocalMicSnapshot(inputEnabled: true, publishingEnabled: true))
    controller.observeSnapshot(LocalMicSnapshot(inputEnabled: true, publishingEnabled: false))

    XCTAssertEqual(delegate.operations, ["publish:true"])

    delegate.completeNextRequest(.success(()))
    controller.observeSnapshot(LocalMicSnapshot(inputEnabled: true, publishingEnabled: true))

    XCTAssertFalse(controller.isTransitioning)
    XCTAssertTrue(controller.isSendingAudio)
  }
}

@MainActor
private final class FakeDelegate: LocalMicStateControllerDelegate {
  struct PendingRequest {
    let completion: (Result<Void, Swift.Error>) -> Void
  }

  var snapshot: LocalMicSnapshot?
  var operations: [String] = []
  private var pendingRequests: [PendingRequest] = []
  private var scheduledTasks: [FakeScheduledTask] = []

  init(snapshot: LocalMicSnapshot?) {
    self.snapshot = snapshot
  }

  var activeScheduledCount: Int {
    scheduledTasks.filter { !$0.isCancelled }.count
  }

  func issueSetInputEnabled(_ enabled: Bool, completion: @escaping (Result<Void, Swift.Error>) -> Void) {
    operations.append("input:\(enabled)")
    pendingRequests.append(PendingRequest(completion: completion))
  }

  func issueSetPublishingEnabled(_ enabled: Bool, completion: @escaping (Result<Void, Swift.Error>) -> Void) {
    operations.append("publish:\(enabled)")
    pendingRequests.append(PendingRequest(completion: completion))
  }

  func readSnapshot() -> LocalMicSnapshot? {
    snapshot
  }

  func schedule(delay: TimeInterval, action: @escaping () -> Void) -> LocalMicScheduledTask {
    let task = FakeScheduledTask(action: action)
    scheduledTasks.append(task)
    return task
  }

  func completeNextRequest(_ result: Result<Void, Swift.Error>) {
    guard !pendingRequests.isEmpty else {
      XCTFail("No pending request to complete.")
      return
    }
    let request = pendingRequests.removeFirst()
    request.completion(result)
  }

  func runNextScheduledAction() {
    while !scheduledTasks.isEmpty {
      let task = scheduledTasks.removeFirst()
      if !task.isCancelled {
        task.run()
        return
      }
    }
    XCTFail("No scheduled action to run.")
  }
}

private final class FakeScheduledTask: LocalMicScheduledTask {
  private let action: () -> Void
  private(set) var isCancelled = false

  init(action: @escaping () -> Void) {
    self.action = action
  }

  func cancel() {
    isCancelled = true
  }

  func run() {
    guard !isCancelled else { return }
    action()
  }
}

private extension Result where Success == Void {
  var isSuccess: Bool {
    if case .success = self {
      return true
    }
    return false
  }
}
