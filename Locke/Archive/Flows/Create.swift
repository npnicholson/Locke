//
//  Create.swift
//  Locke
//
//  Created by Norris Nicholson on 8/30/23.
//

import Foundation
import CoreData
import CryptoKit

struct ArchiveDataAndKey {
    let archive: ArchiveData
    let key: String
}

// MARK: - Create Archive Flow
extension ArchiveManager {
    public func create(name: String, password: String, maxSize: Int16 = 1024) throws -> ArchiveDataAndKey {
        
        // Create a stub archive within the core data context
        let archive = ArchiveData(context: self.context)
        
        // Make an ID and bundle/mount urls for this archive
        let archiveId = UUID()
        let bundleURL = defaultArchiveBundleURL(id: archiveId)
        let mountURL = defaultArchiveMountURL(id: archiveId)
        
        // Store the ID and bundle/mount urls
        archive.id = archiveId
        archive.bundleURL = bundleURL
        archive.mountURL = mountURL
        
        // Set up initial values
        archive.attached = false
        archive.favorite = false
        archive.lastOpened = Date.distantPast
        archive.maxSize = maxSize
        archive.modified = Date.distantPast
        archive.name = name
        archive.created = Date()
        archive.size = 0
        
        let hashString = Keychain.createKey(password: password, archiveId: archiveId)
        
        print ("Hash String: Store in Lastpass: \(hashString)")
        
        do {
            try self.executeCreate(archive, password: hashString)
            archive.size = directorySize(url: bundleURL)
            archive.modified = directoryModified(url: bundleURL)
            
            try self.context.save()
            
        } catch {
            // TODO: Throw error here
        }
        
        return ArchiveDataAndKey(archive: archive, key: hashString)
    }
}
