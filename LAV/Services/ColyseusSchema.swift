import Foundation

// MARK: - Schema Protocol Constants

private let SWITCH_TO_STRUCTURE: UInt8 = 255
private let TYPE_ID_MARKER: UInt8 = 213

// MARK: - Operation Codes

private struct SchemaOp {
    static let REPLACE: UInt8 = 0
    static let CLEAR: UInt8 = 10
    static let REVERSE: UInt8 = 15
    static let DELETE: UInt8 = 64
    static let ADD: UInt8 = 128
    static let ADD_BY_REFID: UInt8 = 129
    static let DELETE_AND_ADD: UInt8 = 192

    static func isAdd(_ op: UInt8) -> Bool { (op & ADD) == ADD }
    static func isDelete(_ op: UInt8) -> Bool { (op & DELETE) == DELETE }
}

// MARK: - Primitive Decoders (Little-Endian)

private enum SchemaDecode {

    static func boolean(_ bytes: Data, _ it: inout Int) -> Bool {
        guard it < bytes.count else { return false }
        let v = bytes[it]; it += 1
        return v > 0
    }

    static func uint8(_ bytes: Data, _ it: inout Int) -> UInt8 {
        guard it < bytes.count else { return 0 }
        let v = bytes[it]; it += 1
        return v
    }

    static func int8(_ bytes: Data, _ it: inout Int) -> Int8 {
        Int8(bitPattern: uint8(bytes, &it))
    }

    static func uint16(_ bytes: Data, _ it: inout Int) -> UInt16 {
        guard it + 2 <= bytes.count else { return 0 }
        let v = UInt16(bytes[it]) | (UInt16(bytes[it + 1]) << 8)
        it += 2; return v
    }

    static func int16(_ bytes: Data, _ it: inout Int) -> Int16 {
        Int16(bitPattern: uint16(bytes, &it))
    }

    static func uint32(_ bytes: Data, _ it: inout Int) -> UInt32 {
        guard it + 4 <= bytes.count else { return 0 }
        let v = UInt32(bytes[it]) | (UInt32(bytes[it + 1]) << 8) |
                UInt32(bytes[it + 2]) << 16 | UInt32(bytes[it + 3]) << 24
        it += 4; return v
    }

    static func int32(_ bytes: Data, _ it: inout Int) -> Int32 {
        Int32(bitPattern: uint32(bytes, &it))
    }

    static func float32(_ bytes: Data, _ it: inout Int) -> Float {
        Float(bitPattern: uint32(bytes, &it))
    }

    static func float64(_ bytes: Data, _ it: inout Int) -> Double {
        guard it + 8 <= bytes.count else { return 0 }
        var v: UInt64 = 0
        for i in 0..<8 { v |= UInt64(bytes[it + i]) << (i * 8) }
        it += 8
        return Double(bitPattern: v)
    }

    // Msgpack-style varint number (used by Schema for "number" type and refIds)
    static func number(_ bytes: Data, _ it: inout Int) -> Int {
        guard it < bytes.count else { return 0 }
        let prefix = bytes[it]

        if prefix < 0x80 { it += 1; return Int(prefix) }

        it += 1
        switch prefix {
        case 0xcc: return Int(uint8(bytes, &it))
        case 0xcd: return Int(uint16(bytes, &it))
        case 0xce: return Int(uint32(bytes, &it))
        case 0xd0: return Int(int8(bytes, &it))
        case 0xd1: return Int(int16(bytes, &it))
        case 0xd2: return Int(int32(bytes, &it))
        case 0xca: return Int(float32(bytes, &it))
        case 0xcb: return Int(float64(bytes, &it))
        default:   return Int(prefix) - 256  // negative fixint
        }
    }

