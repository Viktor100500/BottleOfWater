import Foundation
import HealthKit

/// Синхронизация с Apple Health: каждая запись пишется/удаляется в реальном времени
/// (в том числе прямо из widget extension). Приложение полноценно работает и без
/// разрешения Health.
///
/// Защита от расхождений: каждый сэмпл несёт `HKMetadataKeyExternalUUID` = id нашей
/// записи. Если синхронизация прервалась после записи в Health, но до сохранения её
/// ID у нас, повторная попытка сначала ищет сэмпл по external UUID и «усыновляет»
/// его вместо создания дубля. Удаление по external UUID снимает и случайные дубли.
final class HealthKitService {
    static let shared = HealthKitService()
    private let store = HKHealthStore()
    private var waterType: HKQuantityType { HKQuantityType(.dietaryWater) }

    private var available: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorizationIfNeeded() async {
        guard available,
              store.authorizationStatus(for: waterType) == .notDetermined else { return }
        // В widget extension диалог не показывается — разрешение выдаёт приложение;
        // здесь вызов просто не сработает и save вернёт nil (запись останется pending).
        let types: Set<HKSampleType> = [waterType]
        _ = try? await store.requestAuthorization(toShare: types, read: types)
    }

    /// Сохраняет объём в Health; возвращает UUID сэмпла для последующего удаления.
    func save(volumeML: Int, date: Date, entryID: UUID) async -> UUID? {
        guard available else { return nil }
        await requestAuthorizationIfNeeded()
        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: Double(volumeML))
        let sample = HKQuantitySample(type: waterType, quantity: quantity,
                                      start: date, end: date,
                                      metadata: [HKMetadataKeyExternalUUID: entryID.uuidString])
        do {
            try await store.save(sample)
            return sample.uuid
        } catch {
            return nil
        }
    }

    /// Ищет уже сохранённый сэмпл этой записи — защита от дублей при прерванной синхронизации.
    func existingSampleID(entryID: UUID) async -> UUID? {
        guard available else { return nil }
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeyExternalUUID,
                                                    allowedValues: [entryID.uuidString])
        return await samples(matching: predicate, limit: 1).first?.uuid
    }

    /// Удаляет сэмпл по его HealthKit UUID (записи, созданные до появления external UUID).
    @discardableResult
    func delete(sampleID: UUID) async -> Bool {
        await deleteSamples(matching: HKQuery.predicateForObject(with: sampleID))
    }

    /// Удаляет ВСЕ сэмплы записи по external UUID — включая случайные дубли.
    @discardableResult
    func delete(entryID: UUID) async -> Bool {
        await deleteSamples(matching: HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeyExternalUUID,
            allowedValues: [entryID.uuidString]))
    }

    private func deleteSamples(matching predicate: NSPredicate) async -> Bool {
        guard available else { return false }
        let found = await samples(matching: predicate, limit: HKObjectQueryNoLimit)
        guard !found.isEmpty else { return true }   // нечего удалять — успех
        do {
            try await store.delete(found)
            return true
        } catch {
            return false
        }
    }

    private func samples(matching predicate: NSPredicate, limit: Int) async -> [HKSample] {
        await withCheckedContinuation { cont in
            let query = HKSampleQuery(sampleType: waterType, predicate: predicate,
                                      limit: limit, sortDescriptors: nil) { _, result, _ in
                cont.resume(returning: result ?? [])
            }
            store.execute(query)
        }
    }
}
