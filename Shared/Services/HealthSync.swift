import Foundation
import HealthKit

/// Write-only Apple Health sync for dietary water.
///
/// Every sample carries `HKMetadataKeySyncIdentifier` = entry id and
/// `HKMetadataKeySyncVersion`: saving the same entry again *replaces* the sample
/// instead of duplicating it, which makes retries and edits idempotent.
/// No read permission is requested — an app can always query its own samples.
final class HealthSync: Sendable {
    static let shared = HealthSync()

    struct Sample: Sendable {
        var syncID: String
        var volumeML: Int
        var date: Date
        var version: Int
        var legacySampleID: UUID?
    }

    enum Status: Sendable {
        case unavailable, notDetermined, denied, connected
    }

    private let store = HKHealthStore()
    private let waterType = HKQuantityType(.dietaryWater)

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    var status: Status {
        guard isAvailable else { return .unavailable }
        switch store.authorizationStatus(for: waterType) {
        case .sharingAuthorized: return .connected
        case .sharingDenied: return .denied
        default: return .notDetermined
        }
    }

    var canWrite: Bool { status == .connected }

    /// Shows the system sheet once; afterwards the choice lives in the Health app.
    @discardableResult
    func requestAuthorization() async -> Status {
        guard isAvailable else { return .unavailable }
        try? await store.requestAuthorization(toShare: [waterType], read: [])
        return status
    }

    func save(_ sample: Sample) async -> Bool {
        guard canWrite else { return false }
        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: Double(sample.volumeML))
        let object = HKQuantitySample(
            type: waterType, quantity: quantity, start: sample.date, end: sample.date,
            metadata: [
                HKMetadataKeySyncIdentifier: sample.syncID,
                HKMetadataKeySyncVersion: sample.version,
                HKMetadataKeyExternalUUID: sample.syncID,
            ])
        do {
            try await store.save(object)
            return true
        } catch {
            return false
        }
    }

    /// Deletes every sample of an entry: by sync id, by v0 external UUID, by v0 sample UUID.
    func delete(_ sample: Sample) async -> Bool {
        guard canWrite else { return false }
        var predicates = [
            HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier,
                                        allowedValues: [sample.syncID]),
            HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeyExternalUUID,
                                        allowedValues: [sample.syncID]),
        ]
        if let legacy = sample.legacySampleID {
            predicates.append(HKQuery.predicateForObject(with: legacy))
        }
        return await deleteObjects(matching: NSCompoundPredicate(orPredicateWithSubpredicates: predicates))
    }

    func deleteLegacy(sampleID: UUID) async -> Bool {
        guard canWrite else { return false }
        return await deleteObjects(matching: HKQuery.predicateForObject(with: sampleID))
    }

    private func deleteObjects(matching predicate: NSPredicate) async -> Bool {
        await withCheckedContinuation { continuation in
            store.deleteObjects(of: waterType, predicate: predicate) { success, _, error in
                // "No matching objects" is not a failure — there is simply nothing to delete.
                let nothingToDelete = (error as? HKError)?.code == .errorNoData
                continuation.resume(returning: success || nothingToDelete)
            }
        }
    }
}
