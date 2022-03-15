//
//  VDSAuthenticator.swift
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
import CryptoKit

/// Verifies a VDS using information issued by varying certificate authorities.
public class VDSAuthenticator {

    
    public init() {
        
    }

    // MARK: - Internal Classes
    
    /// Error when parsing a CRL
    private struct CRLParseError : Error {}
    
    /// Error when verifying signature
    private struct VerifySignatureError : Error {}
    
    // MARK: - Verify VDS

    /// Verifies a `VDS`,returning true if it is authentic, otherwise throws an error.
    ///
    /// - Parameters:
    ///     - vds: A `VDS`.
    ///     - cscaCertificate: CSCA certificate to be used for the verification
    ///
    /// - Returns: True if the `VDS` is authentic, otherwise throws an error.
    /// - Throws: `VDSVerifyError` if verification fails.
    public func verify(vds: VDS, withCscaCertificate cscaCertificate: CSCACertificate) throws -> Bool {
        
        guard let crlData = cscaCertificate.crl.data else {
            throw VDSVerifyError.loadCRLFailed
        }
        
        return try verify(vds: vds, withCscaCertData: cscaCertificate.data, cscaCertSHA256Hash: cscaCertificate.integrityHash, crlData: crlData)
    }
    
    /// Verifies a `VDS`, returning true if it is authentic, otherwise throws an error.
    ///
    /// - Parameters:
    ///     - vds: A `VDS`.
    ///     - cscaCertificates: one that successfully matches the VDS will be used for the verification
    ///
    /// - Returns: True if the `VDS` is authentic, otherwise throws an error.
    /// - Throws: `VDSVerifyError` if verification fails.
    public func verify(vds: VDS, withCscaCertificates cscaCertificates: [CSCACertificate]) throws -> Bool {
                
        //see if we have a CSCA from our list
        guard let cscaCertificate = try findMatchingCSCACert(forVds: vds, fromCscaCerts: cscaCertificates) else {
            throw VDSVerifyError.noMatchingCSCAfound
        }
        
        return try verify(vds:vds, withCscaCertificate: cscaCertificate)
    }
    
    /// Verifies a `VDS`, returning true if it is authentic, otherwise throws an error.
    ///
    /// - Parameters:
    ///     - vds: A `VDS`.
    ///     - cscaCertData: CSCA certificate data (in DER format).
    ///     - cscaCertSHA256Hash: Trusted SHA256 hash of CSCA certificate data - used to ensure the CSCA certificate data has not been tampered with.
    ///     - crlData: CRL data - used for CRL verification.
    ///
    /// - Returns: True if the `VDS` is authentic, otherwise throws an error.
    /// - Throws: `VDSVerifyError` if verification fails.
    public func verify(vds: VDS, withCscaCertData cscaCertData: Data, cscaCertSHA256Hash: String, crlData: Data) throws -> Bool {
        
        // CSCA
        try verifyCSCACertHash(cscaCertData: cscaCertData, cscaCertSHA256Hash: cscaCertSHA256Hash)
        
        // CRL
        try verifyCRLSignature(crlData: crlData, forPublicKeyInCsca: cscaCertData)
        
        // BSC
        let bscCertData = try vds.certificateData()
        
        try verifyBSCCertNotRevoked(bscCertData, crlData: crlData)
        
        try verifyAKIMatchInBSCCert(bscCertData, withSKIInCsca: cscaCertData)
        
        try verifyPath(inBscCert: bscCertData, forCscaCert: cscaCertData)
        
        // VDS
        try verifySignature(vds: vds)
        
        return true
    }
    
   
    
    
    // MARK: - Security Checks - CSCA
    
