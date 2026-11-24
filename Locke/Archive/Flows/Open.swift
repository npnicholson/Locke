//
//  Open.swift
//  Locke
//
//  Created by Norris Nicholson on 8/30/23.
//

import Foundation
import CoreData

// MARK: - Open Archive Flow
extension ArchiveManager {
    
    // Start the open archive flow with the given archive
    public func open(_ objectId: NSManagedObjectID) {
        guard let archive = self.archive(objectId) else { return }
        
        if (archive.noPassword == true) {
            Task { @MainActor in
                _ = await self.openHandler(.submitted, archive, "", objectId)
            }
        } else {
            // The second line prompt of the password prompt dialog
            let prompt = "This archive will remain open until it is closed."
            
            // Activate the passwordPromptManager
            self.passwordPromptManager.activate(self.openHandler, archive: archive, prompt: prompt, data: objectId)
            
            // Activate Locke if it is not already. This will force the user to interact with the new password prompt
            self.lockeDelegate.activate()
        }
    }
    
    // Returns false to keep the prompt open (wrong password). Errors other than a failed attach are shown to the user
    @MainActor
    private func openHandler(_ result: PromptResult, _ archive: ArchiveData, _ password: String, _ data: Any?) async -> Bool {
        if (result == .cancelled) {
            return false
        }
        
        guard let archiveId = archive.id else {
            return false
        }
        
        // Calculate the password for this archive
        let hashString: String
        do {
            hashString = try Keychain.deriveKey(password: password, archiveId: archiveId)
        } catch {
            presentError("Unable to read the key for '\(archive.name ?? "archive")'", error,
                         message: "The archive's salt could not be read from Keychain (\(error.localizedDescription)). Use Recover with the recovery key instead.")
            return true
        }
        
        do {
            // Attach the archive
            try await self.executeAttach(archive, password: hashString)
        } catch {
            // Most failures here are a wrong password; keep the prompt open so the user can retry
            logger.error("Unable to open '\(archive.name ?? "archive")': \(error.localizedDescription)")
            return false
        }
        
        // Note it as open for recordkeeping
        self.openArchives[archiveId] = hashString
        
        // Update the list of mounted archives
        self.scanArchiveMounts()
        
        // Show the open archive
        if let objectId = data as? NSManagedObjectID {
            self.show(objectId)
        }
        
        // Close the main window if it is open so the focus can be on the newly opened archive
        self.lockeDelegate.mainWindow.close()
        
        return true
    }
}
