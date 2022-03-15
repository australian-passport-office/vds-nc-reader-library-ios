//
//  X509PublicKey.swift
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

internal class X509PublicKey {

    let pkBlock: ASN1Object

    init(pkBlock: ASN1Object) {
        self.pkBlock = pkBlock
    }

    var algOid: String? {
        return pkBlock.sub(0)?.sub(0)?.value as? String
    }

    var algName: String? {
        return OID.description(of: algOid ?? "")
    }

    var algParams: String? {
        return pkBlock.sub(0)?.sub(1)?.value as? String
    }
    
    var derEncodedKey: Data? {
        return pkBlock.rawValue?.derEncodedSequence
    }

    var key: Data? {
        guard
            let algOid = algOid,
            let oid = OID(rawValue: algOid),
            let keyData = pkBlock.sub(1)?.value as? Data else {
                return nil
        }

        switch oid {
        case .ecPublicKey:
            return keyData

        case .rsaEncryption:
            guard let publicKeyAsn1Objects = (try? ASN1DERDecoder.decode(data: keyData)) else {
                return nil
            }
            guard let publicKeyModulus = publicKeyAsn1Objects.first?.sub(0)?.value as? Data else {
                return nil
            }
            return publicKeyModulus

        default:
            return nil
        }
    }
}
