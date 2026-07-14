import Foundation
import HealthKit

/// Синхронизация с Apple Health: каждая запись пишется/удаляется в реальном времени.
/// Приложение полноценно работает и без разрешения Health.
final class HealthKitService {
    static let shared = HealthKitService()
    private let store = HKHealthStore()
    private var waterType: HKQuantityType { HKQuantityType(.dietaryWater) }

    private var available: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorizationIfNeeded() async {
        guard available else { return }
        let types: Set<HKSampleType> = [waterType]
        _ = try? await store.requestAuthorization(toShare: types, read: types)
    }

    /// Сохраняет объём в Health; возвращает UUID сэмпла для последующего удаления.
    func save(volumeML: Int, date: Date) async -> UUID? {
        guard available else { return nil }
        await requestAuthorizationIfNeeded()
        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: Double(volumeML))
        let sample = HKQuantitySample(type: waterType, quantity: quantity, start: date, end: date)
        do {
            try await store.save(sample)
            return sample.uuid
        } catch {
            return nil
        }
    }

    func delete(sampleID: UUID) async {
        guard available else { return }
        let predicate = HKQuery.predicateForObject(with: sampleID)
        let samples: [HKSample] = await withCheckedContinuation { cont in
            let query = HKSampleQuery(sampleType: waterType, predicate: predicate,
                                      limit: 1, sortDescriptors: nil) { _, result, _ in
                cont.resume(returning: result ?? [])
            }
            store.execute(query)
        }
        guard let sample = samples.first else { return }
        try? await store.delete(sample)
    }
}