    /// Verifies that our CSCA certificate has not been tampered with by checking if its hash matches a known trusted hash.
    ///
    /// - Parameters:
    ///     - cscaCertData: CSCA certificate data (in DER format).
    ///     - cscaCertSHA256Hash: Trusted SHA256 hash of CSCA certificate data.
    ///
    /// - Throws: `VDSVerifyError` if the hash does not match the trusted hash.
    public final func verifyCSCACertHash(cscaCertData: Data, cscaCertSHA256Hash: String) throws {
        // Hash our CSCA cert ourselves
        var cscaCertDataHasher = SHA256()
        cscaCertDataHasher.update(data: cscaCertData)
        let cscaCertDataHash = cscaCertDataHasher.finalize()
        let cscaCertDataHashHexString: String = cscaCertDataHash.withUnsafeBytes { bytes in
            guard let bytesPtr = bytes.baseAddress else {
                return ""
            }

            let data = Data(bytes: bytesPtr, count: SHA256.Digest.byteCount)
            return data.map { String(format: "%02hhx", $0) }.joined()
        }

        // Confirm our new hash matches our trusted hash
        guard cscaCertDataHashHexString == cscaCertSHA256Hash else {
            throw VDSVerifyError.CSCACertHashDoesntMatch
        }
    }
    
    // MARK: - Security Checks - CRL
    
    /// Verifies a CRL's signature using a CSCA public key.
    ///
    /// - Parameters:
    ///     - crlData: CRL data (in DER format).
    ///     - cscaCertData: CSCA certificate data (in DER format).
    ///
    /// - Throws: `VDSVerifyError` if verification fails.
    public final func verifyCRLSignature(crlData: Data, forPublicKeyInCsca cscaCertData: Data) throws {
        
        // Prepare
        var unmanagedError: Unmanaged<CFError>?
        
        let crlASN1 = try getCRLASN1(crlData: crlData)
        let cscaPublicKey = try getCSCAPublicKey(cscaCertData: cscaCertData)

        
        
        // Verify CRL is authentic using CSCA certificate

        // This code is gnarly and way more complicated than it should be, due to Apple not
        // providing any APIs for working with pre-downloaded / from-disk CRLs. Rather, Apple only
        // supports automatically requesting the CRL URLs referenced in the certificates themselves.
        // As CRL checks need to work offline this is not sufficient for our needs, so we are
        // instead parsing and verifying the CRL ourselves.
        //
        // For testing this code I would recommend using the example CRL / cert from
        // https://csrc.nist.gov/projects/pki-testing/sample-certificates-and-crls
        //
        // The CRL format is defined in RFC5280:
        // https://datatracker.ietf.org/doc/html/rfc5280#section-5.1
        //
        // CertificateList  ::=  SEQUENCE  {
        //     tbsCertList          TBSCertList,
        //     signatureAlgorithm   AlgorithmIdentifier,
        //     signatureValue       BIT STRING
        // }
        //
        // TBSCertList  ::=  SEQUENCE  {
        //     version                 Version OPTIONAL,
        //                                  -- if present, MUST be v2
        //     signature               AlgorithmIdentifier,
        //     issuer                  Name,
        //     thisUpdate              Time,
        //     nextUpdate              Time OPTIONAL,
        //     revokedCertificates     SEQUENCE OF SEQUENCE  {
        //          userCertificate         CertificateSerialNumber,
        //          revocationDate          Time,
        //          crlEntryExtensions      Extensions OPTIONAL
        //                                   -- if present, version MUST be v2
        //     }  OPTIONAL,
        //     crlExtensions           [0]  EXPLICIT Extensions OPTIONAL
        //                                   -- if present, version MUST be v2
        // }
        //
        // CertificateSerialNumber  ::=  INTEGER
        //
        // AlgorithmIdentifier  ::=  SEQUENCE  {
        //     algorithm               OBJECT IDENTIFIER,
        //     parameters              ANY DEFINED BY algorithm OPTIONAL
        // }
        //
        do {
            // Parse signature algorithm
            guard let signatureAlgorithm = crlASN1.sub(1) else { throw CRLParseError() }
            guard let algorithm = signatureAlgorithm.sub(0) else { throw CRLParseError() }
            guard let algorithmString = algorithm.asString else { throw CRLParseError() }
            guard let secKeyAlgo = getSecKeyAlgorithmFor(algoString: algorithmString) else { throw CRLParseError() }
            
            // Parse cert list
            guard let tbsCertList = crlASN1.sub(0) else { throw CRLParseError() }
            guard let tbsCertListData = tbsCertList.fullRawValue else { throw CRLParseError() }

            // Parse signature
            guard let signatureValue = crlASN1.sub(2) else { throw CRLParseError() }
            guard let signatureValueData = signatureValue.value as? Data else { throw CRLParseError() }

            
            // Verify signature
            guard SecKeyIsAlgorithmSupported(cscaPublicKey, .verify, secKeyAlgo) else {
                throw CRLParseError()
            }

            guard SecKeyVerifySignature(cscaPublicKey,
                                        secKeyAlgo,
                                        tbsCertListData as CFData,
                                        signatureValueData as CFData,
                                        &unmanagedError) else {
                throw CRLParseError()
            }
        } catch {
            throw VDSVerifyError.verifyCRLFailed
        }
    }
    
