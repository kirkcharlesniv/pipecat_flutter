//
//  PipecatStreamHandlers.swift
//  Pods
//
//  Created by Kirk Charles Niverba on 2/1/26.
//

class TimelineEventStreamHandler: TimelineEventsStreamHandler {
  private var eventSink: PigeonEventSink<TimelineEvent>?
  
  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<TimelineEvent>) {
    self.eventSink = sink
  }
  
  override func onCancel(withArguments arguments: Any?) {
    self.eventSink = nil
  }
  
  func sendEvent(_ event: TimelineEvent) {
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
