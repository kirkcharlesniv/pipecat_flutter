import Foundation

struct LocalMicSnapshot: Equatable {
  let inputEnabled: Bool
  let publishingEnabled: Bool

  var isSending: Bool {
    inputEnabled && publishingEnabled
  }

  func matchesDesired(_ enabled: Bool) -> Bool {
    inputEnabled == enabled && publishingEnabled == enabled
  }
}

struct LocalMicStateControllerConfig {
  let pollInterval: TimeInterval
  let maxPollAttempts: Int

  init(pollInterval: TimeInterval = 0.1, maxPollAttempts: Int = 10) {
    self.pollInterval = pollInterval
    self.maxPollAttempts = maxPollAttempts
  }
}

struct LocalMicStateControllerError: Error {
  let code: String
  let message: String
}

protocol LocalMicScheduledTask: AnyObject {
  func cancel()
}

@MainActor
protocol LocalMicStateControllerDelegate: AnyObject {
  func issueSetInputEnabled(
    _ enabled: Bool,
    completion: @escaping (Result<Void, Swift.Error>) -> Void
  )
  func issueSetPublishingEnabled(
    _ enabled: Bool,
    completion: @escaping (Result<Void, Swift.Error>) -> Void
  )
  func readSnapshot() -> LocalMicSnapshot?
  func schedule(delay: TimeInterval, action: @escaping () -> Void) -> LocalMicScheduledTask
}

@MainActor
final class LocalMicStateController {
  enum Phase {
    case idle
    case waitingForInputEnable
    case waitingForPublishEnable
    case waitingForPublishDisable
    case waitingForInputDisable
  }

  private struct Transition {
    let generation: Int64
    let phase: Phase
    let completion: ((Result<Void, Swift.Error>) -> Void)?
    let pollAttempts: Int
    let didReapply: Bool
  }

  private weak var delegate: LocalMicStateControllerDelegate?
  private let config: LocalMicStateControllerConfig

  private var generationCounter: Int64 = 0
  private var transition: Transition?
  private var pendingPoll: LocalMicScheduledTask?

  private(set) var desiredEnabled = true
  private(set) var observedSnapshot: LocalMicSnapshot?

  init(
    delegate: LocalMicStateControllerDelegate,
    config: LocalMicStateControllerConfig = LocalMicStateControllerConfig()
  ) {
    self.delegate = delegate
    self.config = config
  }

  var phase: Phase {
    transition?.phase ?? .idle
  }

  var isTransitioning: Bool {
    transition != nil
  }

  var isSendingAudio: Bool {
    observedSnapshot?.isSending == true
  }

  func reset(desiredEnabled: Bool = true) {
    self.desiredEnabled = desiredEnabled
    observedSnapshot = nil
    generationCounter += 1
    transition = nil
    cancelPendingPoll()
  }

  func updateDesiredEnabled(
    _ enabled: Bool,
    completion: ((Result<Void, Swift.Error>) -> Void)? = nil
  ) {
    desiredEnabled = enabled
    let snapshot = refreshSnapshot()
    if snapshot?.matchesDesired(enabled) == true {
      completeActiveTransition(with: .success(()))
      completion?(.success(()))
      return
    }

    cancelActiveTransition(with: .success(()))
    startTransition(snapshot: snapshot, completion: completion)
  }

  func observeSnapshot(_ snapshot: LocalMicSnapshot) {
    observedSnapshot = snapshot

    guard let activeTransition = transition else {
      if !snapshot.matchesDesired(desiredEnabled) {
        startTransition(snapshot: snapshot, completion: nil)
      }
      return
    }

    if snapshot.matchesDesired(desiredEnabled) {
      completeActiveTransition(with: .success(()))
      return
    }

    if !phaseSatisfied(activeTransition.phase, snapshot: snapshot) {
      return
    }

    let nextPhase = nextPhase(snapshot: snapshot, desiredEnabled: desiredEnabled)
    guard let nextPhase else {
      completeActiveTransition(with: .success(()))
      return
    }

    if nextPhase == activeTransition.phase {
      return
    }

    cancelPendingPoll()
    transition = Transition(
      generation: activeTransition.generation,
      phase: nextPhase,
      completion: activeTransition.completion,
      pollAttempts: 0,
      didReapply: false
    )
    executeCurrentPhase()
  }

  func currentMicEnabled(fallback: Bool) -> Bool {
    observedSnapshot?.isSending ?? fallback
  }

