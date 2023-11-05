//
//  Backup.swift
//  Locke
//
//  Created by Norris Nicholson on 11/02/23.
//

import Foundation
import AppKit
import CoreData
import UniformTypeIdentifiers

// MARK: - Close Archive Flow
extension ArchiveManager {
    // Show the mount url by opening it in Finder
    public func backup(_ id: NSManagedObjectID) {
        // Get just the specific archive from CoreData
        let archive = try! self.context.existingObject(with: id) as! ArchiveData
        
        guard let name = archive.name else { return }
        
        let savePanel = NSSavePanel()
        
        savePanel.title = "Backup '\(name)'"
        savePanel.showsTagField = false
        savePanel.showsHiddenFiles = true
        savePanel.directoryURL = fm.homeDirectoryForCurrentUser
        savePanel.level = .popUpMenu
        savePanel.prompt = "Copy Archive"
        savePanel.nameFieldStringValue = "\(name).sparsebundle"
        
        
        
        savePanel.allowedContentTypes = [UTType.bundle]
        savePanel.allowsOtherFileTypes = false
        
        savePanel.begin { response in
            if response == .OK, let destinationUrl = savePanel.url {
                print (destinationUrl)
                try? self.executeBackup(archive, destinationUrl)
            }
        }
    }
}
