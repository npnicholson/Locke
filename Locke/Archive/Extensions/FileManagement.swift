//
//  FileManagement.swift
//  Locke
//
//  Created by Norris Nicholson on 8/30/23.
//

import Foundation

// MARK: - Directory and FileManager Functions
// Add all of the directory and filemanager functions to the archive manager. Seperated to make
// the main manager cleaner.
extension ArchiveManager {
    // Get the date the archive was last saved to disk
    public func modified(_ archive: ArchiveData) throws -> Date{
        // Ensure that the mount and bundle urls are valid
        guard let bundleURL = archive.bundleURL else {
            throw ArchiveError.archiveDoesNotExist
        }
        
        if let date = directoryModified(url: bundleURL) {
            return date
        } else {
            return Date()
        }
    }
    
    // See if this archive exists on disk as a sparsebundle
    public func exists(_ archive: ArchiveData) -> Bool {
        if let url = archive.bundleURL {
            return fm.fileExists(atPath: url.path(percentEncoded: false), isDirectory: nil)
        }
        return false
    }

    // See if this archive is attached (mounted)
    public func attached(_ archive: ArchiveData) -> Bool {
        if let url = archive.mountURL {
            return fm.fileExists(atPath: url.path(percentEncoded: false), isDirectory: nil)
        }
        return false
    }
}
