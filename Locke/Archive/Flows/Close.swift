//
//  Close.swift
//  Locke
//
//  Created by Norris Nicholson on 8/30/23.
//

import Foundation
import CoreData

// MARK: - Close Archive Flow
extension ArchiveManager {
    // Start the close archive flow with the given archive. Closing runs in the background
    public func close(_ objectId: NSManagedObjectID) {
        Task { @MainActor in
            await self.closeArchive(objectId)
        }
    }

    @MainActor
    private func closeArchive(_ objectId: NSManagedObjectID) async {
        guard let archive = self.archive(objectId) else { return }
        
        // Record the password hash before it is removed
        var hash: String? = nil
        if let id = archive.id {
            hash = self.openArchives[id]
        }
        
        // Attempt to close the archive by detaching it
        do {
            try await self.executeDetach(archive)
        } catch {
            presentError("Unable to close '\(archive.name ?? "archive")'", error)
            self.scanArchiveMounts()
            return
        }

        if let id = archive.id {
            // Remove this archive from our list of open archives
            self.openArchives[id] = nil

            // Attempt to compact the archive
            if (UserDefaults.standard.bool(.compactOnDetach)), let hash = hash {
                startOperationProgress(archive: archive)
                do {
                    try await self.executeCompact(archive, password: hash)
                } catch {
                    // The archive is closed and safe; compacting only reclaims space, so just log it
                    logger.error("Unable to compact '\(archive.name ?? "archive")': \(error.localizedDescription)")
                }
                stopOperationProgress(archive: archive)
            }
        }
        
        // Update the list of active archives
        self.scanArchiveMounts()
    }
}