    // Msgpack-style string
    static func string(_ bytes: Data, _ it: inout Int) -> String {
        guard it < bytes.count else { return "" }
        let prefix = bytes[it]; it += 1

        let length: Int
        if prefix < 0xc0 {
            length = Int(prefix & 0x1f)         // fixstr
        } else if prefix == 0xd9 {
            length = Int(uint8(bytes, &it))
        } else if prefix == 0xda {
            length = Int(uint16(bytes, &it))
        } else if prefix == 0xdb {
            length = Int(uint32(bytes, &it))
        } else {
            return ""
        }

        guard it + length <= bytes.count else { return "" }
        let result = String(data: bytes[it..<it + length], encoding: .utf8) ?? ""
        it += length
        return result
    }

    // Decode a primitive by type name
    static func primitive(_ type: String, _ bytes: Data, _ it: inout Int) -> Any? {
        switch type {
        case "string":  return string(bytes, &it)
        case "number":  return number(bytes, &it)
        case "boolean": return boolean(bytes, &it)
        case "int8":    return Int(int8(bytes, &it))
        case "uint8":   return Int(uint8(bytes, &it))
        case "int16":   return Int(int16(bytes, &it))
        case "uint16":  return Int(uint16(bytes, &it))
        case "int32":   return Int(int32(bytes, &it))
        case "uint32":  return Int(uint32(bytes, &it))
        case "float32": return Double(float32(bytes, &it))
        case "float64": return float64(bytes, &it)
        default:        return nil
        }
    }

    static func isPrimitive(_ type: String) -> Bool {
        switch type {
        case "string", "number", "boolean",
             "int8", "uint8", "int16", "uint16",
             "int32", "uint32", "float32", "float64":
            return true
        default:
            return false
        }
    }
}

// MARK: - Schema Type Definitions

struct SchemaFieldDef {
    let index: Int
    let name: String
    let type: String          // primitive type string, or "ref", "map", "array"
    let referencedType: Int   // type ID for ref/map/array, -1 for primitives
    var childPrimitive: String? = nil  // for "array:string", "map:number" etc.
}

struct SchemaTypeDef {
    let typeId: Int
    var fields: [Int: SchemaFieldDef] = [:]
}

// MARK: - Ref Kind

enum RefKind {
    case schema(typeId: Int)
    case map(childTypeId: Int, childPrimitive: String?)
    case array(childTypeId: Int, childPrimitive: String?)
}

// MARK: - Colyseus Schema Decoder

final class ColyseusSchemaDecoder {

    // Type definitions (populated from handshake)
    var types: [Int: SchemaTypeDef] = [:]
    var rootTypeId: Int = 0

    // Reference tracking (using NSMutable* for reference semantics)
    // fileprivate for v2 handshake bootstrap access
    var refs: [Int: AnyObject] = [:]
    var refKinds: [Int: RefKind] = [:]
    var mapIndexToKey: [Int: [Int: String]] = [:]

    // State
    private(set) var isReady = false
    var onStateChange: (([String: Any]) -> Void)?

    // MARK: - Handshake

    func parseHandshake(_ data: Data) {
        print("[Schema] Handshake data: \(data.count) bytes, first 32: \(data.prefix(32).map { String(format: "%02x", $0) }.joined(separator: " "))")

        // Try v2 first (Schema-encoded reflection, used by modern Colyseus 0.15+)
        parseHandshakeV2(data)
        if types.isEmpty {
            print("[Schema] v2 parse produced no types, trying v1 format")
            if parseHandshakeV1(data) {
                print("[Schema] Parsed handshake using v1 format")
            } else {
                print("[Schema] Both v1 and v2 handshake parsing failed!")
            }
        } else {
            print("[Schema] Parsed handshake using v2 format")
        }

        // Initialize root ref for game state
        refs.removeAll()
        refKinds.removeAll()
        mapIndexToKey.removeAll()
        refs[0] = NSMutableDictionary()
        refKinds[0] = .schema(typeId: rootTypeId)

        isReady = true
        print("[Schema] Ready with \(types.count) types, root=\(rootTypeId)")
        for (id, t) in types.sorted(by: { $0.key < $1.key }) {
            let fieldDescs = t.fields.sorted(by: { $0.key < $1.key })
                .map { "\($0.value.name):\($0.value.type)\($0.value.referencedType >= 0 ? "<\($0.value.referencedType)>" : "")" }
            print("[Schema]   Type \(id): \(fieldDescs.joined(separator: ", "))")
        }
    }

