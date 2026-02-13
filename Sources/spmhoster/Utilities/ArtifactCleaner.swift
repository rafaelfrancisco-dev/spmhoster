import Foundation
import Vapor

struct ArtifactCleaner {
  static func clean(directory: URL, maxSize: Int, logger: Logger) {
    do {
      logger.info("Checking artifact directory size limit: \(maxSize) bytes")

      let fileManager = FileManager.default
      let resourceKeys: [URLResourceKey] = [.fileSizeKey, .creationDateKey, .isDirectoryKey]

      guard
        let enumerator = fileManager.enumerator(
          at: directory, includingPropertiesForKeys: resourceKeys)
      else {
        logger.warning("Could not enumerate artifacts directory")
        return
      }

      var files: [(url: URL, size: Int, date: Date)] = []
      var totalSize = 0

      for case let fileURL as URL in enumerator {
        let resources = try fileURL.resourceValues(forKeys: Set(resourceKeys))
        if resources.isDirectory == true { continue }

        if let size = resources.fileSize, let date = resources.creationDate {
          files.append((url: fileURL, size: size, date: date))
          totalSize += size
        }
      }

      logger.info("Current artifacts size: \(totalSize) bytes")

      if totalSize <= maxSize {
        logger.info("Artifacts size is within limit.")
        return
      }

      // Sort by creation date (oldest first)
      files.sort { $0.date < $1.date }

      var currentSize = totalSize
      for file in files {
        if currentSize <= maxSize {
          break
        }

        do {
          try fileManager.removeItem(at: file.url)
          currentSize -= file.size
          logger.info(
            "Deleted artifact to free space: \(file.url.lastPathComponent) (\(file.size) bytes)")
        } catch {
          logger.error("Failed to delete artifact: \(file.url.lastPathComponent). Error: \(error)")
        }
      }

      logger.info("Cleanup complete. New size: \(currentSize) bytes")

    } catch {
      logger.error("Error during artifact cleanup: \(error)")
    }
  }
}
