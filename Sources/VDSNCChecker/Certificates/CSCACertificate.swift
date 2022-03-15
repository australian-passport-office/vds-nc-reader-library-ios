//
//  CSCACertificate.swift
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

/// A model representing a CSCA Certificate
///
/// The CSCA certificate has the x509 certificate data which is paired with a ``CRL`` and the integrity hash to ensure it hasnt been tampered with
///
/// You can create a CSCA Certificate by using the ``init(data:integrityHash:crl:)`` initializer
///
public struct CSCACertificate {
    
    /// CSCA certificate data (in DER format)
    private(set) var data: Data
    
    /// CSCA certificate integrity hash (in SHA256 format)
    private(set) var integrityHash: String
    
    /// CRL
    private(set) var crl: CRL
    
    /// X509Certificate
    private(set) var x509Certificate: X509Certificate?
    
    /// Initializes Certificate
    /// - Parameter data: CSCA certificate data (in DER format)
    /// - Parameter integrityHash: CSCA certificate integrity hash (in SHA256 format)
    /// - Parameter crl: CRL
    public init(data: Data, integrityHash: String, crl: CRL) {
        self.data = data
        self.integrityHash = integrityHash
        self.crl = crl
        
        if let cscaX509Cert = try? X509Certificate(data: data) {
            self.x509Certificate = cscaX509Cert
        }
    }
}