    // MARK: - v1 Handshake (simple binary)

    private func parseHandshakeV1(_ data: Data) -> Bool {
        var it = 0
        guard data.count >= 2 else { return false }

        let candidateRootType = Int(data[it]); it += 1
        let numTypes = Int(data[it]); it += 1

        // Sanity check: reasonable number of types
        guard numTypes > 0, numTypes < 50 else { return false }

        var parsedTypes: [Int: SchemaTypeDef] = [:]

        for _ in 0..<numTypes {
            guard it < data.count else { return false }
            let typeId = Int(data[it]); it += 1

            guard it < data.count else { return false }
            let numFields = Int(data[it]); it += 1
            guard numFields < 100 else { return false }

            var typeDef = SchemaTypeDef(typeId: typeId)

            for _ in 0..<numFields {
                guard it < data.count else { return false }
                let fieldIndex = Int(data[it]); it += 1

                // Field name (msgpack string)
                let fieldName = SchemaDecode.string(data, &it)
                guard !fieldName.isEmpty else { return false }

                // Field type (msgpack string)
                let fieldType = SchemaDecode.string(data, &it)
                guard !fieldType.isEmpty else { return false }

                // Referenced type for ref/map/array
                var refType = -1
                if fieldType == "ref" || fieldType == "map" || fieldType == "array" {
                    guard it < data.count else { return false }
                    refType = Int(data[it]); it += 1
                }

                typeDef.fields[fieldIndex] = SchemaFieldDef(
                    index: fieldIndex,
                    name: fieldName,
                    type: fieldType,
                    referencedType: refType
                )
            }
            parsedTypes[typeId] = typeDef
        }

        // Verify we consumed most bytes (allow some slack for padding)
        guard it >= data.count - 10 else {
            print("[Schema] v1 parse only consumed \(it)/\(data.count) bytes")
            return false
        }

        self.types = parsedTypes
        self.rootTypeId = candidateRootType
        return true
    }

    // MARK: - v2 Handshake (Schema-encoded Reflection)

