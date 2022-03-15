//
//  ASN1Encoder.swift
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

internal class ASN1DEREncoder {
    
    static func encodeSequence(content: Data) -> Data {
        var encoded = Data()
        encoded.append(ASN1Identifier.constructedTag | ASN1Identifier.TagNumber.sequence.rawValue)
        encoded.append(contentLength(of: content.count))
        encoded.append(content)
        return encoded
    }
 
    private static func contentLength(of size: Int) -> Data {
        if size >= 128 {
            var lenBytes = byteArray(from: size)
            while lenBytes.first == 0 { lenBytes.removeFirst() }
            let len: UInt8 = 0x80 | UInt8(lenBytes.count)
            return Data([len] + lenBytes)
        } else {
            return Data([UInt8(size)])
        }
    }
    
    private static func byteArray<T>(from value: T) -> [UInt8] where T: FixedWidthInteger {
        return withUnsafeBytes(of: value.bigEndian, Array.init)
    }
    
}

extension Data {
    var derEncodedSequence: Data {
        return ASN1DEREncoder.encodeSequence(content: self)
    }
}
