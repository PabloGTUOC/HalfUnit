import AppIntents
import Foundation
import HalfUnitCore
import SwiftData

enum SharedStore {
    static func makeModelContainer(bundle: Bundle = .main) -> ModelContainer {
        IntentStoreProvider.makeModelContainer(bundle: bundle)
    }
}

struct HalfUnitTargetIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [HalfUnitCoreIntentsPackage.self]
    }
}