    private func parseHandshakeV2(_ data: Data) {
        // Bootstrap decoder with known Reflection types
        let reflDecoder = ColyseusSchemaDecoder()
        reflDecoder.types = Self.reflectionTypes()
        reflDecoder.rootTypeId = 0
        reflDecoder.refs[0] = NSMutableDictionary()
        reflDecoder.refKinds[0] = .schema(typeId: 0)
        reflDecoder.isReady = true

        reflDecoder.decodeBytes(data)

        // Extract game types from decoded reflection
        guard let root = reflDecoder.refs[0] as? NSMutableDictionary else {
            print("[Schema] v2 reflection root is nil")
            return
        }

        print("[Schema] v2 root keys: \(root.allKeys)")
        print("[Schema] v2 refs count: \(reflDecoder.refs.count)")

        // Extract rootType
        if let rt = root["rootType"] as? Int {
            rootTypeId = rt
            print("[Schema] v2 rootType: \(rt)")
        }

        // Find type definitions — root["types"] is an NSMutableArray of ReflectionType dicts
        var typesArray: [NSDictionary] = []

        // Try root["types"] first (direct reference to the array)
        if let typesRef = root["types"] as? NSMutableArray {
            for item in typesRef {
                if let dict = item as? NSDictionary {
                    typesArray.append(dict)
                }
            }
        }

        // Fallback: scan all refs for arrays containing type-like dicts
        if typesArray.isEmpty {
            for (refId, ref) in reflDecoder.refs {
                if refId == 0 { continue } // skip root
                if let arr = ref as? NSMutableArray {
                    for item in arr {
                        if let dict = item as? NSDictionary, dict["id"] != nil {
                            typesArray.append(dict)
                        }
                    }
                }
            }
        }

        guard !typesArray.isEmpty else {
            print("[Schema] v2 reflection: no types found in \(reflDecoder.refs.count) refs")
            // Dump ref contents for debugging
            for (id, ref) in reflDecoder.refs {
                if let dict = ref as? NSMutableDictionary {
                    print("[Schema]   ref[\(id)] dict keys: \(dict.allKeys)")
                } else if let arr = ref as? NSMutableArray {
                    print("[Schema]   ref[\(id)] array count: \(arr.count)")
                }
            }
            return
        }

        // Convert to SchemaTypeDefs
        for typeDict in typesArray {
            let typeId = (typeDict["id"] as? Int) ?? 0
            var typeDef = SchemaTypeDef(typeId: typeId)

            // Fields can be a direct NSMutableArray (ref) or need lookup
            var fieldsArr: NSMutableArray?
            if let f = typeDict["fields"] as? NSMutableArray {
                fieldsArr = f
            }

            if let fields = fieldsArr {
                for (idx, fieldRaw) in fields.enumerated() {
                    if let fieldDict = fieldRaw as? NSDictionary {
                        let name = fieldDict["name"] as? String ?? ""
                        var type = fieldDict["type"] as? String ?? ""
                        let refType = fieldDict["referencedType"] as? Int ?? -1

                        // Handle "array:string", "map:number" format for primitive collections
                        var childPrimitive: String? = nil
                        if type.contains(":") {
                            let parts = type.split(separator: ":", maxSplits: 1)
                            type = String(parts[0])
                            childPrimitive = String(parts[1])
                        }

                        typeDef.fields[idx] = SchemaFieldDef(
                            index: idx,
                            name: name,
                            type: type,
                            referencedType: refType,
                            childPrimitive: childPrimitive
                        )
                    }
                }
            }
            types[typeId] = typeDef
        }

        print("[Schema] v2 parsed \(types.count) types, rootType=\(rootTypeId)")
    }

    private static func reflectionTypes() -> [Int: SchemaTypeDef] {
        // Must match @colyseus/schema 3.0.75 Reflection.ts exactly:
        //   Reflection:      types(array<ReflectionType>), rootType(number)
        //   ReflectionType:  id(number), extendsId(number), fields(array<ReflectionField>)
        //   ReflectionField: name(string), type(string), referencedType(number)

        // ReflectionField (type 2)
        var reflField = SchemaTypeDef(typeId: 2)
        reflField.fields[0] = SchemaFieldDef(index: 0, name: "name", type: "string", referencedType: -1)
        reflField.fields[1] = SchemaFieldDef(index: 1, name: "type", type: "string", referencedType: -1)
        reflField.fields[2] = SchemaFieldDef(index: 2, name: "referencedType", type: "number", referencedType: -1)

        // ReflectionType (type 1) — has extendsId at index 1, fields at index 2
        var reflType = SchemaTypeDef(typeId: 1)
        reflType.fields[0] = SchemaFieldDef(index: 0, name: "id", type: "number", referencedType: -1)
        reflType.fields[1] = SchemaFieldDef(index: 1, name: "extendsId", type: "number", referencedType: -1)
        reflType.fields[2] = SchemaFieldDef(index: 2, name: "fields", type: "array", referencedType: 2)

        // Root Reflection (type 0)
        var root = SchemaTypeDef(typeId: 0)
        root.fields[0] = SchemaFieldDef(index: 0, name: "types", type: "array", referencedType: 1)
        root.fields[1] = SchemaFieldDef(index: 1, name: "rootType", type: "number", referencedType: -1)

        return [0: root, 1: reflType, 2: reflField]
    }

    // MARK: - State Decoding

    private var decodeLogCount = 0

