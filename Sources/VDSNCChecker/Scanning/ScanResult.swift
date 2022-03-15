//
//  ScanResult.swift
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
import UIKit

internal struct ScanResult {
    
    /// Enum for VDS verification result status
    internal enum VDSVerificationResult {
        case failed
        case verified
    }
    
    /// Verification error, returned if not successfully verified
    internal var vdsVerificationError: VDSVerifyError?
    
    /// VDS object
    internal var vds: VDS
    
    /// Whether or not the VDS verification was successful
    internal var vdsVerificationResult: VDSVerificationResult
    
    /// initialize with a VDS picked up in a scan
    /// - Parameter vds: vds
    init(vds: VDS) {
        self.vds = vds
        self.vdsVerificationResult = .failed
        
        let vdsAuthenticator = VDSAuthenticator()
        
        do {
            let isVerified = try vdsAuthenticator.verify(
                vds: vds,
                withCscaCertificates: CertificateRepository.shared().cscaCertificates
            )
            self.vdsVerificationResult = isVerified ? .verified : .failed
        } catch let error as VDSVerifyError {
            self.vdsVerificationError = error
            self.vdsVerificationResult = .failed
        } catch {
            self.vdsVerificationResult = .failed
        }
              
    }
    
}
