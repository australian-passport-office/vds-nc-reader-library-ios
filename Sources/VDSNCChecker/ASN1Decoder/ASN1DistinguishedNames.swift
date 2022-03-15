//
//  ASN1DistinguishedNames.swift
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

internal class ASN1DistinguishedNameFormatter {

    static var separator = ", "

    // Format subject/issuer information in RFC1779
    class func string(from block: ASN1Object) -> String? {
        var result: String?
        for sub in block.sub ?? [] {
            if let subOid = sub.sub(0)?.sub(0), subOid.identifier?.tagNumber() == .objectIdentifier,
               let oidString = subOid.value as? String, let value = sub.sub(0)?.sub(1)?.value as? String {
                if result == nil {
                    result = ""
                } else {
                    result?.append(separator)
                }
                if let oid = OID(rawValue: oidString) {
                    if let representation = shortRepresentation(oid: oid) {
                        result?.append(representation)
                    } else {
                        result?.append("\(oid)")
                    }
                } else {
                    result?.append(oidString)
                }
                result?.append("=")
                result?.append(quote(string: value))
            }
        }
        return result
    }

    class func quote(string: String) -> String {
        let specialChar = ",+=\n<>#;\\"
        if string.contains(where: { specialChar.contains($0) }) {
            return "\"" + string + "\""
        } else {
            return string
        }
    }

    class func shortRepresentation(oid: OID) -> String? {
        switch oid {
        case .commonName: return "CN"
        case .dnQualifier: return "DNQ"
        case .serialNumber: return "SERIALNUMBER"
        case .givenName: return "GIVENNAME"
        case .surname: return "SURNAME"
        case .organizationalUnitName: return "OU"
        case .organizationName: return "O"
        case .streetAddress: return "STREET"
        case .localityName: return "L"
        case .stateOrProvinceName: return "ST"
        case .countryName: return "C"
        case .emailAddress: return "E"
        case .domainComponent: return "DC"
        case .jurisdictionLocalityName: return "jurisdictionL"
        case .jurisdictionStateOrProvinceName: return "jurisdictionST"
        case .jurisdictionCountryName: return "jurisdictionC"
        default: return nil
        }
    }
}