    // MARK: - Security Checks - BSC
    
    /// Verifies a BSC certificate is not revoked in a CRL.
    ///
    /// - Parameters:
    ///     - vds: a `VDS`.
    ///     - crlData: CRL data  (in DER format).
    ///
    /// - Throws: `VDSVerifyError` if verification fails.
    public final func verifyBSCCertNotRevoked(_ bscCertData: Data, crlData: Data) throws {
        // Prepare
        let bscX509Cert = try getBSCX509Cert(bscCertData: bscCertData)
        let crl = try getCRLASN1(crlData: crlData)
        
        // Get BSC cert serial number
        guard let bscCertSerialNumber = bscX509Cert.serialNumber else {
            throw VDSVerifyError.BSCCertNoSerialNumber
        }
        
        // Check if the BSC cert serial number is in the CRL
        // See comment in previous section for outline of CRL format to understand below code
        do {
            // Parse cert list
            guard let tbsCertList = crl.sub(0) else { throw CRLParseError() }
            guard let revokedCertificates = tbsCertList.sub(5) else { throw CRLParseError() }

            // Iterate through revoked certificates and check serial numbers
            var isRevoked = false
            revokedCertificates.sub?.forEach {
                if bscCertSerialNumber == $0.sub(0)?.rawValue {
                    isRevoked = true
                }
            }

            if isRevoked {
                throw CRLParseError()
            }
        } catch {
            throw VDSVerifyError.verifyBSCCertNotInCRLFailed
        }
    }
    
     
    /// Verifies a BSC certificate's AKI (Authority Key Identifier) matches a CSCA certificate's SKI.
    ///
    /// - Parameters:
    ///     - bscX509CertData: BSC certificate data
    ///     - cscaX509CertData: CSCA certificate data (in DER format).
    ///
    /// - Throws: `VDSVerifyError` if verification fails.
    public final func verifyAKIMatchInBSCCert(_ bscCertData: Data, withSKIInCsca cscaCertData: Data) throws {
        
        let cscaX509Cert = try getCSCAX509Cert(cscaCertData: cscaCertData)
        let bscX509Cert = try getBSCX509Cert(bscCertData: bscCertData)
                
        // Get BSC AKI
        guard let bscAKIExtObj = bscX509Cert.extensionObject(oid: .authorityKeyIdentifier) as? X509Certificate.AuthorityKeyIdentifierExtension,
              let bscAKI = bscAKIExtObj.keyIdentifier
        else {
            throw VDSVerifyError.extractBSCAkiFailed
        }
        
        // Get CSCA SKI
        guard let cscaSKIExtObj = cscaX509Cert.extensionObject(oid: .subjectKeyIdentifier) as? X509Certificate.SubjectKeyIdentifierExtension,
              let cscaSKI = cscaSKIExtObj.value as? Data
        else {
            throw VDSVerifyError.extractCSCASkiFailed
        }
        
        // Compare
        guard bscAKI == cscaSKI else {
            throw VDSVerifyError.BSCAkiDoesntMatchCSCASki
        }
    }
    
        
    /// Verifies a BSC certificate's includes a CSCA certificate in its certification path.
    ///
    /// - Parameters:
    ///     - vds: A `VDS`.
    ///     - cscaCertData: CSCA certificate data (in DER format).
    ///
    /// - Throws: `VDSVerifyError` if verification fails.
    public final func verifyPath(inBscCert bscCertData: Data, forCscaCert cscaCertData: Data) throws {
       
        let bscX509Cert = try getBSCX509Cert(bscCertData: bscCertData)
        
        // Ensure that the certificate was signed by the issuer, using the subject public key from the previous certificate in the path to verify the signature on the certificate.
        try verifySignature(inBscX509Cert: bscX509Cert, withPublicKeyInCscaCert: cscaCertData)
        
        let cscaX509Cert = try getCSCAX509Cert(cscaCertData: cscaCertData)
        
        //Ensure that the name of the certificate's issuer is equal to the subject name in the previous certificate, and that there is not an empty issuer name in this certificate or the previous certificate subject name. If no previous certificate exists in the path and this is the first certificate in the chain, ensure that the issuer and subject name are identical and that the trust status is set for the certificate
        guard bscX509Cert.issuerOIDs.count == cscaX509Cert.subjectOIDs.count else {
            throw VDSVerifyError.issuerSubjectsDontMatch
            }
        
        for i in 0..<cscaX509Cert.subjectOIDs.count {
            let subject = cscaX509Cert.subject(oidString: cscaX509Cert.subjectOIDs[i])?.first
            let issuer = bscX509Cert.issuer(oidString: bscX509Cert.issuerOIDs[i])
            guard subject == issuer else {
                throw VDSVerifyError.issuerSubjectsDontMatch
            }
        }
        
        
    }
    
