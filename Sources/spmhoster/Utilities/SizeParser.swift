import Foundation

struct SizeParser {
  static func parse(_ input: String) -> Int? {
    let input = input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

    // Find the numeric part and the unit part
    let scanner = Scanner(string: input)
    guard let value = scanner.scanDouble() else {
      return nil
    }

    let unit = input.replacingOccurrences(of: String(format: "%g", value), with: "")
      .trimmingCharacters(in: .whitespaces)

    let multipiler: Double
    switch unit {
    case "KB", "K":
      multipiler = 1024
    case "MB", "M":
      multipiler = 1024 * 1024
    case "GB", "G":
      multipiler = 1024 * 1024 * 1024
    case "TB", "T":
      multipiler = 1024 * 1024 * 1024 * 1024
    case "":  // Bytes
      multipiler = 1
    default:
      return nil
    }

    return Int(value * multipiler)
  }
}
