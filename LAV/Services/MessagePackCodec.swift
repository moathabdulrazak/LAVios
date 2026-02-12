import Foundation

// MARK: - Minimal MessagePack Encoder/Decoder
// Handles the subset needed for Colyseus protocol communication.

enum MessagePack {

    // MARK: - Encode

    static func encode(_ value: Any?) -> Data {
        var data = Data()
        encodeValue(value, into: &data)
        return data
    }

    private static func encodeValue(_ value: Any?, into data: inout Data) {
        guard let value = value else {
            data.append(0xc0) // nil
            return
        }

        switch value {
        case let b as Bool:
            data.append(b ? 0xc3 : 0xc2)

        case let i as Int:
            encodeInt(i, into: &data)

        case let i as Int8:
            encodeInt(Int(i), into: &data)

        case let i as Int16:
            encodeInt(Int(i), into: &data)

        case let i as Int32:
            encodeInt(Int(i), into: &data)

        case let i as Int64:
            encodeInt(Int(i), into: &data)

        case let u as UInt:
            encodeUInt(UInt64(u), into: &data)

        case let u as UInt8:
            encodeUInt(UInt64(u), into: &data)

        case let u as UInt16:
            encodeUInt(UInt64(u), into: &data)

        case let u as UInt32:
            encodeUInt(UInt64(u), into: &data)

        case let u as UInt64:
            encodeUInt(u, into: &data)

        case let f as Float:
            data.append(0xca)
            var bits = f.bitPattern.bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &bits) { Array($0) })

