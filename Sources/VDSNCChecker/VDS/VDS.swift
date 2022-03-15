//
//  VDS.swift
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

// MARK: - VDS

/// VDS is a Visible Digital Seal codable object
///
/// A VDS is the visible, scannable code on a document which can be machine read to verify the integrity of the document.
/// Full specification [here](https://www.icao.int/Security/FAL/TRIP/Documents/TR%20-%20Visible%20Digital%20Seals%20for%20Non-Electronic%20Documents%20V1.31.pdf).

public struct VDS: Codable {
    /// Data. The actual data for the VDS, including version, person info, vaccination info, etc.
    public let data: VDSData

    /// Signature. The cryptographic signature used to verify the authenticity of the data.
    public let sig: VDSSig

    /// Original JSON - not part of VDS spec, used by VDSReader internally
    public var originalJson: String?
}

// MARK: - VDSData

/// VDS Data
public struct VDSData: Codable {
    /// Header. Includes type of data, version and issuing country.
    public let hdr: VDSHdr

    /// Message. Includes person and vaccination info.
    public let msg: VDSMsg
}

// MARK: - VDSHdr

/// VDS Header
public struct VDSHdr: Codable {
    /// Type of data. Can be either `icao.test` or `icao.vacc`. Other types possible in the future. Required.
    public let t: String

    /// Version. Required.
    public let v: Int

    /// Issuing country. In 3 letter country code format (e.g. `AUS`). Required.
    public let hdrIs: String

    enum CodingKeys: String, CodingKey {
        case t, v
        case hdrIs = "is"
    }
}

// MARK: - VDSMsg

/// VDS Message
public struct VDSMsg: Codable {
    /// Unique vaccination certificate identifier. Required.
    public let uvci: String

    /// Person identification info. Required.
    public let pid: VDSPID

    /// Array of vaccination events. Required.
    public let ve: [VDSVe]
}

// MARK: - VDSPID

/// VDS Personal identification
public struct VDSPID: Codable {
    /// Date of birth. In `yyyy-MM-dd` format. Required if `i` (travel document number) is not provided.
    public let dob: String?

    /// Name. A double space separates first and last name (e.g. `JANE  CITIZEN`). May be truncated. Required.
    public let n: String

    /// Sex. `M` for male, `F` for female or `X` for unspecified.
    public let sex: String?

    /// Unique travel document number.
    public let i: String?

    /// Additional identifier at discretion of issuer.
    public let ai: String?
}

// MARK: - VDSVe

/// VDS Vaccination event
public struct VDSVe: Codable {
    /// Vaccine type/subtype. Required.
    public let des: String

    /// Brand name. Required.
    public let nam: String

    /// Disease targeted by vaccine. Required.
    public let dis: String

    /// Array of vaccination details. Required.
    public let vd: [VDSVd]
}

// MARK: - VDSVd

/// VDS Vaccination details
public struct VDSVd: Codable {
    /// Date of vaccination. In `yyyy-MM-dd` format. Required.
    public let dvc: String

    /// Dose sequence number. Required.
    public let seq: Int

    /// Country of vaccination. In 3 letter country code format (e.g. `AUS`). Required.
    public let ctr: String

    /// Administering center. Required.
    public let adm: String

    /// Vaccine lot number. Required.
    public let lot: String

    /// Date of next vaccination. In `yyyy-MM-dd` format.
    public let dvn: String?
}

// MARK: - VDSSig

/// VDS Signature
public struct VDSSig: Codable {
    /// Crypto algorithm used for the signature. Can be either `ES256`, `ES384` or `ES512` (typically `ES256`). Required.
    public let alg: String

    /// Certificate used for the signature. In Base64 URL encoding (not the same as normal Base64!). Required.
    public let cer: String

    /// Signature value. In Base64 URL encoding (not the same as normal Base64!). Required.
    public let sigvl: String
}
