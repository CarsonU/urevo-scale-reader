import Foundation

@MainActor
protocol CSVServiceProtocol {
    func importWeights(from url: URL) throws -> ImportResult
    func exportWeights(to url: URL, entries: [WeightEntry]) throws
}

enum CSVServiceError: LocalizedError {
    case invalidEncoding

    var errorDescription: String? {
        switch self {
        case .invalidEncoding:
            return "CSV file is not UTF-8 encoded."
        }
    }
}

@MainActor
final class CSVService: CSVServiceProtocol {
    private let repository: WeightRepositoryProtocol

    init(repository: WeightRepositoryProtocol) {
        self.repository = repository
    }

    func importWeights(from url: URL) throws -> ImportResult {
        guard let rawData = try? Data(contentsOf: url),
              let content = String(data: rawData, encoding: .utf8)
        else {
            throw CSVServiceError.invalidEncoding
        }

        var importedCount = 0
        var skippedCount = 0
        var duplicateCount = 0
        var errors: [String] = []

        let allRows = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")

        for (index, rawRow) in allRows.enumerated() {
            let rowNumber = index + 1
            let row = rawRow.trimmingCharacters(in: .whitespacesAndNewlines)

            if row.isEmpty {
                continue
            }

            if rowNumber == 1, row.lowercased() == "timestamp,weight_lbs" {
                continue
            }

            let fields = row.split(separator: ",", omittingEmptySubsequences: false)
            guard fields.count == 2 else {
                skippedCount += 1
                errors.append("Row \(rowNumber): expected 2 columns")
                continue
            }

            let timestampText = String(fields[0]).trimmingCharacters(in: .whitespaces)
            let weightText = String(fields[1]).trimmingCharacters(in: .whitespaces)

            guard let timestamp = TimestampFormatters.parseImportTimestamp(timestampText) else {
                skippedCount += 1
                errors.append("Row \(rowNumber): invalid timestamp")
                continue
            }

            guard let weightLbs = Double(weightText) else {
                skippedCount += 1
                errors.append("Row \(rowNumber): invalid weight")
                continue
            }

            if try repository.hasDuplicate(timestamp: timestamp, weightLbs: weightLbs) {
                duplicateCount += 1
                continue
            }

            _ = try repository.save(weightLbs: weightLbs, timestamp: timestamp, source: .csvImport)
            importedCount += 1
        }

        return ImportResult(
            importedCount: importedCount,
            skippedCount: skippedCount,
            duplicateCount: duplicateCount,
            errors: errors
        )
    }

    func exportWeights(to url: URL, entries: [WeightEntry]) throws {
        var output = "timestamp,weight_lbs\n"

        let sortedEntries = entries.sorted(by: { $0.timestamp < $1.timestamp })
        for entry in sortedEntries {
            let timestamp = TimestampFormatters.exportISO8601.string(from: entry.timestamp)
            let weight = String(format: "%.1f", WeightFormatting.roundToTenth(entry.weightLbs))
            output += "\(timestamp),\(weight)\n"
        }

        try output.write(to: url, atomically: true, encoding: .utf8)
    }
}