    // MARK: - Security Checks - VDS
    
    /// Verifies a VDS's signature.
    ///
    /// - Parameters:
    ///     - vds: a `VDS`.
    ///
    /// - Throws: `VDSVerifyError` if verification fails.
    public final func verifySignature(vds: VDS) throws {
        // Prepare
        var unmanagedError: Unmanaged<CFError>?
        
        let bscCertData = try vds.certificateData()
        let bscTrust = try getBSCSecTrust(bscCertData: bscCertData)
        let canonicalJsonData = try vds.canonicalJson()
        let sigData = try vds.signatureData()
        
        // Get BSC public key
        guard let bscPublicKey = secTrustCopyKey(trust: bscTrust) else {
            throw VDSVerifyError.loadBSCCertNoPublicKey
        }
        
        // Get BSC key data
        guard let bscPublicKeyData = SecKeyCopyExternalRepresentation(bscPublicKey, &unmanagedError) as Data? else {
            throw VDSVerifyError.loadBSCPublicKeyDataFailed
        }
        
        // Validate using different algorithms
        //
        // From the VDS spec:
        //
        // The SignatureAlgo field MUST be only one of the following values:
        // - ES256 – denotes ECDSA with Sha256 hashing algorithm
        // - ES384 – denotes ECDSA with Sha384 hashing algorithm
        // - ES512 – denotes ECDSA with Sha512 hashing algorithm
        do {
            switch vds.sig.alg {
            case "ES256":
                guard let bscCCPublicKey = try? P256.Signing.PublicKey(x963Representation: bscPublicKeyData) else { throw VerifySignatureError() }
                guard let ecdsaSignature = try? P256.Signing.ECDSASignature(rawRepresentation: sigData) else { throw VerifySignatureError() }
                guard bscCCPublicKey.isValidSignature(ecdsaSignature, for: SHA256.hash(data: canonicalJsonData)) else { throw VerifySignatureError() }
                
            case "ES384":
                guard let bscCCPublicKey = try? P384.Signing.PublicKey(x963Representation: bscPublicKeyData) else { throw VerifySignatureError() }
                guard let ecdsaSignature = try? P384.Signing.ECDSASignature(rawRepresentation: sigData) else { throw VerifySignatureError() }
                guard bscCCPublicKey.isValidSignature(ecdsaSignature, for: SHA384.hash(data: canonicalJsonData)) else { throw VerifySignatureError() }
                
            case "ES512":
                guard let bscCCPublicKey = try? P521.Signing.PublicKey(x963Representation: bscPublicKeyData) else { throw VerifySignatureError() }
                guard let ecdsaSignature = try? P521.Signing.ECDSASignature(rawRepresentation: sigData) else { throw VerifySignatureError() }
                guard bscCCPublicKey.isValidSignature(ecdsaSignature, for: SHA512.hash(data: canonicalJsonData)) else { throw VerifySignatureError() }
                
            default:
                // Non-supported algorithm
                throw VerifySignatureError()
            }
        } catch {
            throw VDSVerifyError.verifyVDSSignatureFailed
        }
    }
    
