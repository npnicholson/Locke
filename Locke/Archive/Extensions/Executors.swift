//
//  ArchiveManagerExecutors.swift
//  Locke
//
//  Created by Norris Nicholson on 8/30/23.
//

import Foundation

// MARK: - Execute Functions
// Add all of the execute functions to the archive manager. Seperated to make the main manager cleaner.
// These funcs are responsible for interacting directly with the archives on disk
extension ArchiveManager {
    // Attach the archive by mounting it
    internal func executeAttach(_ archive: ArchiveData, password: String) throws -> Void {
        // If the archive does not exist, then we can't attach it
        if (!self.exists(archive)) { throw ArchiveError.archiveDoesNotExist }
        
        // Ensure that the mount and bundle urls are valid
        guard let mountURL = archive.mountURL, let bundleURL = archive.bundleURL else {
            throw ArchiveError.archiveDoesNotExist
        }
        
        // Try to attach the archive
        let operation = try executeTask(executable: hdiutil, arguments: ["attach", "-stdinpass", "-mountpoint", mountURL.path(percentEncoded: false), bundleURL.path(percentEncoded: false)], inputPipeString: password)
        
        // Log this operation
        logOperation(operation: operation)
        
        // If the operation does not work, then throw an error
        if (!operation.success) { throw ArchiveError.operationFailure(operation)}
        
        // Ensure that the archive was attached
        if (!self.attached(archive)) { throw ArchiveError.notAttached }
    }
    
    // Detach the archive by unmounting it
    internal func executeDetach(_ archive: ArchiveData) throws -> Void {
        // If the archive is not attached, then we can't detach it
        if (!self.attached(archive)) { throw ArchiveError.archiveNotAttached }
        
        // Ensure that the mount url is valid
        guard let mountURL = archive.mountURL else {
            throw ArchiveError.archiveDoesNotExist
        }
        
        // Try to detach the archive
        let operation = try executeTask(executable: hdiutil, arguments: ["detach", mountURL.path(percentEncoded: false)])
        
        // Log this operation
        logOperation(operation: operation)
        
        // Ensure that the archive was detached
        if (self.attached(archive)) { throw ArchiveError.notDetached }
    }
    
    // Compact the archive
    internal func executeCompact(_ archive: ArchiveData, password: String) throws -> Void {
        // If the archive is attached, then we can't compact it
        if (self.attached(archive)) { throw ArchiveError.archiveNotAttached }
        
        // Ensure that the bundle url is valid
        guard let bundleURL = archive.bundleURL else {
            throw ArchiveError.archiveDoesNotExist
        }
        
        // Try to compact the archive
        let operation = try executeTask(executable: hdiutil, arguments: ["compact", "-stdinpass", "-batteryallowed", bundleURL.path(percentEncoded: false)], inputPipeString: password)
        
        // Log this operation
        logOperation(operation: operation)
        
        // If the operation does not work, then throw an error
        if (!operation.success) { throw ArchiveError.operationFailure(operation)}
    }

    // Create the archive on disk as a password protected sparse bundle
    internal func executeCreate(_ archive: ArchiveData, password: String) throws -> Void {
        // If the archive already exists, then throw an error
        if (self.exists(archive)) { throw ArchiveError.archiveExists }
        
        // Ensure that the bundle url is valid
        guard let bundleURL = archive.bundleURL else {
            throw ArchiveError.archiveDoesNotExist
        }

        // Try to make the archive using hdiutil
        let operation = try executeTask( executable: hdiutil, arguments: ["create", "-type", "SPARSEBUNDLE", "-size", "\(archive.maxSize)Gb", "-fs", "Case-sensitive APFS", "-encryption", "AES-256", "-stdinpass", "-volname", archive.name ?? "unnamed", bundleURL.path(percentEncoded: false)], inputPipeString: password)
        
        // Log this operation
        logOperation(operation: operation)
        
        // If the operation does not work, then throw an error
        if (!operation.success) { throw ArchiveError.operationFailure(operation)}
        
        // Ensure that the archive was created
        if (!self.exists(archive)) { throw ArchiveError.notCreated }
    }
    
    // Remove the archive from disk
    internal func executeRemove(_ archive: ArchiveData) throws -> Void {
        // If this archive does not exist, then throw an error
        if (!self.exists(archive)) { throw ArchiveError.archiveDoesNotExist }
        
        // If the archive is attached, then we should not remove it from disk. They should detach it first
        if (self.attached(archive)) { throw ArchiveError.archiveAttached }
        
        // Ensure that the bundle url is valid
        guard let bundleURL = archive.bundleURL else {
            throw ArchiveError.archiveDoesNotExist
        }
        
        // Try to remove the archive by moving it to trash
        try fm.trashItem(at: bundleURL, resultingItemURL: nil)
        
        // Ensure that the archive was removed
        if (self.exists(archive)) { throw ArchiveError.notRemoved }
    }
    
    // Remove the archive from disk
    internal func executeBackup(_ archive: ArchiveData, _ outputURL: URL) throws -> Void {
        // If the archive doesnt exist, then throw an error
        if (!self.exists(archive)) { throw ArchiveError.archiveDoesNotExist }
        
        // If the archive is attached, then we should not back it up. They should detach it first
        if (self.attached(archive)) { throw ArchiveError.archiveAttached }
        
        // Ensure that the bundle url is valid
        guard let bundleURL = archive.bundleURL else {
            throw ArchiveError.archiveDoesNotExist
        }
        
        print ("a", bundleURL.path(percentEncoded: false), outputURL.path(percentEncoded: false))
        
        
        try! fm.copyItem(atPath: bundleURL.path(percentEncoded: false), toPath: outputURL.path(percentEncoded: false))
    }
}

func logOperation(operation: Operation) {
    if let stdout = operation.stdout {
        if (!stdout.isEmpty) {
            logger.trace(stdout)
        }
    }
    
    if let stderr = operation.stderr {
        if (!stderr.isEmpty) {
            logger.error(stderr)
        }
    }
}
