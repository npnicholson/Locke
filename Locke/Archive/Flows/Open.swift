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
        
        // The second line prompt of the password prompt dialog
        let prompt = "This archive will remain open until it is closed."
        
        // Activate the passwordPromptManager
        self.passwordPromptManager.activate(self.openHandler, archive: archive, prompt: prompt)
        
        // Activate Locke if it is not already. This will force the user to interact with the new password prompt
        self.lockeDelegate.activate()
    }
    
    private func openHandler(_ result: PromptResult, _ archive: ArchiveData, _ password: String) -> Bool {
        if (result == .cancled) {
            return false
        }
        
        guard let archiveId = archive.id else {
            return false
        }
        
        do {
            let hashString = Keychain.deriveKey(password: password, archiveId: archiveId)
            
            try self.executeAttach(archive, password: hashString)
            
            // Update the lsit of mounted archives
            self.scanArchiveMounts()
            return true
        } catch {
            return false
        }
        
    }
}
