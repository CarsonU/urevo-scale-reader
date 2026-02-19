import Foundation

struct ImportResult: Equatable {
    var importedCount: Int
    var skippedCount: Int
    var duplicateCount: Int
    var errors: [String]
}
