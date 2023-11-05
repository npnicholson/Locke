//
//  Open.swift
//  Locke
//
//  Created by Norris Nicholson on 8/30/23.
//

import Foundation
import CoreData
import CryptoKit

// MARK: - Open Archive Flow
extension ArchiveManager {
    
    // Start the open archive flow with the given archive
    public func open(_ objectId: NSManagedObjectID) {
        // Get just the specific archive from CoreData
        let archive = try! self.context.existingObject(with: objectId) as! ArchiveData
        
        if (archive.noPassword == true) {
            let _ = openHandler(.submitted, archive, "", objectId)
        } else {
            // The second line prompt of the password prompt dialog
            let prompt = "This archive will remain open until it is closed."
            
            // Activate the passwordPromptManager
            self.passwordPromptManager.activate(self.openHandler, archive: archive, prompt: prompt, data: objectId)
            
            // Activate Locke if it is not already. This will force the user to interact with the new password prompt
            self.lockeDelegate.activate()
        }
    }
    
    private func openHandler(_ result: PromptResult, _ archive: ArchiveData, _ password: String, _ data: Any) -> Bool {
        if (result == .cancled) {
            return false
        }
        
        guard let archiveId = archive.id else {
            return false
        }
        
        do {
            // Calculate the password for this archive
            let hashString = Keychain.deriveKey(password: password, archiveId: archiveId)
            
            // Attach the archive
            try self.executeAttach(archive, password: hashString)
            
            // Note it as open for recordkeeping
            self.openArchives[archiveId] = hashString
            
            // Update the list of mounted archives
            self.scanArchiveMounts()
            
            // Show the open archive
            self.show(data as! NSManagedObjectID)
            
            // Close the main window if it is open so the focus can be on the newly opened archive
            self.lockeDelegate.mainWindow.close()
            
            return true
        } catch {
            return false
        }
        
    }
}
