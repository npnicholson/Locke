//
//  KeyChain.swift
//  Locke
//
//  Created by Norris Nicholson on 8/30/23.
//

import Foundation
import CryptoKit

// @see: https://stackoverflow.com/questions/30719638/save-and-retrieve-value-via-keychain
class Keychain {
    enum KeychainError: Error {
        // Attempted read for an item that does not exist.
        case itemNotFound
        
        // Attempted save to override an existing item.
        // Use update instead of save to update existing items
        case duplicateItem
        
        // A read of an item in any format other than Data
        case invalidItemFormat
        
        // Any operation result status than errSecSuccess
        case unexpectedStatus(OSStatus)
        
        // An error occured while generating random data
        case randomDataError
    }
    
    static func save(password: Data, service: String, account: String) async throws {

        let query: [String: AnyObject] = [
            // kSecAttrService,  kSecAttrAccount, and kSecClass
            // uniquely identify the item to save in Keychain
            kSecAttrService as String: service as AnyObject,
            kSecAttrAccount as String: account as AnyObject,
            kSecClass as String: kSecClassGenericPassword,
            
            // kSecValueData is the item value to save
            kSecValueData as String: password as AnyObject,
        ]
        
        // SecItemAdd attempts to add the item identified by
        // the query to keychain
        let status = SecItemAdd(
            query as CFDictionary,
            nil
        )

        // errSecDuplicateItem is a special case where the
        // item identified by the query already exists. Throw
        // duplicateItem so the client can determine whether
        // or not to handle this as an error
        if status == errSecDuplicateItem {
            throw KeychainError.duplicateItem
        }

        // Any status other than errSecSuccess indicates the
        // save operation failed.
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    static func update(password: Data, service: String, account: String) throws {
        let query: [String: AnyObject] = [
            // kSecAttrService,  kSecAttrAccount, and kSecClass
            // uniquely identify the item to update in Keychain
            kSecAttrService as String: service as AnyObject,
            kSecAttrAccount as String: account as AnyObject,
            kSecClass as String: kSecClassGenericPassword
        ]
        
        // attributes is passed to SecItemUpdate with
        // kSecValueData as the updated item value
        let attributes: [String: AnyObject] = [
            kSecValueData as String: password as AnyObject
        ]
        
        // SecItemUpdate attempts to update the item identified
        // by query, overriding the previous value
        let status = SecItemUpdate(
            query as CFDictionary,
            attributes as CFDictionary
        )

        // errSecItemNotFound is a special status indicating the
        // item to update does not exist. Throw itemNotFound so
        // the client can determine whether or not to handle
        // this as an error
        guard status != errSecItemNotFound else {
            throw KeychainError.itemNotFound
        }

        // Any status other than errSecSuccess indicates the
        // update operation failed.
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    static func readPassword(service: String, account: String) throws -> Data {
        let query: [String: AnyObject] = [
            // kSecAttrService,  kSecAttrAccount, and kSecClass
            // uniquely identify the item to read in Keychain
            kSecAttrService as String: service as AnyObject,
            kSecAttrAccount as String: account as AnyObject,
            kSecClass as String: kSecClassGenericPassword,
            
            // kSecMatchLimitOne indicates keychain should read
            // only the most recent item matching this query
            kSecMatchLimit as String: kSecMatchLimitOne,

            // kSecReturnData is set to kCFBooleanTrue in order
            // to retrieve the data for the item
            kSecReturnData as String: kCFBooleanTrue
        ]

        // SecItemCopyMatching will attempt to copy the item
        // identified by query to the reference itemCopy
        var itemCopy: AnyObject?
        let status = SecItemCopyMatching(
            query as CFDictionary,
            &itemCopy
        )

        // errSecItemNotFound is a special status indicating the
        // read item does not exist. Throw itemNotFound so the
        // client can determine whether or not to handle
        // this case
        guard status != errSecItemNotFound else {
            throw KeychainError.itemNotFound
        }
        
        // Any status other than errSecSuccess indicates the
        // read operation failed.
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }

        // This implementation of KeychainInterface requires all
        // items to be saved and read as Data. Otherwise,
        // invalidItemFormat is thrown
        guard let password = itemCopy as? Data else {
            throw KeychainError.invalidItemFormat
        }

        return password
    }
    
    static func deletePassword(service: String, account: String) async throws {
        let query: [String: AnyObject] = [
            // kSecAttrService,  kSecAttrAccount, and kSecClass
            // uniquely identify the item to delete in Keychain
            kSecAttrService as String: service as AnyObject,
            kSecAttrAccount as String: account as AnyObject,
            kSecClass as String: kSecClassGenericPassword
        ]

        // SecItemDelete attempts to perform a delete operation
        // for the item identified by query. The status indicates
        // if the operation succeeded or failed.
        let status = SecItemDelete(query as CFDictionary)

        // Any status other than errSecSuccess indicates the
        // delete operation failed.
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    static func generateRandomString(length: Int) throws -> String {
        // each hexadecimal character represents 4 bits, so we need 2 hex characters per byte
        let byteCount = length / 2
        
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let result = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        guard result == errSecSuccess else {
            throw KeychainError.randomDataError
        }
        
        // convert to hex string
        let hexString = bytes.map { String(format: "%02x", $0) }.joined()
        let paddedHexString = hexString.padding(toLength: length, withPad: "0", startingAt: 0)
        return paddedHexString
    }
    
    static func createKey(password: String, archiveId: UUID) -> String {
        // Randomly generated salt to be stored in keychain
        let saltString = try! Keychain.generateRandomString(length: 64)
        
        // Convert both the password and salt to data
        let passwordData = password.data(using: .utf8)!
        let saltData = saltString.data(using: .utf8)!
        
        Task {
            // Save the salt to keychain
            try! await Keychain.save(password: saltData, service: "Locke", account: archiveId.uuidString)
        }
            
        // Build a hash to be fed into the Symetric key using the password and salt
        var hash = SHA512()
        hash.update(data: passwordData)
        hash.update(data: saltData)
        
        return hash.finalize().withUnsafeBytes {Data(Array($0)).base64EncodedString()}
    }
    
    static func deriveKey(password: String, archiveId: UUID) -> String {
        // Get the salt from keychain
        let saltData = try! Keychain.readPassword(service: "Locke", account: archiveId.uuidString)
        
        // Convert the password to data
        let passwordData = password.data(using: .utf8)!
        
        // Build a hash to be fed into the Symetric key using the password and salt
        var hash = SHA512()
        hash.update(data: passwordData)
        hash.update(data: saltData)
        
        return hash.finalize().withUnsafeBytes {Data(Array($0)).base64EncodedString()}
    }
}
