//
//  Create.swift
//  Locke
//
//  Created by Norris Nicholson on 8/30/23.
//

import Foundation
import CoreData

struct ArchiveDataAndKey {
    let archive: ArchiveData
    let key: String
}

// MARK: - Create Archive Flow
extension ArchiveManager {
    // Create a new archive on disk and in Core Data. Throws, leaving nothing behind, if any step fails
    @MainActor
    public func create(name: String, password: String, bundleURL: URL? = nil, mountURL: URL? = nil, maxSize: Int16 = 1024) async throws -> ArchiveDataAndKey {
        
        // Create a stub archive within the core data context
        let archive = ArchiveData(context: self.context)
        
        // Make an ID and bundle/mount urls for this archive
        let archiveId = UUID()
        let bundleURL = bundleURL ?? defaultArchiveBundleURL(id: archiveId)
        let mountURL = mountURL ?? defaultArchiveMountURL(id: archiveId)
        
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
        archive.noPassword = password.count == 0
        
        do {
            let hashString = try Keychain.createKey(password: password, archiveId: archiveId)
            try await self.executeCreate(archive, password: hashString)

            archive.size = directorySize(url: bundleURL)
            archive.modified = directoryModified(url: bundleURL)
            try self.context.save()

            return ArchiveDataAndKey(archive: archive, key: hashString)
        } catch {
            // Roll back: drop the Core Data stub and the stored salt so no half-created archive remains
            self.context.delete(archive)
            try? Keychain.deleteKey(archiveId: archiveId)
            throw error
        }
    }
}
