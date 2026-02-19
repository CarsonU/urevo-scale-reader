import Foundation
import SwiftData
import XCTest
@testable import UrevoScale

@MainActor
final class CSVServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var repository: WeightRepository!
    private var service: CSVService!

    override func setUpWithError() throws {
        container = PersistenceController.makeContainer(inMemory: true)
        repository = WeightRepository(container: container)
        service = CSVService(repository: repository)
    }

    override func tearDownWithError() throws {
        service = nil
        repository = nil
        container = nil
    }

    func testImportHandlesDuplicatesAndMalformedRows() throws {
        let csv = """
        timestamp,weight_lbs
        2026-02-19T10:33:36.651624,176.4
        2026-02-19T10:33:36.900000,176.44
        invalid,row,shape
        2026-02-19T10:33:37.000000,oops
        """

        let fileURL = writeTempCSV(csv)
        let result = try service.importWeights(from: fileURL)

        XCTAssertEqual(result.importedCount, 1)
        XCTAssertEqual(result.duplicateCount, 1)
        XCTAssertEqual(result.skippedCount, 2)

        let entries = try repository.fetchAll()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.source, .csvImport)
    }

    func testExportSchemaAndTimestampFormat() throws {
        _ = try repository.save(
            weightLbs: 176.4,
            timestamp: Date(timeIntervalSince1970: 1_707_000_000.123),
            source: .live
        )

        let outputURL = tempFileURL(fileName: "export.csv")
        try service.exportWeights(to: outputURL, entries: try repository.fetchAll())

        let content = try String(contentsOf: outputURL, encoding: .utf8)
        let lines = content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n")

        XCTAssertEqual(lines.first, "timestamp,weight_lbs")
        XCTAssertEqual(lines.count, 2)

        let payload = lines[1].split(separator: ",")
        XCTAssertEqual(payload.count, 2)

        let timestamp = String(payload[0])
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        XCTAssertNotNil(formatter.date(from: timestamp))

        XCTAssertEqual(String(payload[1]), "176.4")
    }

    private func writeTempCSV(_ content: String) -> URL {
        let url = tempFileURL(fileName: "import.csv")
        try? content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func tempFileURL(fileName: String) -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(UUID().uuidString)-\(fileName)")
    }
}
