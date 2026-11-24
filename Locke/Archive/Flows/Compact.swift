//
//  Compact.swift
//  Locke
//
//  Created by Norris Nicholson on 8/30/23.
//

import Foundation
import CoreData

// MARK: - Compact Archive Flow
extension ArchiveManager {
    // Start the compact archive flow with the given archive
    public func compact(_ objectId: NSManagedObjectID) {
        guard let archive = self.archive(objectId) else { return }
        
        // The second line prompt of the password prompt dialog
        let prompt = "This will compact the archive and store it back to disk."
        
        // Activate the passwordPromptManager
        self.passwordPromptManager.activate(self.compactHandler, archive: archive, prompt: prompt)
        
        // Activate Locke if it is not already. This will force the user to interact with the new password prompt
        self.lockeDelegate.activate()
    }
    
    // Receive data from the password prompt and compact the archive
    @MainActor
    private func compactHandler(_ result: PromptResult, _ archive: ArchiveData, _ password: String, _ data: Any?) async -> Bool {
        if (result == .cancelled) {
            return false
        }
        
        guard let id = archive.id else {
            return false
        }
        
        do {
            // Calculate the password for this archive
            let hashString = try Keychain.deriveKey(password: password, archiveId: id)
            
            // Compact the archive
            startOperationProgress(archive: archive)
            defer { stopOperationProgress(archive: archive) }
            try await self.executeCompact(archive, password: hashString)
        } catch {
            // A wrong password also fails here; keep the prompt open so the user can retry
            logger.error("Unable to compact '\(archive.name ?? "archive")': \(error.localizedDescription)")
            return false
        }
        
        // Update the size of the archive
        if let bundleURL = archive.bundleURL {
            archive.size = directorySize(url: bundleURL)
            self.saveContext()
        }
        
        // Update the list of active archives
        self.scanArchiveMounts()
        return true
    }
}