        case let d as Double:
            data.append(0xcb)
            var bits = d.bitPattern.bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &bits) { Array($0) })

        case let s as String:
            encodeString(s, into: &data)

        case let d as Data:
            encodeBinary(d, into: &data)

        case let arr as [Any]:
            encodeArray(arr, into: &data)

        case let arr as [Any?]:
            encodeArray(arr, into: &data)

        case let dict as [String: Any]:
            encodeMap(dict, into: &data)

        case let dict as [String: Any?]:
            encodeMap(dict, into: &data)

        case let n as NSNumber:
            // Handle NSNumber edge cases (JSON deserialization can produce these)
            if CFBooleanGetTypeID() == CFGetTypeID(n) {
                data.append(n.boolValue ? 0xc3 : 0xc2)
            } else {
                encodeInt(n.intValue, into: &data)
            }

        default:
            data.append(0xc0) // Unknown types -> nil
        }
    }

    private static func encodeInt(_ i: Int, into data: inout Data) {
        if i >= 0 {
            encodeUInt(UInt64(i), into: &data)
        } else if i >= -32 {
            data.append(UInt8(bitPattern: Int8(i))) // negative fixint
        } else if i >= Int(Int8.min) {
            data.append(0xd0)
            data.append(UInt8(bitPattern: Int8(i)))
        } else if i >= Int(Int16.min) {
            data.append(0xd1)
            var v = Int16(i).bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &v) { Array($0) })
        } else if i >= Int(Int32.min) {
            data.append(0xd2)
            var v = Int32(i).bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &v) { Array($0) })
        } else {
            data.append(0xd3)
            var v = Int64(i).bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &v) { Array($0) })
        }
    }

    private static func encodeUInt(_ u: UInt64, into data: inout Data) {
        if u <= 0x7f {
            data.append(UInt8(u)) // positive fixint
        } else if u <= UInt64(UInt8.max) {
            data.append(0xcc)
            data.append(UInt8(u))
        } else if u <= UInt64(UInt16.max) {
            data.append(0xcd)
            var v = UInt16(u).bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &v) { Array($0) })
        } else if u <= UInt64(UInt32.max) {
            data.append(0xce)
            var v = UInt32(u).bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &v) { Array($0) })
        } else {
            data.append(0xcf)
            var v = u.bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &v) { Array($0) })
        }
    }

    private static func encodeString(_ s: String, into data: inout Data) {
        let utf8 = Array(s.utf8)
        let len = utf8.count
        if len <= 31 {
            data.append(0xa0 | UInt8(len)) // fixstr
        } else if len <= Int(UInt8.max) {
            data.append(0xd9)
            data.append(UInt8(len))
        } else if len <= Int(UInt16.max) {
            data.append(0xda)
            var v = UInt16(len).bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &v) { Array($0) })
        } else {
            data.append(0xdb)
            var v = UInt32(len).bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &v) { Array($0) })
        }
        data.append(contentsOf: utf8)
    }

    private static func encodeBinary(_ bin: Data, into data: inout Data) {
        let len = bin.count
        if len <= Int(UInt8.max) {
            data.append(0xc4)
            data.append(UInt8(len))
        } else if len <= Int(UInt16.max) {
            data.append(0xc5)
            var v = UInt16(len).bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &v) { Array($0) })
        } else {
            data.append(0xc6)
            var v = UInt32(len).bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &v) { Array($0) })
        }
        data.append(bin)
    }

    private static func encodeArray(_ arr: [Any?], into data: inout Data) {
        let count = arr.count
        if count <= 15 {
            data.append(0x90 | UInt8(count)) // fixarray
        } else if count <= Int(UInt16.max) {
            data.append(0xdc)
            var v = UInt16(count).bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &v) { Array($0) })
        } else {
            data.append(0xdd)
            var v = UInt32(count).bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &v) { Array($0) })
        }
        for item in arr {
            encodeValue(item, into: &data)
        }
    }

    private static func encodeMap(_ dict: [String: Any?], into data: inout Data) {
        let count = dict.count
        if count <= 15 {
            data.append(0x80 | UInt8(count)) // fixmap
        } else if count <= Int(UInt16.max) {
            data.append(0xde)
            var v = UInt16(count).bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &v) { Array($0) })
        } else {
            data.append(0xdf)
            var v = UInt32(count).bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &v) { Array($0) })
        }
        for (key, val) in dict {
            encodeString(key, into: &data)
            encodeValue(val, into: &data)
        }
    }

    // MARK: - Decode

    static func decode(_ data: Data) -> Any? {
        var offset = 0
        return decodeValue(data, offset: &offset)
    }

    /// Decode a single value starting at the given offset, advancing offset past the decoded value.
    static func decode(_ data: Data, offset: inout Int) -> Any? {
        return decodeValue(data, offset: &offset)
    }

    private static func decodeValue(_ data: Data, offset: inout Int) -> Any? {
        guard offset < data.count else { return nil }
        let byte = data[offset]
        offset += 1

        // Positive fixint (0x00 - 0x7f)
        if byte <= 0x7f {
            return Int(byte)
        }

        // Negative fixint (0xe0 - 0xff)
        if byte >= 0xe0 {
            return Int(Int8(bitPattern: byte))
        }

        // Fixmap (0x80 - 0x8f)
        if byte >= 0x80 && byte <= 0x8f {
            return decodeMap(data, count: Int(byte & 0x0f), offset: &offset)
        }

        // Fixarray (0x90 - 0x9f)
        if byte >= 0x90 && byte <= 0x9f {
            return decodeArray(data, count: Int(byte & 0x0f), offset: &offset)
        }

        // Fixstr (0xa0 - 0xbf)
        if byte >= 0xa0 && byte <= 0xbf {
            return decodeString(data, length: Int(byte & 0x1f), offset: &offset)
        }

        switch byte {
        case 0xc0: return nil                               // nil
        case 0xc2: return false                             // false
        case 0xc3: return true                              // true

        // Binary
        case 0xc4:
            let len = Int(readUInt8(data, offset: &offset))
            return readData(data, length: len, offset: &offset)
        case 0xc5:
            let len = Int(readUInt16(data, offset: &offset))
            return readData(data, length: len, offset: &offset)
        case 0xc6:
            let len = Int(readUInt32(data, offset: &offset))
            return readData(data, length: len, offset: &offset)

        // Float
        case 0xca:
            let bits = readUInt32(data, offset: &offset)
            return Double(Float(bitPattern: bits))
        case 0xcb:
            let bits = readUInt64(data, offset: &offset)
            return Double(bitPattern: bits)

        // Unsigned int
        case 0xcc: return Int(readUInt8(data, offset: &offset))
        case 0xcd: return Int(readUInt16(data, offset: &offset))
        case 0xce: return Int(readUInt32(data, offset: &offset))
        case 0xcf:
            let v = readUInt64(data, offset: &offset)
            return v <= UInt64(Int.max) ? Int(v) : Double(v)

        // Signed int
        case 0xd0: return Int(Int8(bitPattern: readUInt8(data, offset: &offset)))
        case 0xd1: return Int(Int16(bitPattern: readUInt16(data, offset: &offset)))
        case 0xd2: return Int(Int32(bitPattern: readUInt32(data, offset: &offset)))
        case 0xd3:
            let v = Int64(bitPattern: readUInt64(data, offset: &offset))
            return Int(v)

        // String
        case 0xd9:
            let len = Int(readUInt8(data, offset: &offset))
            return decodeString(data, length: len, offset: &offset)
        case 0xda:
            let len = Int(readUInt16(data, offset: &offset))
            return decodeString(data, length: len, offset: &offset)
        case 0xdb:
            let len = Int(readUInt32(data, offset: &offset))
            return decodeString(data, length: len, offset: &offset)

        // Array
        case 0xdc:
            let count = Int(readUInt16(data, offset: &offset))
            return decodeArray(data, count: count, offset: &offset)
        case 0xdd:
            let count = Int(readUInt32(data, offset: &offset))
            return decodeArray(data, count: count, offset: &offset)

        // Map
        case 0xde:
            let count = Int(readUInt16(data, offset: &offset))
            return decodeMap(data, count: count, offset: &offset)
        case 0xdf:
            let count = Int(readUInt32(data, offset: &offset))
            return decodeMap(data, count: count, offset: &offset)

        default:
            return nil
        }
    }

    // MARK: - Decode Helpers

    private static func readUInt8(_ data: Data, offset: inout Int) -> UInt8 {
        guard offset < data.count else { return 0 }
        let v = data[offset]
        offset += 1
        return v
    }

    private static func readUInt16(_ data: Data, offset: inout Int) -> UInt16 {
        guard offset + 2 <= data.count else { return 0 }
        let v = UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
        offset += 2
        return v
    }

    private static func readUInt32(_ data: Data, offset: inout Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        let v = UInt32(data[offset]) << 24 | UInt32(data[offset + 1]) << 16 |
                UInt32(data[offset + 2]) << 8 | UInt32(data[offset + 3])
        offset += 4
        return v
    }

    private static func readUInt64(_ data: Data, offset: inout Int) -> UInt64 {
        guard offset + 8 <= data.count else { return 0 }
        var v: UInt64 = 0
        for i in 0..<8 {
            v = v << 8 | UInt64(data[offset + i])
        }
        offset += 8
        return v
    }

    private static func readData(_ data: Data, length: Int, offset: inout Int) -> Data {
        guard offset + length <= data.count else { return Data() }
        let result = data[offset..<offset + length]
        offset += length
        return Data(result)
    }

    private static func decodeString(_ data: Data, length: Int, offset: inout Int) -> String {
        guard offset + length <= data.count else { return "" }
        let strData = data[offset..<offset + length]
        offset += length
        return String(data: Data(strData), encoding: .utf8) ?? ""
    }

    private static func decodeArray(_ data: Data, count: Int, offset: inout Int) -> [Any] {
        var arr = [Any]()
        arr.reserveCapacity(count)
        for _ in 0..<count {
            if let val = decodeValue(data, offset: &offset) {
                arr.append(val)
            } else {
                arr.append(NSNull())
            }
        }
        return arr
    }

    private static func decodeMap(_ data: Data, count: Int, offset: inout Int) -> [String: Any] {
        var dict = [String: Any]()
        dict.reserveCapacity(count)
        for _ in 0..<count {
            let key: String
            if let k = decodeValue(data, offset: &offset) {
                key = k as? String ?? "\(k)"
            } else {
                key = ""
            }
            let val = decodeValue(data, offset: &offset) ?? NSNull()
            dict[key] = val
        }
        return dict
    }
}
