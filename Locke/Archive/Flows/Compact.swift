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
    // Start the open archive flow with the given archive
    public func compact(_ objectId: NSManagedObjectID) {
        // Get just the specific archive from CoreData
        let archive = try! self.context.existingObject(with: objectId) as! ArchiveData
        
        // The second line prompt of the password prompt dialog
        let prompt = "This will compact the archive and store it back to disk."
        
        // Activate the passwordPromptManager
        self.passwordPromptManager.activate(self.compactHandler, archive: archive, prompt: prompt)
        
        // Activate Locke if it is not already. This will force the user to interact with the new password prompt
        self.lockeDelegate.activate()
    }
    
    // Receive data from the password prompt and compact the archive
    private func compactHandler(_ result: PromptResult, _ archive: ArchiveData, _ password: String) -> Bool {
        if (result == .cancled) {
            return false
        }
        
        do {
            try self.executeCompact(archive, password: password)
            return true
        } catch {
            return false
        }
    }
}
