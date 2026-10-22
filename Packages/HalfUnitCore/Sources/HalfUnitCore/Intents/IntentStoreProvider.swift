import Foundation
import OSLog
import SwiftData

public enum IntentStoreProvider {
    private static let logger = Logger(
        subsystem: "es.opinasdeque.halfunit",
        category: "IntentStoreProvider"
    )

    public static let shared: ModelContainer = makeModelContainer()

    private static func makeModelContainer(bundle: Bundle = .main) -> ModelContainer {
        let appGroupIdentifier = bundle.object(forInfoDictionaryKey: "HalfUnitAppGroup") as? String
        let cloudKitContainer =
            bundle.object(forInfoDictionaryKey: "HalfUnitCloudKitContainer") as? String

        let storeURL: URL? =
            if let appGroupIdentifier,
                let groupURL = FileManager.default.containerURL(
                    forSecurityApplicationGroupIdentifier: appGroupIdentifier
                )
            {
                groupURL.appending(path: "HalfUnit.store")
            } else {
                nil
            }

        do {
            return try ModelContainerFactory.make(
                storeURL: storeURL,
                cloudKitContainerIdentifier: cloudKitContainer,
                inMemory: false
            )
        } catch {
            logger.notice(
                "CloudKit container init failed; falling back to local store: \(error.localizedDescription, privacy: .public)"
            )
            do {
                return try ModelContainerFactory.make(
                    storeURL: storeURL,
                    cloudKitContainerIdentifier: nil,
                    inMemory: false
                )
            } catch {
                logger.error(
                    "Local store init failed; falling back to in-memory store: \(error.localizedDescription, privacy: .public)"
                )
                do {
                    return try ModelContainerFactory.make(inMemory: true)
                } catch {
                    preconditionFailure("Unable to create in-memory ModelContainer")
                }
            }
        }
    }
}
