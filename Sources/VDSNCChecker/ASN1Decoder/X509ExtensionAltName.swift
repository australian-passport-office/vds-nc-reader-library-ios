//
//  X509ExtensionAltName.swift
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

internal extension X509Extension {
    
    // Used for SubjectAltName and IssuerAltName
    // Every name can be one of these subtype:
    //  - otherName      [0] INSTANCE OF OTHER-NAME,
    //  - rfc822Name     [1] IA5String,
    //  - dNSName        [2] IA5String,
    //  - x400Address    [3] ORAddress,
    //  - directoryName  [4] Name,
    //  - ediPartyName   [5] EDIPartyName,
    //  - uniformResourceIdentifier [6] IA5String,
    //  - IPAddress      [7] OCTET STRING,
    //  - registeredID   [8] OBJECT IDENTIFIER
    //
    // Result does not support: x400Address and ediPartyName
    //
    var alternativeNameAsStrings: [String] {
        var result: [String] = []
        for item in block.sub?.last?.sub?.last?.sub ?? [] {
            guard let name = generalName(of: item) else {
                continue
            }
            result.append(name)
        }
        return result
    }
    
    func generalName(of item: ASN1Object) -> String? {
        guard let nameType = item.identifier?.tagNumber().rawValue else {
            return nil
        }
        switch nameType {
        case 0:
            if let name = item.sub?.last?.sub?.last?.value as? String {
                return name
            }
        case 1, 2, 6:
            if let name = item.value as? String {
                return name
            }
        case 4:
            if let sequence = item.sub(0) {
                return ASN1DistinguishedNameFormatter.string(from: sequence)
            }
        case 7:
            if let ip = item.value as? Data {
                return ip.map({ "\($0)" }).joined(separator: ".")
            }
        case 8:
            if let value = item.value as? String, var data = value.data(using: .utf8) {
                let oid = ASN1DERDecoder.decodeOid(contentData: &data)
                return oid
            }
        default:
            return nil
        }
        return nil
    }
}
