import Foundation
import SwiftData

public enum ModelContainerFactory {
    public static func make(
        storeURL: URL? = nil,
        cloudKitContainerIdentifier: String? = nil,
        inMemory: Bool = false
    ) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration: ModelConfiguration

        if inMemory {
            configuration = ModelConfiguration(
                UUID().uuidString,
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        } else {
            let cloudKitDatabase: ModelConfiguration.CloudKitDatabase =
                if let cloudKitContainerIdentifier {
                    .private(cloudKitContainerIdentifier)
                } else {
                    .none
                }

            if let storeURL {
                configuration = ModelConfiguration(
                    schema: schema,
                    url: storeURL,
                    cloudKitDatabase: cloudKitDatabase
                )
            } else {
                configuration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: cloudKitDatabase
                )
            }
        }

        return try ModelContainer(
            for: schema,
            migrationPlan: HalfUnitMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
