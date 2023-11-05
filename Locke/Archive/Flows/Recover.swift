//
//  Recover.swift
//  Locke
//
//  Created by Norris Nicholson on 10/30/23.
//

import Foundation
import CoreData
import CryptoKit

// MARK: - Open Archive Flow
extension ArchiveManager {
    
    // Start the open archive flow with the given archive
    public func recover(_ objectId: NSManagedObjectID) {
        // Get just the specific archive from CoreData
        let archive = try! self.context.existingObject(with: objectId) as! ArchiveData
        
        if (!archive.attached) {
            
            // Activate the passwordPromptManager
            self.passwordPromptManager.activate(self.recoverHandle, archive: archive,
                                                title: "Locke: Enter your recovery Key.",
                                                subtitle: "Please enter the recovery key for '\(archive.name ?? "Unknown")'.",
                                                prompt: "This key was generated when the archive was created.", data: nil)
            
            // Activate Locke if it is not already. This will force the user to interact with the new password prompt
            self.lockeDelegate.activate()
        }
    }
    
    private func recoverHandle(_ result: PromptResult, _ archive: ArchiveData, _ key: String, _ data: Any) -> Bool {
        if (result == .cancled) { return false }
        guard let archiveId = archive.id else { return false }
        do {
            
            // Attach the archive
            try self.executeAttach(archive, password: key)
            
            // Note it as open for recordkeeping
            self.openArchives[archiveId] = key
            
            // Update the list of mounted archives
            self.scanArchiveMounts()
            
            return true
        } catch {
            return false
        }
    }
}