    // MARK: - Helper - CSCA
    
    /// Finds a matching CSCA certificate, given a VDS and one or more CSCA Certificates
    /// - Parameters:
    ///   - vds: vds
    ///   - cscaCertificates: CSCA Certificates
    /// - Returns: a matching CSCA certificate if found, not nil if not
    private func findMatchingCSCACert(forVds vds: VDS, fromCscaCerts cscaCertificates: [CSCACertificate]) throws -> CSCACertificate? {
        
        //get certificate from VDS
        let vdsBscX509Cert = try vds.x509Certificate()
        
        //filter certificates by issuing country
        for cscaCertificate in cscaCertificates.filter({ $0.x509Certificate?.issuingCountry() == vdsBscX509Cert.issuingCountry() }) {
            do {
                try verifySignature(inBscX509Cert: vdsBscX509Cert, withPublicKeyInCscaCert: cscaCertificate.data)
                //we didnt throw an error, it found the right certificate, so return it
                return cscaCertificate
            }
            catch {
                // we dont throw here
            }
        }
        
        return nil
    }
        
    /// Gets the public key from the given CSCA certificate data.
    ///
    /// - Parameters:
    ///     - cscaCertData: CSCA certificate data (in DER format).
    ///
    /// - Returns: CSCA certificate public key.
    ///
    /// - Throws: `VDSVerifyError` if getting the public key fails.
    private func getCSCAPublicKey(cscaCertData: Data) throws -> SecKey {
        // Prepare
        var tempTrust: SecTrust?
        
        // Create CSCA sec cert
        guard let cscaSecCert = SecCertificateCreateWithData(nil, cscaCertData as CFData) else {
            throw VDSVerifyError.createCSCASecCertFailed
        }
        
        let policy = SecPolicyCreateBasicX509()
                
        // Create CSCA trust
        guard SecTrustCreateWithCertificates(cscaSecCert, policy, &tempTrust) == errSecSuccess,
              let cscaTrust = tempTrust else {
            throw VDSVerifyError.createCSCASecTrustFailed
        }
        
        var cscaPublicKey = secTrustCopyKey(trust: cscaTrust)
        
        // if we have managed to get it, great, return
        if let secKey = cscaPublicKey {
            return secKey
        }
        
        // ok we havent managed to get the secKey, lets try a different method..
        let cscaX509Cert = try getCSCAX509Cert(cscaCertData: cscaCertData)
        cscaPublicKey = cscaX509Cert.publicKey?.secKey
        
        if let secKey = cscaPublicKey {
            return secKey
        } else {
            throw VDSVerifyError.loadCSCACertNoPublicKey
        }
    }
    
    
    /// Gets a CSCA X.509 certificate from the given CSCA certificate data.
    ///
    /// - Parameters:
    ///     - cscaCertData: CSCA certificate data (in DER format).
    ///
    /// - Returns: CSCA X.509 certificate.
    ///
    /// - Throws: `VDSVerifyError` if creating the X.509 certificate fails.
    private func getCSCAX509Cert(cscaCertData: Data) throws -> X509Certificate {
        guard let cscaX509Cert = try? X509Certificate(data: cscaCertData as Data) else {
            throw VDSVerifyError.loadCSCAX509CertFailed
        }
        
        return cscaX509Cert
    }
    
    // MARK: - Helper - CRL
    
    /// Gets a CRL from the given CRL data.
    ///
    /// - Parameters:
    ///     - crlData: CRL data (in DER format).
    ///
    /// - Returns: CRL.
    ///
    /// - Throws: `VDSVerifyError` if creating the CRL fails.
    private func getCRLASN1(crlData: Data) throws -> ASN1Object {
        guard let crl = try? ASN1DERDecoder.decode(data: crlData).first else {
            throw VDSVerifyError.loadCRLFailed
        }
        
        return crl
    }
    
    // MARK: - Helper - BSC
    