    func decodeFullState(_ data: Data) {
        // Reset refs (full state replaces everything)
        refs.removeAll()
        refKinds.removeAll()
        mapIndexToKey.removeAll()
        refs[0] = NSMutableDictionary()
        refKinds[0] = .schema(typeId: rootTypeId)

        print("[Schema] decodeFullState: \(data.count) bytes, first 64: \(data.prefix(64).map { String(format: "%02x", $0) }.joined(separator: " "))")
        decodeLogCount = 0
        decodeBytes(data)

        // Log final root dict keys
        if let root = refs[0] as? NSMutableDictionary {
            print("[Schema] Root dict keys after decode: \(root.allKeys)")
            print("[Schema] Total refs after decode: \(refs.count)")
        }
        notifyStateChange()
    }

    private var patchCount = 0
    private var patchSwitchNotFound = 0

    func decodePatch(_ data: Data) {
        patchCount += 1
        // Reset decode logging for first 3 patches so we can see what they contain
        if patchCount <= 3 {
            decodeLogCount = 0
            print("[Schema] === PATCH #\(patchCount): \(data.count) bytes, first 32: \(data.prefix(32).map { String(format: "%02x", $0) }.joined(separator: " "))")
        }
        let refsBefore = refs.count
        patchSwitchNotFound = 0
        // Patches modify existing refs in place
        decodeBytes(data)
        if patchCount <= 10 {
            print("[Schema] Patch #\(patchCount) done: refs \(refsBefore)→\(refs.count), switchOps=\(patchSwitchOps), fieldUpdates=\(patchFieldUpdates), mismatches=\(patchFieldMismatches), switchNotFound=\(patchSwitchNotFound)")
        }
        notifyStateChange()
    }

    private func notifyStateChange() {
        guard let root = refs[0] as? NSMutableDictionary else { return }
        let converted = deepConvert(root)
        // Don't dispatch here — ColyseusRoom.onStateChange handler dispatches to main
        onStateChange?(converted)
    }

    private func deepConvert(_ obj: AnyObject) -> [String: Any] {
        guard let dict = obj as? NSMutableDictionary else { return [:] }
        var result: [String: Any] = [:]
        for (key, value) in dict {
            guard let k = key as? String else { continue }
            if let d = value as? NSMutableDictionary {
                result[k] = deepConvert(d)
            } else if let a = value as? NSMutableArray {
                result[k] = deepConvertArray(a)
            } else {
                result[k] = value
            }
        }
        return result
    }

    private func deepConvertArray(_ arr: NSMutableArray) -> [Any] {
        var result: [Any] = []
        for item in arr {
            if let d = item as? NSMutableDictionary {
                result.append(deepConvert(d))
            } else if let a = item as? NSMutableArray {
                result.append(deepConvertArray(a))
            } else {
                result.append(item)
            }
        }
        return result
    }

    // MARK: - Main Decode Loop

    // Patch statistics
    private var patchSwitchOps = 0
    private var patchFieldUpdates = 0
    private var patchFieldMismatches = 0