  private func startTransition(
    snapshot: LocalMicSnapshot?,
    completion: ((Result<Void, Swift.Error>) -> Void)?
  ) {
    guard let initialPhase = nextPhase(snapshot: snapshot, desiredEnabled: desiredEnabled) else {
      completion?(.success(()))
      return
    }

    transition = Transition(
      generation: nextGeneration(),
      phase: initialPhase,
      completion: completion,
      pollAttempts: 0,
      didReapply: false
    )
    executeCurrentPhase()
  }

  private func executeCurrentPhase() {
    guard let activeTransition = transition, let delegate = delegate else { return }
    cancelPendingPoll()

    let completion: (Result<Void, Swift.Error>) -> Void = { [weak self] result in
      guard let self else { return }
      guard let current = self.transition, current.generation == activeTransition.generation else {
        return
      }

      switch result {
      case .failure:
        self.completeActiveTransition(with: result)
      case .success:
        self.schedulePoll(generation: activeTransition.generation)
      }
    }

    switch activeTransition.phase {
    case .idle:
      completeActiveTransition(with: .success(()))
    case .waitingForInputEnable:
      delegate.issueSetInputEnabled(true, completion: completion)
    case .waitingForPublishEnable:
      delegate.issueSetPublishingEnabled(true, completion: completion)
    case .waitingForPublishDisable:
      delegate.issueSetPublishingEnabled(false, completion: completion)
    case .waitingForInputDisable:
      delegate.issueSetInputEnabled(false, completion: completion)
    }
  }

  private func schedulePoll(generation: Int64) {
    guard let delegate else { return }
    cancelPendingPoll()
    pendingPoll = delegate.schedule(delay: config.pollInterval) { [weak self] in
      self?.onPoll(generation: generation)
    }
  }

  private func onPoll(generation: Int64) {
    guard let activeTransition = transition, activeTransition.generation == generation else {
      return
    }

    if let snapshot = refreshSnapshot() {
      observeSnapshot(snapshot)
    }

    guard let current = transition, current.generation == generation else {
      return
    }

    let attempts = current.pollAttempts + 1
    if attempts < config.maxPollAttempts {
      transition = Transition(
        generation: current.generation,
        phase: current.phase,
        completion: current.completion,
        pollAttempts: attempts,
        didReapply: current.didReapply
      )
      schedulePoll(generation: generation)
      return
    }

    if !current.didReapply {
      transition = Transition(
        generation: current.generation,
        phase: current.phase,
        completion: current.completion,
        pollAttempts: 0,
        didReapply: true
      )
      executeCurrentPhase()
      return
    }

    completeActiveTransition(
      with: .failure(
        LocalMicStateControllerError(
          code: "MIC_RECONCILE_ERROR",
          message: "Daily microphone input/publishing did not reach requested state."
        )
      )
    )
  }

  private func refreshSnapshot() -> LocalMicSnapshot? {
    let snapshot = delegate?.readSnapshot()
    if let snapshot {
      observedSnapshot = snapshot
    }
    return snapshot
  }

  private func completeActiveTransition(with result: Result<Void, Swift.Error>) {
    let completion = transition?.completion
    transition = nil
    cancelPendingPoll()
    completion?(result)
  }

  private func cancelActiveTransition(with result: Result<Void, Swift.Error>) {
    let completion = transition?.completion
    transition = nil
    cancelPendingPoll()
    completion?(result)
  }

  private func cancelPendingPoll() {
    pendingPoll?.cancel()
    pendingPoll = nil
  }

  private func nextGeneration() -> Int64 {
    generationCounter += 1
    return generationCounter
  }

  private func nextPhase(snapshot: LocalMicSnapshot?, desiredEnabled: Bool) -> Phase? {
    guard let snapshot else {
      return desiredEnabled ? .waitingForInputEnable : .waitingForPublishDisable
    }

    if desiredEnabled {
      if !snapshot.inputEnabled {
        return .waitingForInputEnable
      }
      if !snapshot.publishingEnabled {
        return .waitingForPublishEnable
      }
      return nil
    }

    if snapshot.publishingEnabled {
      return .waitingForPublishDisable
    }
    if snapshot.inputEnabled {
      return .waitingForInputDisable
    }
    return nil
  }

  private func phaseSatisfied(_ phase: Phase, snapshot: LocalMicSnapshot) -> Bool {
    switch phase {
    case .idle:
      return true
    case .waitingForInputEnable:
      return snapshot.inputEnabled
    case .waitingForPublishEnable:
      return snapshot.publishingEnabled
    case .waitingForPublishDisable:
      return !snapshot.publishingEnabled
    case .waitingForInputDisable:
      return !snapshot.inputEnabled
    }
  }
}
