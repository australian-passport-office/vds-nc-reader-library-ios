//
//  X509ExtensionClasses.swift
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

internal extension X509Certificate {
    
    /// Recognition for Basic Constraint Extension (2.5.29.19)
    class BasicConstraintExtension: X509Extension {
        
        var isCA: Bool {
            return (valueAsBlock?.sub(0)?.sub(0)?.value as? Bool) ?? false
        }
        
        var pathLenConstraint: UInt64? {
            guard let data = valueAsBlock?.sub(0)?.sub(1)?.value as? Data else {
                return nil
            }
            return data.uint64Value
        }
    }

    /// Recognition for Subject Key Identifier Extension (2.5.29.14)
    class SubjectKeyIdentifierExtension: X509Extension {
        
        override var value: Any? {
            guard let rawValue = valueAsBlock?.rawValue else {
                return nil
            }
            return rawValue.sequenceContent
        }
    }
    
    // MARK: - Authority Extensions
    
    struct AuthorityInfoAccess {
        let method: String
        let location: String
    }
    
    /// Recognition for Authority Info Access Extension (1.3.6.1.5.5.7.1.1)
    class AuthorityInfoAccessExtension: X509Extension {
        
        var infoAccess: [AuthorityInfoAccess]? {
            guard let valueAsBlock = valueAsBlock else {
                return nil
            }
            let subs = valueAsBlock.sub(0)?.sub ?? []
            
            return subs.compactMap { sub in
                guard var oidData = sub.sub(0)?.rawValue,
                      let nameBlock = sub.sub(1) else {
                    return nil
                }
                if
                    let oid = ASN1DERDecoder.decodeOid(contentData: &oidData),
                    let location = generalName(of: nameBlock) {
                    return AuthorityInfoAccess(method: oid, location: location)
                } else {
                    return nil
                }
            }
        }
    }
    
    /// Recognition for Authority Key Identifier Extension (2.5.29.35)
    class AuthorityKeyIdentifierExtension: X509Extension {
        
        /*
        AuthorityKeyIdentifier ::= SEQUENCE {
           keyIdentifier             [0] KeyIdentifier           OPTIONAL,
           authorityCertIssuer       [1] GeneralNames            OPTIONAL,
           authorityCertSerialNumber [2] CertificateSerialNumber OPTIONAL  }
        */
        
        var keyIdentifier: Data? {
            guard let sequence = valueAsBlock?.sub(0)?.sub else {
                return nil
            }
            if let sub = sequence.first(where: { $0.identifier?.tagNumber().rawValue == 0 }) {
                return sub.rawValue
            }
            return nil
        }

        var certificateIssuer: [String]? {
            guard let sequence = valueAsBlock?.sub(0)?.sub else {
                return nil
            }
            if let sub = sequence.first(where: { $0.identifier?.tagNumber().rawValue == 1 }) {
                return sub.sub?.compactMap { generalName(of: $0) }
            }
            return nil
        }

        var serialNumber: Data? {
            guard let sequence = valueAsBlock?.sub(0)?.sub else {
                return nil
            }
            if let sub = sequence.first(where: { $0.identifier?.tagNumber().rawValue == 2 }) {
                return sub.rawValue
            }
            return nil
        }
    }
    
    // MARK: - Certificate Policies Extension
    
    struct CertificatePolicyQualifier {
        let oid: String
        let value: String?
    }
    struct CertificatePolicy {
        let oid: String
        let qualifiers: [CertificatePolicyQualifier]?
    }
    
    /// Recognition for Certificate Policies Extension (2.5.29.32)
    class CertificatePoliciesExtension: X509Extension {
        
        var policies: [CertificatePolicy]? {
            guard let valueAsBlock = valueAsBlock else {
                return nil
            }
            let subs = valueAsBlock.sub(0)?.sub ?? []
            
            return subs.compactMap { sub in
                guard
                    var data = sub.sub(0)?.rawValue,
                    let oid = ASN1DERDecoder.decodeOid(contentData: &data) else {
                    return nil
                }
                var qualifiers: [CertificatePolicyQualifier]?
                if let subQualifiers = sub.sub(1) {
                    qualifiers = subQualifiers.sub?.compactMap { sub in
                        if var rawValue = sub.sub(0)?.rawValue, let oid = ASN1DERDecoder.decodeOid(contentData: &rawValue) {
                            let value = sub.sub(1)?.asString
                            return CertificatePolicyQualifier(oid: oid, value: value)
                        } else {
                            return nil
                        }
                    }
                }
                return CertificatePolicy(oid: oid, qualifiers: qualifiers)
            }
        }
    }
    
    // MARK: - CRL Distribution Points
    
    class CRLDistributionPointsExtension: X509Extension {
        
        var crls: [String]? {
            guard let valueAsBlock = valueAsBlock else {
                return nil
            }
            let subs = valueAsBlock.sub(0)?.sub ?? []
            return subs.compactMap { $0.asString }
        }
    }
}