    func decodeBytes(_ data: Data) {
        var it = 0
        var currentRefId = 0
        patchSwitchOps = 0
        patchFieldUpdates = 0
        patchFieldMismatches = 0

        while it < data.count {
            let shouldLog = decodeLogCount < 40
            decodeLogCount += 1

            // Check for SWITCH_TO_STRUCTURE
            if data[it] == SWITCH_TO_STRUCTURE {
                it += 1
                let newRefId = SchemaDecode.number(data, &it)

                if refs[newRefId] == nil {
                    patchSwitchNotFound += 1
                    if patchSwitchNotFound <= 5 || patchCount <= 3 {
                        print("[Schema] SWITCH ref \(newRefId) not found, \(refs.count) refs total (patch#\(patchCount))")
                    }
                    skipToNextStructure(data, &it)
                    continue
                }

                patchSwitchOps += 1
                if shouldLog { print("[Schema] SWITCH to ref \(newRefId) (\(refKinds[newRefId].map { "\($0)" } ?? "?"))") }
                currentRefId = newRefId
                continue
            }

            guard let kind = refKinds[currentRefId] else {
                print("[Schema] No kind for ref \(currentRefId)")
                break
            }

            if shouldLog {
                let byte = data[it]
                print("[Schema] @\(it) byte=\(byte)(0x\(String(format: "%02x", byte))) ref=\(currentRefId) kind=\(kind)")
            }

            let prevOffset = it
            switch kind {
            case .schema(let typeId):
                if !decodeSchemaField(data, &it, refId: currentRefId, typeId: typeId) {
                    patchFieldMismatches += 1
                    if shouldLog || patchFieldMismatches <= 3 { print("[Schema]   -> FIELD MISMATCH at ref=\(currentRefId) type=\(typeId), skipping to next structure") }
                    skipToNextStructure(data, &it)
                } else {
                    patchFieldUpdates += 1
                }
            case .map:
                decodeMapOperation(data, &it, refId: currentRefId)
                patchFieldUpdates += 1
            case .array:
                decodeArrayOperation(data, &it, refId: currentRefId)
                patchFieldUpdates += 1
            }

            // Safety: ensure we're making progress
            if it <= prevOffset {
                print("[Schema] Stuck at offset \(it), breaking")
                break
            }
        }
    }

    // MARK: - Schema Field Decode

    @discardableResult
    private func decodeSchemaField(_ bytes: Data, _ it: inout Int, refId: Int, typeId: Int) -> Bool {
        guard it < bytes.count else { return false }
        let firstByte = bytes[it]; it += 1

        // Schema field encoding:
        //   Primitives / REPLACE refs: byte = fieldIndex (0-63)
        //   ADD refs:                  byte = fieldIndex | 0x80  (128-191)
        //   DELETE:                    byte = fieldIndex | 0x40  (64-127)
        //   DELETE_AND_ADD:            byte = fieldIndex | 0xC0  (192-254)
        let operation = firstByte & 0xC0  // Top 2 bits
        let fieldIndex: Int
        if operation == 0 {
            fieldIndex = Int(firstByte)   // No operation flags — full byte is the field index
        } else {
            fieldIndex = Int(firstByte & 0x3F)  // Bottom 6 bits = field index
        }

        guard let typeDef = types[typeId],
              let field = typeDef.fields[fieldIndex] else {
            if decodeLogCount < 40 {
                print("[Schema]   -> field \(fieldIndex) not found in type \(typeId) (op=0x\(String(format: "%02x", operation)), maxField=\(types[typeId]?.fields.keys.max() ?? -1))")
            }
            return false  // DEFINITION_MISMATCH
        }

        if decodeLogCount < 40 {
            print("[Schema]   -> field[\(fieldIndex)]=\(field.name)(\(field.type)) op=0x\(String(format: "%02x", operation))")
        }

        guard let dict = refs[refId] as? NSMutableDictionary else { return false }

        // Pure DELETE — remove the field and return
        if operation == 0x40 { // DELETE but not DELETE_AND_ADD
            dict.removeObject(forKey: field.name)
            return true
        }

        // Decode value based on field type
        if field.type == "ref" {
            let childRefId = SchemaDecode.number(bytes, &it)

            // Check for TYPE_ID marker (polymorphism)
            var childTypeId = field.referencedType
            if it < bytes.count && bytes[it] == TYPE_ID_MARKER {
                it += 1
                childTypeId = SchemaDecode.number(bytes, &it)
            }

            // Always ensure the child ref exists
            if refs[childRefId] == nil {
                refs[childRefId] = NSMutableDictionary()
                refKinds[childRefId] = .schema(typeId: childTypeId)
            }

            if let childRef = refs[childRefId] {
                dict[field.name] = childRef
            }

        } else if field.type == "map" || field.type == "array" {
            let childRefId = SchemaDecode.number(bytes, &it)

            // Always create collection ref if it doesn't exist
            if refs[childRefId] == nil {
                let childType = resolveChildType(field.referencedType)
                // Use field.childPrimitive for "array:string", "map:number" etc.
                let primitive = childType.1 ?? field.childPrimitive

                if field.type == "map" {
                    refs[childRefId] = NSMutableDictionary()
                    refKinds[childRefId] = .map(childTypeId: childType.0, childPrimitive: primitive)
                    mapIndexToKey[childRefId] = [:]
                } else {
                    refs[childRefId] = NSMutableArray()
                    refKinds[childRefId] = .array(childTypeId: childType.0, childPrimitive: primitive)
                }
            }

            dict[field.name] = refs[childRefId]

        } else {
            // Primitive
            if let value = SchemaDecode.primitive(field.type, bytes, &it) {
                dict[field.name] = value
            }
        }

        return true
    }

