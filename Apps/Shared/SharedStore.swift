import AppIntents
import Foundation
import HalfUnitCore
import SwiftData

enum SharedStore {
    static var shared: ModelContainer {
        IntentStoreProvider.shared
    }
}

struct HalfUnitTargetIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [HalfUnitCoreIntentsPackage.self]
    }
}
