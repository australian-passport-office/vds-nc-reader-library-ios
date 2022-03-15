//
//  ASN1Object.swift
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

internal class ASN1Object: CustomStringConvertible {
    
    /// This property contains the DER encoded object
    var rawValue: Data?

    /// This property contains the DER encoded object, including the initial identifier and content length bytes
    var fullRawValue: Data?

    /// This property contains the decoded Swift object whenever is possible
    var value: Any?

    var identifier: ASN1Identifier?

    var sub: [ASN1Object]?

    weak var parent: ASN1Object?

    func sub(_ index: Int) -> ASN1Object? {
        if let sub = self.sub, index >= 0, index < sub.count {
            return sub[index]
        }
        return nil
    }

    func subCount() -> Int {
        return sub?.count ?? 0
    }

    func findOid(_ oid: OID) -> ASN1Object? {
        return findOid(oid.rawValue)
    }
    
    func findOid(_ oid: String) -> ASN1Object? {
        for child in sub ?? [] {
            if child.identifier?.tagNumber() == .objectIdentifier {
                if child.value as? String == oid {
                    return child
                }
            } else {
                if let result = child.findOid(oid) {
                    return result
                }
            }
        }
        return nil
    }

    var description: String {
        return printAsn1()
    }

    var asString: String? {
        if let string = value as? String {
            return string
        }
        
        for item in sub ?? [] {
            if let string = item.asString {
                return string
            }
        }
        
        return nil
    }
    
    fileprivate func printAsn1(insets: String = "") -> String {
        var output = insets
        output.append(identifier?.description.uppercased() ?? "")
        output.append(value != nil ? ": \(value!)": "")
        if identifier?.typeClass() == .universal, identifier?.tagNumber() == .objectIdentifier {
            if let oidName = OID.description(of: value as? String ?? "") {
                output.append(" (\(oidName))")
            }
        }
        output.append(sub != nil && sub!.count > 0 ? " {": "")
        output.append("\n")
        for item in sub ?? [] {
            output.append(item.printAsn1(insets: insets + "    "))
        }
        output.append(sub != nil && sub!.count > 0 ? insets + "}\n": "")
        return output
    }
}
