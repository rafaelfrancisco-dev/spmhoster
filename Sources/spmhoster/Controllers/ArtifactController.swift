import Crypto
import Vapor

struct ArtifactController: RouteCollection {
  func boot(routes: any RoutesBuilder) throws {
    // Upload route
    routes.on(.POST, "upload", body: .collect(maxSize: "500mb"), use: upload)

    // Download route
    routes.get("artifacts", ":filename", use: download)
  }

  func upload(req: Request) async throws -> String {
    let file: File

    if let input = try? req.content.decode(UploadInput.self) {
      file = input.file
    } else {
      // Fallback to raw binary upload
      // Check for filename in headers
      let filename: String

      if let xFilename = req.headers["X-Filename"].first {
        filename = xFilename
      } else if let contentDisposition = req.headers["Content-Disposition"].first,
        let range = contentDisposition.range(of: "filename=")
      {
        let value = contentDisposition[range.upperBound...]
          .trimmingCharacters(in: .whitespacesAndNewlines)
          .trimmingCharacters(in: CharacterSet(charactersIn: "\""))

        filename = value
      } else {
        throw Abort(
          .badRequest,
          reason: "File must be provided in 'file' field or via raw binary with X-Filename header"
        )
      }

      guard let body = req.body.data else {
        throw Abort(.badRequest, reason: "File content is missing")
      }

      file = File(data: body, filename: filename)
    }

    // Validate file extension
    guard file.filename.lowercased().hasSuffix(".zip") else {
      throw Abort(.badRequest, reason: "Only .zip files are allowed")
    }

    // Save file
    // Determine artifacts path
    let directory = req.application.directory.workingDirectory
    let artifactsPath: String

    if let config = req.application.storage[ArtifactsConfigKey.self] {
      artifactsPath = config.artifactsPath
    } else {
      artifactsPath = directory + "artifacts/"
    }

    var finalFilename = file.filename
    var filePath = artifactsPath + finalFilename

    // Check for collision and rename if necessary
    if FileManager.default.fileExists(atPath: filePath) {
      let nameWithoutExtension = (file.filename as NSString).deletingPathExtension
      let fileExtension = (file.filename as NSString).pathExtension

      // Append a secure random identifier (6 chars of UUID is usually enough for this context, but full UUID is safer, let's use 6 chars as per plan)
      let randomSuffix = UUID().uuidString.prefix(6)
      finalFilename = "\(nameWithoutExtension)-\(randomSuffix).\(fileExtension)"
      filePath = artifactsPath + finalFilename
    }

    // Ensure artifacts directory exists
    try FileManager.default.createDirectory(
      atPath: artifactsPath, withIntermediateDirectories: true)

    // Write file data
    try await req.fileio.writeFile(file.data, at: filePath)

    // Trigger cleanup if size limit is configured
    if let config = req.application.storage[ArtifactsConfigKey.self],
      let maxSize = config.maxSizeBytes
    {
      let logger = req.logger
      let artifactsURL = URL(fileURLWithPath: artifactsPath)

      Task.detached {
        ArtifactCleaner.clean(
          directory: artifactsURL, maxSize: maxSize, logger: logger)
      }
    }

    // Calculate SHA256 Checksum
    let checksum = SHA256.hash(data: file.data.readableBytesView).hex

    // Generate Public URL
    // Assuming the server is reachable via the Host header, defaulting to localhost:8080 if not present
    let host = req.headers["Host"].first ?? "localhost:8080"
    let scheme =
      req.headers["X-Forwarded-Proto"].first
      ?? (req.application.http.server.configuration.tlsConfiguration == nil ? "http" : "https")
    let url = "\(scheme)://\(host)/artifacts/\(finalFilename)"

    // Extract package name (remove .zip) from original filename to keep package identity
    let packageName = file.filename.replacingOccurrences(of: ".zip", with: "")

    // Generate Package.swift
    let packageManifest = """
      // swift-tools-version: 5.9
      import PackageDescription

      let package = Package(
          name: "\(packageName)",
          products: [
              .library(
                  name: "\(packageName)",
                  targets: ["\(packageName)"]
              ),
          ],
          targets: [
              .binaryTarget(
                  name: "\(packageName)",
                  url: "\(url)",
                  checksum: "\(checksum)"
              )
          ]
      )
      """

    // Calculate remaining space
    let fileManager = FileManager.default
    let resourceKeys: [URLResourceKey] = [.fileSizeKey]

    var totalSize: Int64 = 0

    let artifactsURL = URL(fileURLWithPath: artifactsPath)

    if let files = try? fileManager.contentsOfDirectory(
      at: artifactsURL,
      includingPropertiesForKeys: resourceKeys,
      options: [.skipsHiddenFiles]
    ) {
      for fileURL in files {
        if let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
          let fileSize = resourceValues.fileSize
        {
          totalSize += Int64(fileSize)  // accumulate size
        }
      }
    }

    if let config = req.application.storage[ArtifactsConfigKey.self],
      let maxSizeBytes = config.maxSizeBytes
    {
      let remainingBytes = max(0, Int64(maxSizeBytes) - totalSize)
      let formatter = ByteCountFormatter()

      formatter.allowedUnits = [.useAll]
      formatter.countStyle = .file

      let remainingString = formatter.string(fromByteCount: remainingBytes)

      req.logger.info("Artifact uploaded. Remaining space: \(remainingString)")
    } else {
      req.logger.info("Artifact uploaded. Remaining space: ∞")
    }

    return packageManifest
  }

  func download(req: Request) async throws -> Response {
    guard let filename = req.parameters.get("filename") else {
      throw Abort(.badRequest)
    }

    let directory = req.application.directory.workingDirectory
    let artifactsPath: String

    if let config = req.application.storage[ArtifactsConfigKey.self] {
      artifactsPath = config.artifactsPath
    } else {
      artifactsPath = directory + "artifacts/"
    }

    let filePath = artifactsPath + filename

    guard FileManager.default.fileExists(atPath: filePath) else {
      throw Abort(.notFound)
    }

    return try await req.fileio.asyncStreamFile(at: filePath)
  }
}

struct UploadInput: Content {
  var file: File
}
