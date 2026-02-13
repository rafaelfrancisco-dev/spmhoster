import XCTVapor

@testable import spmhoster

final class ArtifactCleanupTests: XCTestCase {

  // MARK: - SizeParser Tests

  func testSizeParser() throws {
    XCTAssertEqual(SizeParser.parse("100"), 100)
    XCTAssertEqual(SizeParser.parse("1KB"), 1024)
    XCTAssertEqual(SizeParser.parse("1MB"), 1024 * 1024)
    XCTAssertEqual(SizeParser.parse("1GB"), 1024 * 1024 * 1024)
    XCTAssertEqual(SizeParser.parse("1.5 MB"), Int(1.5 * 1024 * 1024))
    XCTAssertNil(SizeParser.parse("Invalid"))
  }

  // MARK: - ArtifactCleaner Tests

  func testArtifactCleaner() async throws {
    let app = try await Application.make(.testing)

    // Setup temporary directory
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

    // Defer cleanup of temp directory
    defer { try? FileManager.default.removeItem(at: tempDir) }

    // Create dummy files
    // File 1: Oldest, 1MB
    let file1 = tempDir.appendingPathComponent("file1.zip")
    try Data(count: 1024 * 1024).write(to: file1)
    try FileManager.default.setAttributes(
      [.creationDate: Date().addingTimeInterval(-3600)], ofItemAtPath: file1.path)

    // File 2: Newest, 1MB
    let file2 = tempDir.appendingPathComponent("file2.zip")
    try Data(count: 1024 * 1024).write(to: file2)
    try FileManager.default.setAttributes([.creationDate: Date()], ofItemAtPath: file2.path)

    // Limit to 1.5MB (should delete 1 file, the oldest)
    ArtifactCleaner.clean(directory: tempDir, maxSize: Int(1.5 * 1024 * 1024), logger: app.logger)

    XCTAssertFalse(
      FileManager.default.fileExists(atPath: file1.path), "Oldest file should be deleted")
    XCTAssertTrue(FileManager.default.fileExists(atPath: file2.path), "Newest file should remain")

    // Create another file (1MB)
    let file3 = tempDir.appendingPathComponent("file3.zip")
    try Data(count: 1024 * 1024).write(to: file3)
    // Set date to be newer than file2? No, let's just use current date.

    // Now total is 2MB. Limit to 0.5MB (should delete all except maybe one if it fits, but 1MB > 0.5MB, so logic might keep deleting?)
    // The logic is: delete oldest until currentSize <= maxSize.
    // If single file > maxSize, it will delete it if it's the oldest and helps reducing size?
    // Logic: while currentSize > maxSize.
    // If we have 2 files (2MB), limit 0.5MB.
    // Delete oldest -> 1MB left. Still > 0.5MB.
    // Delete next oldest -> 0MB left.

    ArtifactCleaner.clean(directory: tempDir, maxSize: 500 * 1024, logger: app.logger)

    // Checking if everything is gone
    let files = try FileManager.default.contentsOfDirectory(
      at: tempDir, includingPropertiesForKeys: nil)
    XCTAssertTrue(files.isEmpty, "All files should be deleted as they exceed limit")

    try await app.asyncShutdown()
  }
}
