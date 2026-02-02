//
//  DailyHelper.swift
//  Pods
//
//  Created by Kirk Charles Niverba on 2/3/26.
//
import Daily
import PipecatClientIOSDaily

@MainActor
func muteRemoteParticipantAudio(
    transport: DailyTransport,
    muted: Bool
) async throws {
    guard let callClient = transport.dailyCallClient else {
        throw NSError(domain: "DailyHelper", code: 1, userInfo: [NSLocalizedDescriptionKey: "CallClient not available"])
    }
    
    guard let botParticipantId = callClient.participants.remote.keys.first else {
        throw NSError(domain: "DailyHelper", code: 2, userInfo: [NSLocalizedDescriptionKey: "No remote participant found"])
    }
    
    _ = try await callClient.updateSubscriptions(
        forParticipants: .set([
            botParticipantId: .set(SubscriptionSettingsUpdate(
                media: .set(MediaSubscriptionSettingsUpdate(
                    microphone: .set(.subscribed(!muted))
                ))
            ))
        ])
    )
}
