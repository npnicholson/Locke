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
    // Start the close archive flow with the given archive
    public func close(_ id: NSManagedObjectID) {
        // Get just the specific archive from CoreData
        let archive = try! self.context.existingObject(with: id) as! ArchiveData
        
        // Record the password hash before it is removed
        var hash: String? = nil
        if let id = archive.id {
            hash = self.openArchives[id]
        }
        
        // Attempt to close the archive by detaching it
        try? self.executeDetach(archive)

        if let id = archive.id {
            // Attempt to compact the archive
            if (UserDefaults.standard.bool(forKey: "setting.CompactOnDetach")) {
                if let hash = hash {
                    try? self.executeCompact(archive, password: hash)
                }
            }
            
            // Remove this archive from our list of open archives
            self.openArchives[id] = nil
        }
        
        // Update the list of active archives
        self.scanArchiveMounts()
    }
}
