import Daily
import Foundation

@MainActor
public protocol DailyTransportObserver: AnyObject {
    func dailyTransport(_ transport: DailyTransport, inputsUpdated inputs: InputSettings)
    func dailyTransport(_ transport: DailyTransport, publishingUpdated publishing: PublishingSettings)
    func dailyTransport(_ transport: DailyTransport, subscriptionsUpdated subscriptions: SubscriptionSettingsByID)
}

public extension DailyTransportObserver {
    func dailyTransport(_ transport: DailyTransport, inputsUpdated inputs: InputSettings) {}
    func dailyTransport(_ transport: DailyTransport, publishingUpdated publishing: PublishingSettings) {}
    func dailyTransport(_ transport: DailyTransport, subscriptionsUpdated subscriptions: SubscriptionSettingsByID) {}
}

final class WeakDailyTransportObserver {
    weak var value: DailyTransportObserver?

    init(value: DailyTransportObserver) {
        self.value = value
    }
}