    // MARK: - Map Decode

    private func decodeMapOperation(_ bytes: Data, _ it: inout Int, refId: Int) {
        guard it < bytes.count else { return }
        let operation = bytes[it]; it += 1

        guard let dict = refs[refId] as? NSMutableDictionary else { return }

        // CLEAR
        if operation == SchemaOp.CLEAR {
            dict.removeAllObjects()
            mapIndexToKey[refId]?.removeAll()
            return
        }

        let index = SchemaDecode.number(bytes, &it)

        // Get child type info
        let (childTypeId, childPrimitive) = mapChildType(refId: refId)

        // For ADD: read the string key
        var dynamicKey: String
        if SchemaOp.isAdd(operation) {
            dynamicKey = SchemaDecode.string(bytes, &it)
            mapIndexToKey[refId, default: [:]][index] = dynamicKey
        } else {
            dynamicKey = mapIndexToKey[refId]?[index] ?? "\(index)"
        }

        // DELETE
        if SchemaOp.isDelete(operation) && !SchemaOp.isAdd(operation) {
            dict.removeObject(forKey: dynamicKey)
            return
        }

        // Decode value
        if let childPrimitive = childPrimitive {
            // Primitive child
            if let value = SchemaDecode.primitive(childPrimitive, bytes, &it) {
                dict[dynamicKey] = value
            }
        } else if childTypeId >= 0 {
            // Schema child
            let childRefId = SchemaDecode.number(bytes, &it)

            // Check for TYPE_ID marker (polymorphism) on ADD operations
            var actualTypeId = childTypeId
            if SchemaOp.isAdd(operation) {
                if it < bytes.count && bytes[it] == TYPE_ID_MARKER {
                    it += 1
                    actualTypeId = SchemaDecode.number(bytes, &it)
                }
            }

            // Create child ref if it doesn't exist (for ADD, REPLACE, or DELETE_AND_ADD)
            if refs[childRefId] == nil {
                refs[childRefId] = NSMutableDictionary()
                refKinds[childRefId] = .schema(typeId: actualTypeId)
            }

            if let childRef = refs[childRefId] {
                dict[dynamicKey] = childRef
            }
        }
    }

    // MARK: - Array Decode

