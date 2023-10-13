//
//  Show.swift
//  Locke
//
//  Created by Norris Nicholson on 8/30/23.
//

import Foundation
import AppKit
import CoreData


// MARK: - Close Archive Flow
extension ArchiveManager {
    // Start the close archive flow with the given archive
    public func show(_ id: NSManagedObjectID) {
        // Get just the specific archive from CoreData
        let archive = try! self.context.existingObject(with: id) as! ArchiveData
        
        // Show the archive in finder
        NSWorkspace.shared.selectFile(archive.mountURL?.path(percentEncoded: false), inFileViewerRootedAtPath: "")
    }
}