    /// Verifies the CSCA public key can be used to decrypt the signature in the BSC Cert
    /// - Parameters:
    ///   - bscX509Cert: BSC Certificate in X509 format
    ///   - cscaCertData: CSCA Certificate data (in DER format).
    private func verifySignature(inBscX509Cert bscX509Cert: X509Certificate, withPublicKeyInCscaCert cscaCertData: Data) throws {
        
        guard let cscaPublicKey = try? getCSCAPublicKey(cscaCertData: cscaCertData) else {
            throw VDSVerifyError.loadCSCACertNoPublicKey
        }
                
        // get BSC signature algorithm
        guard let secKeyAlgo = getSecKeyAlgorithmFor(algoString: bscX509Cert.sigAlgOID!) else { throw VDSVerifyError.bscKeyAlgorithmNotSupported }
        
        // check whether CSCA public key supports the BSC signature algorithm
        guard SecKeyIsAlgorithmSupported(cscaPublicKey, .verify, secKeyAlgo) else {
            throw VDSVerifyError.bscKeyAlgorithmNotSupported
        }
        
        // get data to verify
        guard let vdsBscX509CertAsn1 = bscX509Cert.block1.fullRawValue else {
            throw VDSVerifyError.noBSCBlock1Found
        }
        
        // get signature to verify
        guard let vdsBscX509CertSignature = bscX509Cert.signature else {
            throw VDSVerifyError.noBSCSignatureFound
        }
        var unmanagedError: Unmanaged<CFError>?
        
        guard SecKeyVerifySignature(cscaPublicKey,
                                 secKeyAlgo,
                                    vdsBscX509CertAsn1 as CFData,
                                    vdsBscX509CertSignature as CFData,
                                                &unmanagedError) else {
         
            throw VDSVerifyError.verifyBSCSignatureFailed
                    }
    }
    
    /// Gets a BSC sec trust from the given BSC certificate data.
    ///
    /// - Parameters:
    ///     - bscCertData: BSC certificate data (in DER format).
    ///
    /// - Returns: BSC sec trust.
    ///
    /// - Throws: `VDSVerifyError` if creating the sec trust fails.
    private func getBSCSecTrust(bscCertData: Data) throws -> SecTrust {
        // Prepare
        var tempTrust: SecTrust?
        
        // Create BSC sec cert
        guard let bscSecCert = SecCertificateCreateWithData(nil, bscCertData as CFData) else {
            throw VDSVerifyError.createBSCSecCertFailed
        }
        
        // Create BSC trust
        guard SecTrustCreateWithCertificates(bscSecCert, nil, &tempTrust) == errSecSuccess,
              let bscTrust = tempTrust else {
            throw VDSVerifyError.createBSCSecTrustFailed
        }
        
        return bscTrust
    }
    
    /// Gets a BSC X.509 certificate from the given BSC certificate data.
    ///
    /// - Parameters:
    ///     - bscCertData: BSC certificate data (in DER format).
    ///
    /// - Returns: BSC X.509 certificate.
    ///
    /// - Throws: `VDSVerifyError` if creating the X.509 certificate fails.
    private func getBSCX509Cert(bscCertData: Data) throws -> X509Certificate {
        guard let bscX509Cert = try? X509Certificate(data: bscCertData as Data) else {
            throw VDSVerifyError.loadBSCX509CertFailed
        }
        
        return bscX509Cert
    }
    
    // MARK: - Helper - Misc
    
    /// Copies the (public) key out of the given trust object.
    ///
    /// - Parameters:
    ///     - trust: The trust object to copy the key out of.
    ///
    /// - Returns: Key copied out of the given trust object.
    private func secTrustCopyKey(trust: SecTrust) -> SecKey? {
        if #available(iOS 14.0, *) {
            return SecTrustCopyKey(trust)
        } else {
            return SecTrustCopyPublicKey(trust)
        }
    }
    
    private func getSecKeyAlgorithmFor(algoString: String) -> SecKeyAlgorithm? {
        switch algoString {
        case OID.sha256WithRSAEncryption.rawValue:
            return .rsaSignatureMessagePKCS1v15SHA256
        case OID.rsaEncryption.rawValue:
            return .rsaSignatureMessagePKCS1v15SHA256
        case OID.ecdsaWithSHA384.rawValue:
            return .ecdsaSignatureMessageX962SHA384
        case OID.ecPublicKey.rawValue:
            return .ecdsaSignatureMessageX962SHA384
        default:
            return nil
        }
    }
    
   
}

