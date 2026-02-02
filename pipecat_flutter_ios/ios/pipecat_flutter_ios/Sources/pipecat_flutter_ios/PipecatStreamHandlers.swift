//
//  PipecatStreamHandlers.swift
//  Pods
//
//  Created by Kirk Charles Niverba on 2/1/26.
//

class PipecatEventStreamHandler: EventsStreamHandler {
  private var eventSink: PigeonEventSink<PipecatEvent>?
  
  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<PipecatEvent>) {
    self.eventSink = sink
  }
  
  override func onCancel(withArguments arguments: Any?) {
    self.eventSink = nil
  }
  
  func sendEvent(_ event: PipecatEvent) {
    eventSink?.success(event)
  }
}

class LocalAudioLevelHandler: LocalAudioLevelStreamHandler {
  private var sink: PigeonEventSink<AudioLevel>?
  
  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<AudioLevel>) {
    self.sink = sink
  }
  
  override func onCancel(withArguments arguments: Any?) {
    self.sink = nil
  }
  
  func sendLevel(_ level: Double) {
    sink?.success(AudioLevel(level: level))
  }
}

class RemoteAudioLevelHandler: RemoteAudioLevelStreamHandler {
  private var sink: PigeonEventSink<AudioLevel>?
  
  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<AudioLevel>) {
    self.sink = sink
  }
  
  override func onCancel(withArguments arguments: Any?) {
    self.sink = nil
  }
  
  func sendLevel(_ level: Double) {
    sink?.success(AudioLevel(level: level))
  }
}

class BotOutputHandler: BotOutputStreamHandler {
  private var sink: PigeonEventSink<BotOutputEvent>?
  
  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<BotOutputEvent>) {
    self.sink = sink
  }
  
  override func onCancel(withArguments arguments: Any?) {
    self.sink = nil
  }
  
  func sendEvent(_ event: BotOutputEvent) {
    sink?.success(event)
  }
}

class UserTranscriptionHandler: UserTranscriptionsStreamHandler {
  private var sink: PigeonEventSink<UserTranscriptionEvent>?
  
  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<UserTranscriptionEvent>) {
    self.sink = sink
  }
  
  override func onCancel(withArguments arguments: Any?) {
    self.sink = nil
  }
  
  func sendEvent(_ event: UserTranscriptionEvent) {
    sink?.success(event)
  }
}

class ConnectionStateHandler: ConnectionStateEventsStreamHandler {
  private var sink: PigeonEventSink<ConnectionStateEvent>?
  
  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<ConnectionStateEvent>) {
    self.sink = sink
  }
  
  override func onCancel(withArguments arguments: Any?) {
    self.sink = nil
  }
  
  func sendEvent(_ event: ConnectionStateEvent) {
    sink?.success(event)
  }
}


class SpeakingEventHandler: SpeakingEventsStreamHandler {
  private var sink: PigeonEventSink<SpeakingEvent>?
  
  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<SpeakingEvent>) {
    self.sink = sink
  }
  
  override func onCancel(withArguments arguments: Any?) {
    self.sink = nil
  }
  
  func sendEvent(_ event: SpeakingEvent) {
    sink?.success(event)
  }
}