    private func decodeArrayOperation(_ bytes: Data, _ it: inout Int, refId: Int) {
        guard it < bytes.count else { return }
        let operation = bytes[it]; it += 1

        guard let arr = refs[refId] as? NSMutableArray else { return }

        // CLEAR
        if operation == SchemaOp.CLEAR {
            arr.removeAllObjects()
            return
        }

        // REVERSE
        if operation == SchemaOp.REVERSE {
            let reversed = arr.reversed()
            arr.removeAllObjects()
            arr.addObjects(from: reversed as [Any])
            return
        }

        // DELETE_BY_REFID / ADD_BY_REFID
        if operation == 33 { // DELETE_BY_REFID
            let targetRefId = SchemaDecode.number(bytes, &it)
            if let target = refs[targetRefId] {
                let idx = arr.index(of: target)
                if idx != NSNotFound { arr.removeObject(at: idx) }
            }
            return
        }
        if operation == SchemaOp.ADD_BY_REFID {
            let targetRefId = SchemaDecode.number(bytes, &it)
            if let target = refs[targetRefId] {
                arr.add(target)
            }
            return
        }

        let index = SchemaDecode.number(bytes, &it)

        let (childTypeId, childPrimitive) = arrayChildType(refId: refId)

        // DELETE
        if SchemaOp.isDelete(operation) && !SchemaOp.isAdd(operation) {
            if index < arr.count { arr.removeObject(at: index) }
            return
        }

        // Decode value
        var value: Any?

        if let childPrimitive = childPrimitive {
            value = SchemaDecode.primitive(childPrimitive, bytes, &it)
        } else if childTypeId >= 0 {
            let childRefId = SchemaDecode.number(bytes, &it)

            // Check for TYPE_ID marker on ADD operations
            var actualTypeId = childTypeId
            if SchemaOp.isAdd(operation) {
                if it < bytes.count && bytes[it] == TYPE_ID_MARKER {
                    it += 1
                    actualTypeId = SchemaDecode.number(bytes, &it)
                }
            }

            // Always create child ref if it doesn't exist
            if refs[childRefId] == nil {
                refs[childRefId] = NSMutableDictionary()
                refKinds[childRefId] = .schema(typeId: actualTypeId)
            }

            value = refs[childRefId]
        }

        guard let val = value else { return }

        // Insert/replace
        if SchemaOp.isAdd(operation) && !SchemaOp.isDelete(operation) {
            // Pure ADD
            if index >= arr.count {
                // Extend array
                while arr.count < index { arr.add(NSNull()) }
                arr.add(val)
            } else {
                arr.insert(val, at: index)
            }
        } else {
            // REPLACE or DELETE_AND_ADD
            if index < arr.count {
                arr.replaceObject(at: index, with: val)
            } else {
                while arr.count < index { arr.add(NSNull()) }
                arr.add(val)
            }
        }
    }

    // MARK: - Helpers

    /// Map/array children can reference a Schema type (by type ID) or be a primitive.
    /// The handshake stores referencedType as a type ID for schemas, or -1/255 for primitives.
    /// When the type ID doesn't exist in our types dict, it may be a primitive that was
    /// stored as the raw "type" string on the parent field (handled at field level).
    private func resolveChildType(_ referencedType: Int) -> (Int, String?) {
        if referencedType >= 0, types[referencedType] != nil {
            return (referencedType, nil)
        }
        // Not a known schema type — treat as primitive.
        // The actual primitive type name is determined from the field definition's type string.
        // For maps/arrays of primitives, Colyseus encodes the child type as "string", "number", etc.
        // in the field's type field itself (e.g., type="map" with child being primitive).
        // We return nil here and let the caller check.
        return (-1, nil)
    }

    private func mapChildType(refId: Int) -> (Int, String?) {
        guard let kind = refKinds[refId] else { return (-1, nil) }
        switch kind {
        case .map(let childTypeId, let childPrimitive):
            return (childTypeId, childPrimitive)
        default:
            return (-1, nil)
        }
    }

    private func arrayChildType(refId: Int) -> (Int, String?) {
        guard let kind = refKinds[refId] else { return (-1, nil) }
        switch kind {
        case .array(let childTypeId, let childPrimitive):
            return (childTypeId, childPrimitive)
        default:
            return (-1, nil)
        }
    }

    private func skipToNextStructure(_ bytes: Data, _ it: inout Int) {
        // Skip forward until we find a SWITCH_TO_STRUCTURE marker.
        // Note: 0xFF can appear as data bytes (e.g., inside numbers/strings),
        // so we verify by checking if the next byte after 0xFF could be a valid refId.
        while it < bytes.count {
            if bytes[it] == SWITCH_TO_STRUCTURE && it + 1 < bytes.count {
                // Peek: next bytes should decode to a small refId (< 256 typically)
                let nextByte = bytes[it + 1]
                if nextByte < 128 { // Positive fixint = likely a valid refId
                    return
                }
            }
            it += 1
        }
    }
}
