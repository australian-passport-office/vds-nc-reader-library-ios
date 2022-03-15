//
//  X509Extension.swift
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

internal class X509Extension {

    let block: ASN1Object

    required init(block: ASN1Object) {
        self.block = block
    }

    var oid: String? {
        return block.sub(0)?.value as? String
    }

    var name: String? {
        return OID.description(of: oid ?? "")
    }

    var isCritical: Bool {
        if block.sub?.count ?? 0 > 2 {
            return block.sub(1)?.value as? Bool ?? false
        }
        return false
    }

    var value: Any? {
        if let valueBlock = block.sub?.last {
            return firstLeafValue(block: valueBlock)
        }
        return nil
    }

    var valueAsBlock: ASN1Object? {
        return block.sub?.last
    }

    var valueAsStrings: [String] {
        var result: [String] = []
        for item in block.sub?.last?.sub?.last?.sub ?? [] {
            if let name = item.value as? String {
                result.append(name)
            }
        }
        return result
    }
}
