//
//  ArchiveManagerExecutors.swift
//  Locke
//
//  Created by Norris Nicholson on 8/30/23.
//

import Foundation

// MARK: - Execute Functions
// Add all of the execute functions to the archive manager. Seperated to make the main manager cleaner.
// These funcs are responsible for interacting directly with the archives on disk. They run on the main
// actor (they read Core Data objects) but the slow hdiutil and file work happens off the main thread
extension ArchiveManager {
    // Attach the archive by mounting it
    @MainActor
    internal func executeAttach(_ archive: ArchiveData, password: String) async throws {
        // If the archive does not exist, then we can't attach it
        if (!self.exists(archive)) { throw ArchiveError.archiveDoesNotExist }
        
        // Ensure that the mount and bundle urls are valid
        guard let mountURL = archive.mountURL, let bundleURL = archive.bundleURL else {
            throw ArchiveError.archiveDoesNotExist
        }
        
        // Try to attach the archive
        let operation = try await runTask(executable: hdiutil, arguments: ["attach", "-stdinpass", "-mountpoint", mountURL.path(percentEncoded: false), bundleURL.path(percentEncoded: false)], inputPipeString: password)
        logOperation(operation: operation)
        
        // If the operation does not work, then throw an error
        if (!operation.success) { throw ArchiveError.operationFailure(operation) }
        
        // Ensure that the archive was attached
        if (!self.attached(archive)) { throw ArchiveError.notAttached }
    }
    
    // Detach the archive by unmounting it
    @MainActor
    internal func executeDetach(_ archive: ArchiveData) async throws {
        // If the archive is not attached, then we can't detach it
        if (!self.attached(archive)) { throw ArchiveError.archiveNotAttached }
        
        // Ensure that the mount url is valid
        guard let mountURL = archive.mountURL else {
            throw ArchiveError.archiveDoesNotExist
        }
        
        // Try to detach the archive
        let operation = try await runTask(executable: hdiutil, arguments: ["detach", mountURL.path(percentEncoded: false)])
        logOperation(operation: operation)
        
        // Ensure that the archive was detached
        if (self.attached(archive)) {
            throw operation.success ? ArchiveError.notDetached : ArchiveError.operationFailure(operation)
        }
    }
    
    // Compact the archive
    @MainActor
    internal func executeCompact(_ archive: ArchiveData, password: String) async throws {
        // If the archive is attached, then we can't compact it
        if (self.attached(archive)) { throw ArchiveError.archiveAttached }
        
        // Ensure that the bundle url is valid
        guard let bundleURL = archive.bundleURL else {
            throw ArchiveError.archiveDoesNotExist
        }
        
        // Try to compact the archive
        let operation = try await runTask(executable: hdiutil, arguments: ["compact", "-stdinpass", "-batteryallowed", "-puppetstrings", bundleURL.path(percentEncoded: false)], inputPipeString: password)
        logOperation(operation: operation)
        
        // If the operation does not work, then throw an error
        if (!operation.success) { throw ArchiveError.operationFailure(operation) }
    }

    // Create the archive on disk as a password protected sparse bundle
    @MainActor
    internal func executeCreate(_ archive: ArchiveData, password: String) async throws {
        // If the archive already exists, then throw an error
        if (self.exists(archive)) { throw ArchiveError.archiveExists }
        
        // Ensure that the bundle url is valid
        guard let bundleURL = archive.bundleURL else {
            throw ArchiveError.archiveDoesNotExist
        }

        // Try to make the archive using hdiutil
        let operation = try await runTask(executable: hdiutil, arguments: ["create", "-type", "SPARSEBUNDLE", "-size", "\(archive.maxSize)Gb", "-fs", "Case-sensitive APFS", "-encryption", "AES-256", "-stdinpass", "-volname", archive.name ?? "unnamed", bundleURL.path(percentEncoded: false)], inputPipeString: password)
        logOperation(operation: operation)
        
        // If the operation does not work, then throw an error
        if (!operation.success) { throw ArchiveError.operationFailure(operation) }
        
        // Ensure that the archive was created
        if (!self.exists(archive)) { throw ArchiveError.notCreated }
    }
    
    // Remove the archive from disk by moving it to the trash
    internal func executeRemove(_ archive: ArchiveData) throws {
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
    
    // Copy the archive's bundle to the given location
    @MainActor
    internal func executeBackup(_ archive: ArchiveData, _ outputURL: URL) async throws {
        // If the archive doesnt exist, then throw an error
        if (!self.exists(archive)) { throw ArchiveError.archiveDoesNotExist }
        
        // If the archive is attached, then we should not back it up. They should detach it first
        if (self.attached(archive)) { throw ArchiveError.archiveAttached }
        
        // Ensure that the bundle url is valid
        guard let bundleURL = archive.bundleURL else {
            throw ArchiveError.archiveDoesNotExist
        }
        
        // Copying a large bundle takes a while, so do it off the main thread
        try await Task.detached(priority: .userInitiated) {
            try FileManager.default.copyItem(at: bundleURL, to: outputURL)
        }.value
    }
}

func logOperation(operation: Operation) {
    if let stdout = operation.stdout, !stdout.isEmpty {
        logger.trace(stdout)
    }
    if let stderr = operation.stderr, !stderr.isEmpty {
        logger.error(stderr)
    }
}
