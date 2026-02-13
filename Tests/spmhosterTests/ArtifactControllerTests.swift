import XCTVapor

@testable import spmhoster

final class ArtifactControllerTests: XCTestCase {
  var app: Application!

  override func setUp() async throws {
    app = try await Application.make(.testing)
    try await configure(app)
  }

  override func tearDown() async throws {
    try await app.asyncShutdown()
    app = nil
  }

  func testUpload() async throws {
    let zipContent = "dummy zip content".data(using: .utf8)!
    let filename = "test.zip"
    let file = File(data: ByteBuffer(data: zipContent), filename: filename)

    try await app.test(
      .POST, "upload",
      beforeRequest: { req async in
        try? req.content.encode(UploadInput(file: file), as: .formData)
      },
      afterResponse: { res async in
        XCTAssertEqual(res.status, .ok)

        let body = res.body.string
        XCTAssertTrue(body.contains("name: \"test\""))
        XCTAssertTrue(body.contains("url: \"http://localhost:8080/artifacts/test.zip\""))
        XCTAssertTrue(body.contains("checksum:"))

        // Verify file exists in working directory
        let filePath = app.directory.workingDirectory + "artifacts/" + filename
        XCTAssertTrue(FileManager.default.fileExists(atPath: filePath))

        // Cleanup
        try? FileManager.default.removeItem(atPath: filePath)
      })
  }

  func testUploadWithHttpsHeader() async throws {
    let zipContent = "dummy zip content".data(using: .utf8)!
    let filename = "test_https.zip"
    let file = File(data: ByteBuffer(data: zipContent), filename: filename)

    try await app.test(
      .POST, "upload",
      beforeRequest: { req async in
        try? req.content.encode(UploadInput(file: file), as: .formData)
        req.headers.add(name: "X-Forwarded-Proto", value: "https")
      },
      afterResponse: { res async in
        XCTAssertEqual(res.status, .ok)

        let body = res.body.string
        XCTAssertTrue(body.contains("url: \"https://localhost:8080/artifacts/test_https.zip\""))

        // Cleanup
        let filePath = app.directory.workingDirectory + "artifacts/" + filename
        try? FileManager.default.removeItem(atPath: filePath)
      })
  }

  func testDownload() async throws {
    let content = "download content".data(using: .utf8)!
    let filename = "download.zip"

    // Create dummy file
    let directory = app.directory.workingDirectory
    let artifactsPath = directory + "artifacts/"
    try FileManager.default.createDirectory(
      atPath: artifactsPath, withIntermediateDirectories: true)
    let filePath = artifactsPath + filename

    // Write content
    try content.write(to: URL(fileURLWithPath: filePath))

    try await app.test(
      .GET, "artifacts/\(filename)",
      afterResponse: { res async in
        XCTAssertEqual(res.status, .ok)
        XCTAssertEqual(res.body.string, "download content")
      })

    // Cleanup
    try? FileManager.default.removeItem(atPath: artifactsPath)
  }

  func testInvalidExtension() async throws {
    let content = "bad content".data(using: .utf8)!
    let filename = "test.txt"
    let file = File(data: ByteBuffer(data: content), filename: filename)

    try await app.test(
      .POST, "upload",
      beforeRequest: { req async in
        try? req.content.encode(UploadInput(file: file), as: .formData)
      },
      afterResponse: { res async in
        XCTAssertEqual(res.status, .badRequest)
      })
  }
}
