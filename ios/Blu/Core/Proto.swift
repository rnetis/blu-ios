import Foundation

/// Minimal protobuf wire-format codec.
///
/// The Blu gateway speaks protobuf with no descriptor available to the client, so requests are
/// encoded field-by-field from the extracted schema (see docs/SCHEMA.md) and responses are parsed
/// into a tag-indexed tree that the model layer reads by field number.
enum PB {
    static func key(_ field: Int, _ wire: UInt64) -> Data { varint(UInt64(field) << 3 | wire) }

    static func varint(_ value: UInt64) -> Data {
        var v = value
        var out = Data()
        repeat {
            var byte = UInt8(v & 0x7F)
            v >>= 7
            if v != 0 { byte |= 0x80 }
            out.append(byte)
        } while v != 0
        return out
    }

    static func int(_ field: Int, _ value: UInt64) -> Data { key(field, 0) + varint(value) }
    static func int(_ field: Int, _ value: Int) -> Data { int(field, UInt64(value)) }
    static func bool(_ field: Int, _ value: Bool) -> Data { int(field, value ? 1 : 0) }

    static func bytes(_ field: Int, _ value: Data) -> Data {
        key(field, 2) + varint(UInt64(value.count)) + value
    }

    static func string(_ field: Int, _ value: String) -> Data {
        bytes(field, Data(value.utf8))
    }

    static func message(_ field: Int, _ value: Data) -> Data { bytes(field, value) }
}

/// Parsed protobuf message: field number -> ordered values.
struct PBMessage {
    enum Value {
        case varint(UInt64)
        case bytes(Data)
        case message(PBMessage)
    }

    private(set) var fields: [Int: [Value]] = [:]
    /// The exact bytes this message was parsed from — re-encoding a parsed tree is not byte-stable,
    /// so this is what callers get back for `bytes`-typed fields.
    private(set) var source = Data()

    init?(data: Data, depth: Int = 0) {
        guard depth <= 6 else { return nil }
        source = data
        var index = data.startIndex
        while index < data.endIndex {
            guard let (key, afterKey) = PBMessage.readVarint(data, index) else { return nil }
            let field = Int(key >> 3)
            let wire = key & 7
            guard field > 0 else { return nil }
            index = afterKey

            switch wire {
            case 0:
                guard let (value, next) = PBMessage.readVarint(data, index) else { return nil }
                fields[field, default: []].append(.varint(value))
                index = next
            case 1:
                guard index + 8 <= data.endIndex else { return nil }
                fields[field, default: []].append(.bytes(Data(data[index..<(index + 8)])))
                index += 8
            case 5:
                guard index + 4 <= data.endIndex else { return nil }
                fields[field, default: []].append(.bytes(Data(data[index..<(index + 4)])))
                index += 4
            case 2:
                guard let (length, afterLength) = PBMessage.readVarint(data, index) else { return nil }
                let count = Int(length)
                guard count >= 0, afterLength + count <= data.endIndex else { return nil }
                let end = afterLength + count
                let slice = Data(data[afterLength..<end])
                if let nested = PBMessage(data: slice, depth: depth + 1) {
                    fields[field, default: []].append(.message(nested))
                } else {
                    fields[field, default: []].append(.bytes(slice))
                }
                index = end
            default:
                return nil
            }
        }
    }

    private static func readVarint(_ data: Data, _ start: Data.Index) -> (UInt64, Data.Index)? {
        var value: UInt64 = 0
        var shift: UInt64 = 0
        var index = start
        while index < data.endIndex {
            let byte = data[index]
            value |= UInt64(byte & 0x7F) << shift
            index = data.index(after: index)
            if byte & 0x80 == 0 { return (value, index) }
            shift += 7
            if shift > 63 { return nil }
        }
        return nil
    }

    // MARK: - accessors

    func all(_ tag: Int) -> [Value] { fields[tag] ?? [] }
    func value(_ tag: Int) -> Value? { all(tag).first }

    func int(_ tag: Int) -> UInt64? {
        if case .varint(let v) = value(tag) { return v }
        return nil
    }

    func bool(_ tag: Int) -> Bool? { int(tag).map { $0 != 0 } }

    func data(_ tag: Int) -> Data? {
        switch value(tag) {
        case .bytes(let d):   return d
        case .message(let m): return m.source
        default:              return nil
        }
    }

    func message(_ tag: Int) -> PBMessage? {
        if case .message(let m) = value(tag) { return m }
        return nil
    }

    func messages(_ tag: Int) -> [PBMessage] {
        all(tag).compactMap { item in
            if case .message(let m) = item { return m }
            return nil
        }
    }

    func string(_ tag: Int) -> String? {
        guard let d = data(tag), !d.isEmpty else { return nil }
        return String(data: d, encoding: .utf8)
    }

    func strings(_ tag: Int) -> [String] {
        all(tag).compactMap { item in
            guard case .bytes(let d) = item else { return nil }
            return String(data: d, encoding: .utf8)
        }
    }

    /// Depth-first lookup of a descendant field — the API decorates nearly every message with a
    /// human-readable Persian `localizedDescription` at tag 15, and its exact nesting depth varies.
    func descendantString(_ tag: Int, maxDepth: Int = 5) -> String? {
        if let s = string(tag), !s.isEmpty { return s }
        guard maxDepth > 0 else { return nil }
        for values in fields.values {
            for case let .message(nested) in values {
                if let found = nested.descendantString(tag, maxDepth: maxDepth - 1) { return found }
            }
        }
        return nil
    }

    /// The nearest Persian human-readable label anywhere in this subtree.
    var localizedLabel: String? { descendantString(15) }

    /// Every descendant value of a tag, in depth-first order.
    func descendantStrings(_ tag: Int, maxDepth: Int = 6) -> [String] {
        var out: [String] = []
        if let s = string(tag), !s.isEmpty { out.append(s) }
        guard maxDepth > 0 else { return out }
        for values in fields.values {
            for case let .message(nested) in values {
                out += nested.descendantStrings(tag, maxDepth: maxDepth - 1)
            }
        }
        return out
    }

    var rawBytes: Data { source }
}
