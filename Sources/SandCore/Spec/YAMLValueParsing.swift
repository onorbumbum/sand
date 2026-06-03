import Foundation

// Shared helpers for the deliberately small YAML subset accepted by sand specs.
func parseYAMLKeyValue(_ line: String) -> (String, String)? {
    guard let colon = line.firstIndex(of: ":") else { return nil }
    let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
    let value = parseYAMLScalar(String(line[line.index(after: colon)...]))
    return (key, value)
}

func parseYAMLScalar(_ rawValue: String) -> String {
    let value = rawValue.trimmingCharacters(in: .whitespaces)
    guard value.count >= 2 else { return value }
    if value.hasPrefix("'") && value.hasSuffix("'") {
        return String(value.dropFirst().dropLast()).replacingOccurrences(of: "''", with: "'")
    }
    if value.hasPrefix("\"") && value.hasSuffix("\"") {
        return String(value.dropFirst().dropLast())
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }
    return value
}

func requireYAMLValue<T, E: Error>(_ value: T?, _ field: String, missingError: (String) -> E) throws -> T {
    guard let value else { throw missingError(field) }
    return value
}