private extension X509Certificate {
    func issuingCountry() -> String? {
        return issuer(oid: OID.countryName)
    }
}

private extension X509PublicKey {
    
    var secKey : SecKey? {
        
        var unmanagedError: Unmanaged<CFError>?
        
        guard let algOid = algOid,
              let oid = OID(rawValue: algOid) else {
            return nil
        }
        
        // Create public secKey
        switch oid {
        case .ecPublicKey:
            guard let keyData = key else {
                return nil
            }
            let attributes: [String: Any] = [
                kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
                kSecAttrKeyType as String: kSecAttrKeyTypeEC
            ]
            return SecKeyCreateWithData(keyData as CFData, attributes as CFDictionary, &unmanagedError)
            
        case .rsaEncryption:
            guard let keyData = derEncodedKey else {
                return nil
            }
            // for RSA bit size is modulus * 8
            let attributes: [String: Any] = [
                kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
                kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
                kSecAttrKeySizeInBits as String: keyData.count * 8
            ]
            return SecKeyCreateWithData(keyData as CFData, attributes as CFDictionary, &unmanagedError)
            
        default:
            return nil
        }
        
    }
    
}

private extension VDS {
    /// Gets BSC certificate data from the given VDS.
    /// - Returns: BSC certificate data (in DER format).
    ///
    /// - Throws: `VDSVerifyError` if extracting the BSC certificate data fails.
    func certificateData() throws -> Data {
        let bscCertBase64String = getBase64StringFor(base64UrlString: sig.cer)
        guard let bscCertData = Data(base64Encoded: bscCertBase64String) else {
            throw VDSVerifyError.parseBSCCertFromVdsFailed
        }
        
        return bscCertData
    }
    
    func x509Certificate() throws -> X509Certificate {
        guard let cert = try? X509Certificate(data: certificateData() as Data) else {
            throw VDSVerifyError.loadCSCAX509CertFailed
        }
        return cert
    }
    
   
    
    /// Gets signature data
    /// - Returns: Signature data.
    ///
    /// - Throws: `VDSVerifyError` if extracting the signature data fails.
    func signatureData() throws -> Data {
        let sigBase64String = getBase64StringFor(base64UrlString: sig.sigvl)
        guard let sigData = Data(base64Encoded: sigBase64String) else {
            throw VDSVerifyError.parseSignatureFromVdsFailed
        }
        
        return sigData
    }
    
    
    /// Gets canonical JSON data from the given VDS. This is used as part of the VDS signature verification process.
    ///
    /// Canonical JSON is described here: http://gibson042.github.io/canonicaljson-spec/
    /// - Returns: Canonical JSON representation of the `VDS`.
    ///
    /// - Throws: `VDSVerifyError` if getting the canonical JSON data fails.
    func canonicalJson() throws -> Data {
        guard let json = originalJson else {
            throw VDSVerifyError.parseJsonNoJsonFound
        }

        guard let jsonObj = try? JSONSerialization.jsonObject(with: Data(json.utf8), options: []) else {
            throw VDSVerifyError.parseJsonNotSerializable
        }

        guard let jsonDict = jsonObj as? [String: Any] else {
            throw VDSVerifyError.parseJsonNoDictionary
        }

        guard let jsonDataObj = jsonDict["data"] else {
            throw VDSVerifyError.parseJsonNoDataObject
        }
        
        guard let canonicalJsonData = try? JsonCanonicalizer.canonicalize(withJSONObject: jsonDataObj) else {
            throw VDSVerifyError.parseJsonFailedCanonicalization
        }
        
        return canonicalJsonData
    }
    
    /// Gets a Base64 string for a given Base64 URL string.
    ///
    /// Further information on Base64 URL strings: https://datatracker.ietf.org/doc/html/rfc4648#section-5
    ///
    /// - Parameters:
    ///     - base64UrlString: A Base64 URL string.
    ///
    /// - Returns: A Base64 string created from the given Base64 URL string.
    private func getBase64StringFor(base64UrlString: String) -> String {
        var base64String = base64UrlString
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        if base64String.count % 4 != 0 {
            base64String.append(String(repeating: "=", count: 4 - base64String.count % 4))
        }
        
        return base64String
    }
    
}
