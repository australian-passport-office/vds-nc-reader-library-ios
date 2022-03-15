//
//  JsonCanonicalizer.swift
//  VDSNCChecker
//
//  Copyright (c) 2021, Commonwealth of Australia. vds.support@dfat.gov.au
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not
//  use this file except in compliance with the License. You may obtain a copy
//  of the License at:
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
//  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
//  License for the specific language governing permissions and limitations
//  under the License.

import Foundation


internal class JsonCanonicalizer {
    
    /*
     - Serialization of primitive JSON data types
     - Lexicographic sorting of JSON Object properties in a recursive process
     - JSON Array data is also subject to canonicalization, but element order remains untouched
     */
    
    public static func canonicalize(json: String) throws -> Data {
        
        guard let jsonObj = try? JSONSerialization.jsonObject(with: Data(json.utf8), options: []) else {
            throw JsonCanonicalizerError.invalidJson
        }
        
        return try canonicalize(withJSONObject: jsonObj)
    }
    
    public static func canonicalize(withJSONObject value: Any) throws -> Data {

        return try canonicalizedData(withJSONObject: value)
    }
    
    
    private static var _backslash   = "\\";
    
    internal class func canonicalizedData(withJSONObject value: Any) throws -> Data {
        var jsonStr = [UInt8]()
        
        var writer = JSONWriter(
            writer: { (str: String?) in
                if let str = str {
                    jsonStr.append(contentsOf: str.utf8)
                }
            }
        )
        
        if let container = value as? Array<Any> {
            try writer.serializeJSON(container)
        } else if let container = value as? Dictionary<AnyHashable, Any> {
            try writer.serializeJSON(container)
        } else {
            fatalError("Top-level object was not Array or Dictionary")
        }
        
        let count = jsonStr.count
        return Data(bytes: &jsonStr, count: count)
    }
}

//MARK: - Writer

private struct JSONWriter {
    
    let writer: (String?) -> Void
    
    init(writer: @escaping (String?) -> Void) {
        self.writer = writer
    }
    
    mutating func serializeJSON(_ object: Any?) throws {
        
        let toSerialize = object
        
        guard let obj = toSerialize else {
            try serializeNull()
            return
        }
        
        switch (obj) {
        case let str as String:
            try serializeString(str)
        case let boolValue as Bool:
            // check if its an bool by casting to NSNumber
            // NSNumber is toll-free bridged to CFBoolean for Booleans, and CFNumber for most other things
            if let checkNum = obj as? NSNumber {
                if CFGetTypeID(checkNum) == CFBooleanGetTypeID() {
                    serializeBool(boolValue)
                } else {
                    writer(checkNum.description)
                }
            } else {
                serializeBool(boolValue)
            }
        case let num as Int:
            writer(num.description)
        case let num as Int8:
            writer(num.description)
        case let num as Int16:
            writer(num.description)
        case let num as Int32:
            writer(num.description)
        case let num as Int64:
            writer(num.description)
        case let num as UInt:
            writer(num.description)
        case let num as UInt8:
            writer(num.description)
        case let num as UInt16:
            writer(num.description)
        case let num as UInt32:
            writer(num.description)
        case let num as UInt64:
            writer(num.description)
        case let array as Array<Any?>:
            try serializeArray(array)
        case let dict as Dictionary<AnyHashable, Any?>:
            try serializeDictionary(dict)
        case let num as Float:
            try serializeFloat(num)
        case let num as Double:
            try serializeFloat(num)
        case let num as Decimal:
            writer(num.description)
        case let num as NSDecimalNumber:
            writer(num.description)
            
        case is NSNull:
            try serializeNull()
        default:
            throw JsonCanonicalizerError.invalidObject
        }
    }
    
    func serializeBool(_ bool: Bool) {
        writer(bool.description)
    }
    
    func serializeString(_ str: String) throws {
        writer("\"")
        for scalar in str.unicodeScalars {
            switch scalar {
            case "\"":
                writer("\\\"") // U+0022 quotation mark
            case "\\":
                writer("\\\\") // U+005C reverse solidus
            case "/":
                writer("\\") // U+002F solidus
            case "\u{8}":
                writer("\\b") // U+0008 backspace
            case "\u{c}":
                writer("\\f") // U+000C form feed
            case "\n":
                writer("\\n") // U+000A line feed
            case "\r":
                writer("\\r") // U+000D carriage return
            case "\t":
                writer("\\t") // U+0009 tab
            case "\u{0}"..."\u{f}":
                writer("\\u000\(String(scalar.value, radix: 16))") // U+0000 to U+000F
            case "\u{10}"..."\u{1f}":
                writer("\\u00\(String(scalar.value, radix: 16))") // U+0010 to U+001F
            default:
                writer(String(scalar))
            }
        }
        writer("\"")
    }
    
    private func serializeFloat<T: FloatingPoint & LosslessStringConvertible>(_ num: T) throws {
        
        guard num.isFinite else {
            throw JsonCanonicalizerError.invalidNuberInWrite
        }
        var str = num.description
        if str.hasSuffix(".0") {
            str.removeLast(2)
        }
        if !num.isCanonical {
            print("non canonical found: " + str)
        }
        writer(str)
    }
    
    mutating func serializeArray(_ array: [Any?]) throws {
        writer("[")
        
        var first = true
        for elem in array {
            if first {
                first = false
            } else {
                writer(",")
            }
            
            try serializeJSON(elem)
        }
        
        writer("]")
    }
    
    mutating func serializeDictionary(_ dict: Dictionary<AnyHashable, Any?>) throws {
        writer("{")
        
        var first = true
        
        func serializeDictionaryElement(key: AnyHashable, value: Any?) throws {
            if first {
                first = false
            } else {
                writer(",")
            }
            
            if let key = key as? String {
                try serializeString(key)
            } else {
                throw JsonCanonicalizerError.keyMustBeString
            }
            writer(":")
            try serializeJSON(value)
        }
        
        let elems = try dict.sorted(by: { a, b in
            guard let a = a.key as? String,
                  let b = b.key as? String else {
                      throw JsonCanonicalizerError.keyMustBeString
                  }
            
            let options: NSString.CompareOptions = [.diacriticInsensitive, .caseInsensitive, .forcedOrdering]
            let range: Range<String.Index>  = a.startIndex..<a.endIndex
            
            return a.compare(b, options: options, range: range) == .orderedAscending
        })
        for elem in elems {
            try serializeDictionaryElement(key: elem.key, value: elem.value)
        }
        
        
        writer("}")
    }
    
    func serializeNull() throws {
        writer("null")
    }
}

internal enum JsonCanonicalizerError: Error {
    case keyMustBeString
    case invalidNuberInWrite
    case invalidObject
    case invalidJson
}
