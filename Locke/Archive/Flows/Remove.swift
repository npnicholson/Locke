//
//  Remove.swift
//  Locke
//
//  Created by Norris Nicholson on 8/30/23.
//

import Foundation
import CoreData

// MARK: - Remove Archive Flow
extension ArchiveManager {
    // Start the remove archive flow with the given archive
    public func remove(_ id: NSManagedObjectID) {
        guard let archive = self.archive(id), let archiveId = archive.id else { return }
        
        do {
            // Attempt to remove the archive
            try self.executeRemove(archive)
        } catch {
            presentError("Unable to remove '\(archive.name ?? "archive")'", error)
            return
        }

        // The bundle is in the trash, so delete the archive from Core Data
        self.context.delete(archive)
        self.saveContext()

        // Finally remove the salt from keychain. The archive is already gone, so only log a failure
        do {
            try Keychain.deleteKey(archiveId: archiveId)
        } catch {
            logger.error("Unable to remove Keychain salt for removed archive \(archiveId): \(error.localizedDescription)")
        }
        
        // Update the list of active archives
        self.scanArchiveMounts()
    }
}
