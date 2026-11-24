//
//  Show.swift
//  Locke
//
//  Created by Norris Nicholson on 8/30/23.
//

import Foundation
import AppKit
import CoreData


// MARK: - Show Archive Flow
extension ArchiveManager {
    // Show the mount url by opening it in Finder
    public func show(_ id: NSManagedObjectID) {
        guard let archive = self.archive(id) else { return }
        
        // Show the archive in finder
        NSWorkspace.shared.selectFile(archive.mountURL?.path(percentEncoded: false), inFileViewerRootedAtPath: "")
    }
    
    // Show the bundle url by opening it in Finder
    public func showBundle(_ id: NSManagedObjectID) {
        guard let archive = self.archive(id) else { return }
        
        // Show the archive in finder
        NSWorkspace.shared.selectFile(archive.bundleURL?.path(percentEncoded: false), inFileViewerRootedAtPath: "")
    }
}
