import Foundation

// Shared helpers for the deliberately small YAML subset accepted by sand specs.
func parseYAMLKeyValue(_ line: String) -> (String, String)? {
    guard let colon = line.firstIndex(of: ":") else { return nil }
    let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
    let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
    return (key, value)
}

func requireYAMLValue<T, E: Error>(_ value: T?, _ field: String, missingError: (String) -> E) throws -> T {
    guard let value else { throw missingError(field) }
    return value
}
