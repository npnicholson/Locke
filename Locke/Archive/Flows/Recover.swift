//
//  Recover.swift
//  Locke
//
//  Created by Norris Nicholson on 10/30/23.
//

import Foundation
import CoreData

// MARK: - Recover Archive Flow
extension ArchiveManager {
    
    // Start the recover flow, which opens the archive using its recovery key instead of the password
    public func recover(_ objectId: NSManagedObjectID) {
        guard let archive = self.archive(objectId), !archive.attached else { return }
        
        // Activate the passwordPromptManager
        self.passwordPromptManager.activate(self.recoverHandler, archive: archive,
                                            title: "Locke: Enter your recovery Key.",
                                            subtitle: "Please enter the recovery key for '\(archive.name ?? "Unknown")'.",
                                            prompt: "This key was generated when the archive was created.", data: nil)
        
        // Activate Locke if it is not already. This will force the user to interact with the new password prompt
        self.lockeDelegate.activate()
    }
    
    @MainActor
    private func recoverHandler(_ result: PromptResult, _ archive: ArchiveData, _ key: String, _ data: Any?) async -> Bool {
        if (result == .cancelled) { return false }
        guard let archiveId = archive.id else { return false }
        do {
            // Attach the archive
            try await self.executeAttach(archive, password: key)
        } catch {
            logger.error("Unable to recover '\(archive.name ?? "archive")': \(error.localizedDescription)")
            return false
        }
        
        // Note it as open for recordkeeping
        self.openArchives[archiveId] = key
        
        // Update the list of mounted archives
        self.scanArchiveMounts()
        
        return true
    }
}
