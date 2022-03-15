//
//  CRL.swift
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

/// A model representing a Certificate Revocation List (CRL)
///
/// CRLs can be just static data, or can be updated using a CRL URL.
///
/// You can create a CRL using the ``init(crlData:)`` initializer, or
/// using the ``init(updatingURL:initialCrlData:)`` if there is a
/// URL that can be used to routinely update the stored CRL data.

public class CRL {
    
    // MARK: - Properties
    
    /// URL to update the CRL data from
    public private(set) var url: URL?
    
    /// CRL data
    public private(set) var data: Data?
    
    /// date the CRL data was last downloaded from the URL
    public private(set) var dateLastDownloaded: Date?
    
    private let keychainKeyCrlPrefix = "vdsncchecker.crldata."
    private let keychainKeyDatePrefix = "vdsncchecker.downloaded."
        
    
    // MARK: - Initialization
   
    /// Initializes CRL, will use crl data provided, and doesnt auto update
    /// - Parameter data: crl data
    public init(crlData: Data) {
        self.data = crlData
    }
    
    /// Initializes auto updating CRL, if initial CRL data is provided then that is used to start off with
    /// - Parameters:
    ///   - updatingURL: url to use to download the data from
    ///   - initialCrlData: optional initial data to use before updating it from the provided data
    public init(updatingURL: URL, initialCrlData: Data? = nil) {
        self.url = updatingURL
        
        //try to retrieve the CRL from the keychain
        if let keychainData = getCRLDataFromKeychain() {
            //we have existing keychain data so use it
            self.data = keychainData
        } else {
            if initialCrlData != nil {
                //we dont have anything in the keychain but we have pre-bundled data, save to keychain
                saveCRLDataToKeychain()
                self.data = initialCrlData
            }
        }
        
        //retrieve last downloaded date
        self.dateLastDownloaded = getUpdatedDateFromKeychain()
    }
        
    // MARK: - Updating
    
    /// Updates the CRL data from the url and stores it in the keychain for later retrieval.
    ///
    /// - Returns: `true` if the CRL data was successfully updated, `false` otherwise
    public func update(completion: @escaping (_ success: Bool) -> Void) {
        // Download CRL file
        
        guard let downloadUrl = url else {
            completion(false)
            return
        }
        
        downloadFile(url: downloadUrl) { result in
            switch result {
            case .success(let data):
                
                // Save in memory
                self.data = data
                self.dateLastDownloaded = Date()
                
                //save to keychain
                self.saveCRLDataToKeychain()
                self.saveUpdatedDateToKeychain()
                
                completion(true)
            case .failure(_):
                completion(false)
            }
        }
       
    }
    
    /// Downloads data from the given array of URLs. Attempts to download from the first URL - on failure the second URL is tried, and
    /// and so on until all URLs have been tried.
    ///
    /// - Parameters:
    ///     - urls: Array of URLs to attempt to download from
    ///     - callback: Callback that is called with the data (on success) or nil (on failure, once all URLs have been tried)
    private func downloadFile(url: URL, completion: @escaping (Result<Data, Error>) -> Void) {
        
        let downloadTask = URLSession.shared.downloadTask(with: url) {
            fileUrlOrNil, responseOrNil, errorOrNil in
            
            // Try to parse the data from the downloaded file URL
            guard let fileUrl = fileUrlOrNil else {
                completion(.failure(DownloadFileError.noFileURL))
                return
            }
            
            do {
                let data = try Data(contentsOf: fileUrl)
                completion(.success(data))
            } catch {
                completion(.failure(DownloadFileError.noFileData))
                return
            }
            
            // Remove the temporary file
            do {
                try FileManager.default.removeItem(at: fileUrl)
            } catch {
                // print("Failed to remove item at path: ", fileUrl)
            }
            
        }
        
        downloadTask.resume()
    }
    
    enum DownloadFileError: Error {
        case noFileURL
        case noFileData
    }
    
    // MARK: - Keychain
    
    private func getCRLDataFromKeychain() -> Data? {
        guard let downloadUrl = url else {
            return nil
        }
        return KeychainHelper.getData(key: keychainKeyCrlPrefix + downloadUrl.absoluteString)
    }
    
    private func getUpdatedDateFromKeychain() -> Date? {
        guard let downloadUrl = url else {
            return nil
        }
        return KeychainHelper.getItem(key: keychainKeyDatePrefix + downloadUrl.absoluteString)
    }
    
    private func saveCRLDataToKeychain() {
        if let downloadUrl = url, let crlData = data {
            KeychainHelper.setData(key: keychainKeyCrlPrefix + downloadUrl.absoluteString, data: crlData)
        }
    }
    
    private func saveUpdatedDateToKeychain() {
        if let downloadUrl = url, let date = dateLastDownloaded {
            KeychainHelper.setItem(key: keychainKeyDatePrefix + downloadUrl.absoluteString, item: date)
        }
    }
}
