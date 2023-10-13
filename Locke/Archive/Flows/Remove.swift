//
//  Remove.swift
//  Locke
//
//  Created by Norris Nicholson on 8/30/23.
//

import Foundation
import CoreData

// MARK: - Close Archive Flow
extension ArchiveManager {
    // Start the remove archive flow with the given archive
    public func remove(_ id: NSManagedObjectID) {
        let archive = try! self.context.existingObject(with: id) as! ArchiveData

        // Make sure there is an archive id ready
        guard let archiveId = archive.id else {
            print ("No archive name given for removal!")
            return
        }
        
        do {
            // Attempt to remove the archive
            try self.executeRemove(archive)
            
            // If there was no error, then delete the archive from CoreData
            self.context.delete(archive)
            try? context.save()
            
            // Finally remove the salt from keychain
            Task {
                try await Keychain.deletePassword(service: "Locke", account: archiveId.uuidString)
            }
        } catch { }
        
        // Update the list of active archives
        self.scanArchiveMounts()
    }
}
