import Foundation

enum EntrySource: String, Codable, CaseIterable {
    case live
    case csvImport
}
