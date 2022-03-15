//
//  VDSReader.swift
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

/// Reader to assist with converting VDS JSON data  into a ``VDS`` object

public class VDSReader {

    public init() {
        
    }
    /// Decodes VDS data from a VDS JSON string.
    ///
    /// - Parameters:
    ///     - jsonString: The VDS JSON string
    ///
    /// - Returns: A `VDS` if decoding is successful, otherwise throws an error.
    /// - Throws: `VDSDecodeError` if decoding fails.
    public func decodeVDSFrom(jsonString: String) throws -> VDS? {
        do {
            let decoder = JSONDecoder()
            var vds = try decoder.decode(VDS.self, from: Data(jsonString.utf8))
            vds.originalJson = jsonString
            return vds
        } catch {
            throw VDSDecodeError.jsonDecoding
        }
    }
}
