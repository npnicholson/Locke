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
        
        // Attempt to close the archive by detaching it
        try? self.executeDetach(archive)
        
        // Update the list of active archives
        self.scanArchiveMounts()
    }
}
