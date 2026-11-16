import Foundation

/// A small JSON tree for request bodies whose keys are already in server (snake_case) form.
enum JSONValue: Encodable, Sendable {
    case string(String)
    case int(Int)
    case bool(Bool)
    case array([JSONValue])
    case null

    static func uuid(_ value: UUID) -> JSONValue {
        .string(value.lower)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

extension UUID {
    /// Postgres prints UUIDs in lowercase, and storage paths are compared as text.
    var lower: String { uuidString.lowercased() }
}

func q(_ name: String, _ value: String) -> URLQueryItem {
    URLQueryItem(name: name, value: value)
}

extension Error {
    /// Text that is safe to show to the person using the app.
    var userMessage: String {
        if let localized = self as? LocalizedError, let text = localized.errorDescription {
            return text
        }
        return "出错了，请稍后再试"
    }
}
