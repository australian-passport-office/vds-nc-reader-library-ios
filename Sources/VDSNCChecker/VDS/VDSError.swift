//
//  VDSError.swift
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

internal enum VDSDecodeError: Error {
    case jsonDecoding
}

/// Types of errors that can occur when verifying a VDS
public enum VDSVerifyError: Error {
    case parseBSCCertFromVdsFailed
    case parseSignatureFromVdsFailed
    case parseJsonNoJsonFound
    case parseJsonNotSerializable
    case parseJsonNoDictionary
    case parseJsonNoDataObject
    case parseJsonFailedCanonicalization
    case loadBSCCertNoPublicKey
    case loadCSCACertNoPublicKey
    case createBSCSecCertFailed
    case createBSCSecTrustFailed
    case createCSCASecCertFailed
    case createCSCASecTrustFailed
    case noMatchingCSCAfound
    case loadBSCX509CertFailed
    case loadCSCAX509CertFailed
    case loadCSCACertDataFailed
    case CSCACertHashDoesntMatch
    case loadCRLFailed
    case verifyCRLFailed
    case BSCCertNoSerialNumber
    case verifyBSCCertNotInCRLFailed
    case extractBSCAkiFailed
    case extractCSCASkiFailed
    case loadBSCPublicKeyDataFailed
    case BSCAkiDoesntMatchCSCASki
    case setTrustAnchorCSCACertFailed
    case setTrustAnchorCertOnly
    case setTrustEvaluateFailed
    case verifyVDSSignatureFailed
    case verifyBSCSignatureFailed
    case noBSCSignatureFound
    case noBSCBlock1Found
    case bscKeyAlgorithmNotSupported
    case issuerSubjectsDontMatch
}
