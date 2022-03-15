//
//  KeychainHelper.swift
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

class KeychainHelper {

    /// Gets item from the keychain. The item is JSON decoded after being retrieved.
    ///
    /// - Parameters:
    ///     - key: Key to retrieve the data for from the keychain
    ///
    /// - Returns: Item or nil
    public static func getItem<T: Codable>(key: String) -> T? {
        guard let data = getData(key: key) else {
            return nil
        }

        let jsonDecoder = JSONDecoder()
        guard let result = try? jsonDecoder.decode(T.self, from: data) else {
            return nil
        }

        return result
    }

    /// Sets item in the keychain. The item is JSON encoded prior to being inserted.
    ///
    /// - Parameters:
    ///     - key: Key to set the data for in the keychain
    ///     - item: Item to store in the keychain - must be `Codable`
    public static func setItem<T: Codable>(key: String, item: T) {
        let jsonEncoder = JSONEncoder()
        guard let data = try? jsonEncoder.encode(item) else {
            return
        }

        setData(key: key, data: data)
    }

    /// Gets data from the keychain.
    ///
    /// - Parameters:
    ///     - key: Key to retrieve the data for from the keychain
    ///
    /// - Returns: Data, or `nil` if the key is not found or an error occurs
    public static func getData(key: String) -> Data? {
        // Create query to get the data from the keychain
        let getQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        // Get data from keychain
        var dataOrNil: CFTypeRef?
        guard SecItemCopyMatching(getQuery as CFDictionary, &dataOrNil) == errSecSuccess,
              let data = dataOrNil as? Data else {
            // print("[Keychain] Failed to get data from keychain for key <\(key)>")
            return nil
        }

        return data
    }

    /// Sets data in the keychain.
    ///
    /// - Parameters:
    ///     - key: Key to set the data for in the keychain
    ///     - data: Data to store in the keychain
    ///
    /// - Returns: `true` on success, `false` otherwise
    @discardableResult public static func setData(key: String, data: Data) -> Bool {
        // Create query to add the data to the keychain
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        // Add data to keychain
        var result = SecItemAdd(addQuery as CFDictionary, nil)
        if result == errSecDuplicateItem {
            // Update existing data in keychain instead
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key
            ]

            let updateAttr: [String: Any] = [
                kSecValueData as String: data
            ]

            result = SecItemUpdate(updateQuery as CFDictionary, updateAttr as CFDictionary)
        }

        guard result == errSecSuccess else {
            // print("[Keychain] Failed to add data to keychain for key <\(key)>")
            return false
        }

        // print("[Keychain] Successfully added data to keychain for key <\(key)>")

        return true
    }
}
