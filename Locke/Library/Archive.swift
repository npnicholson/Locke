//
//  Archive.swift
//  Locke
//
//  Created by Norris Nicholson on 8/14/23.
//

import Foundation
import SwiftUI
import SFSafeSymbols

// TODO: Remove


//class DirectoryObserver {
//
//    private let fileDescriptor: CInt
//    private let source: DispatchSourceProtocol
//
//    deinit {
//
//      self.source.cancel()
//      close(fileDescriptor)
//    }
//
//    init(URL: URL, block: @escaping ()->Void) {
//
//      self.fileDescriptor = open(URL.path, O_EVTONLY)
//      self.source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: self.fileDescriptor, eventMask: .all, queue: DispatchQueue.global())
//      self.source.setEventHandler {
//          block()
//      }
//      self.source.resume()
//  }
//
//}

//func directoryExists(url: URL) -> Bool {
//    var isDirectory : ObjCBool = true
//    let exists = FileManager.default.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory)
//    return exists && isDirectory.boolValue
//}

/// Class for managing an individual Archive
//class Archive: CustomStringConvertible, ObservableObject, Hashable {
//    static func == (lhs: Archive, rhs: Archive) -> Bool {
//        return lhs.id == rhs.id
//    }
//    func hash(into hasher: inout Hasher) {
//        hasher.combine(self.id)
//    }
//    
//    
//    static func toData(context: NSManagedObjectContext, archive: Archive) {
//        let archiveData = ArchiveData(context: context)
//        archiveData.id = archive.id
//        archiveData.name = archive.name
//        archiveData.bundleURL = archive.bundleURL
//        archiveData.mountURL = archive.mountURL
//        archiveData.maxSize = archive.maxSize
//        archiveData.favorite = archive.favorite
//        archiveData.order = archive.order
//        archiveData.icon = archive.icon
//        try? context.save()
//    }
//    
//    static func fromData(data: ArchiveData) -> Archive {
//        return Archive(
//            id: data.id ?? UUID(),
//            name: data.name ?? "Unnamed",
//            bundleURL: data.bundleURL,
//            mountURL: data.mountURL,
//            maxSize: data.maxSize,
//            favorite: data.favorite,
//            order: data.order,
//            icon: data.icon ??  SFSymbol.folderFill.rawValue
//        )
//    }
//    
//    // Decoded Variables
//    let id: UUID
//    let name: String
//    let bundleURL: URL
//    let mountURL: URL
//    let maxSize: Int16
//    var favorite: Bool
//    var order: Int16
//    var icon: String
//    
//    @Published var pubAttached: Bool = false
//    @Published var pubSize: Int64 = 0
//    
//    // Non-decoded Variables
//    var password: String?
//    var operation: Operation
//    
//    // Standard Init
//    init(id: UUID = UUID(), name: String, bundleURL: URL? = nil, mountURL: URL? = nil, maxSize: Int16? = nil, favorite: Bool? = nil, order: Int16? = nil, icon: String? = nil) {
//        self.id = id
//        self.name = name
//        self.bundleURL = bundleURL ?? defaultArchiveBundleURL(id: id)
//        self.mountURL = mountURL ?? defaultArchiveMountURL(id: id)
//        self.maxSize = maxSize ?? 16
//        self.favorite = favorite ?? false
//        self.order = order ?? 0
//        self.icon = icon ?? SFSymbol.folderFill.rawValue
//        
//        // Blank operation standin
//        self.operation = Operation(code: 0, success: true, stdout: "")
//        
//        // Grab and store state values
//        let _ = self.attached
//        let _ = self.size
//    }
//    
//    // CustomStringConvertible Implementation
//    public var description: String {
//        return "\(name) [\(self.password == nil ? "No Password" : "Password")] | Bundle:\(bundleURL.path(percentEncoded: false)); Mount:\(mountURL.path(percentEncoded: false))"
//    }
//    
//    /// Gets the date at which this archive was last modified
//    public var modified: Date {
//        if let date = directoryModified(url: self.bundleURL) {
//            return date
//        } else {
//            return Date()
//        }
//    }
//    
//    /// Get the size of this archive in bytes
//    public var size: Int64 {
//        self.pubSize = directorySize(url: self.bundleURL)
//        return self.pubSize
//    }
//    
//    /// See if this archive exists on disk as a sparsebundle
//    public var exists: Bool {
//        return fm.fileExists(atPath: self.bundleURL.path(percentEncoded: false), isDirectory: nil)
//    }
//    
//    /// See if this archive is attached (mounted)
//    public var attached: Bool {
//        self.pubAttached = fm.fileExists(atPath: self.mountURL.path(percentEncoded: false), isDirectory: nil)
//        return self.pubAttached
//    }
//    
//    /// Attach this archive by mounting it
//    public func attach() throws -> Void {
//        // If the archive does not exist, then we can't attach it
//        if (!self.exists) { throw ArchiveError.archiveDoesNotExist }
//        
//        // Make sure we have a valid password to use
//        if (self.password == nil) { throw ArchiveError.noPasswordProvided }
//        
//        // Try to attach the archive
//        self.operation = try executeTask(executable: hdiutil, arguments: ["attach", "-stdinpass", "-mountpoint", self.mountURL.path(percentEncoded: false), self.bundleURL.path(percentEncoded: false)], inputPipeString: self.password)
//        
//        // If the operation does not work, then throw an error
//        if (!self.operation.success) { throw ArchiveError.operationFailure(self.operation)}
//        
//        // Ensure that the archive was attached
//        if (!self.attached) { throw ArchiveError.notAttached }
//        
//        // Clear the password from memory if everything went well
//        self.password = nil
//    }
//    
//    /// Detach this archive by unmounting it
//    public func detach() throws -> Void {
//        // If the archive is not attached, then we can't detach it
//        if (!self.attached) { throw ArchiveError.archiveNotAttached }
//        
//        // Try to detach the archive
//        self.operation = try executeTask(executable: hdiutil, arguments: ["detach", self.mountURL.path(percentEncoded: false)])
//        
//        // Ensure that the archive was detached
//        if (self.attached) { throw ArchiveError.notDetached }
//
//        // If we have the password for this archive, then compact the archive
//        if (self.password != nil) {
//            try self.compact()
//        } else {
//            print ("Skipping Compact - no password")
//        }
//    }
//    
//    public func compact() throws -> Void {
//        // If the archive is attached, then we can't compact it
//        if (self.attached) { throw ArchiveError.archiveNotAttached }
//        
//        // Try to compact the archive
//        self.operation = try executeTask(executable: hdiutil, arguments: ["compact", "-stdinpass", "-batteryallowed", self.bundleURL.path(percentEncoded: false)], inputPipeString: self.password)
//        
//        // If the operation does not work, then throw an error
//        if (!self.operation.success) { throw ArchiveError.operationFailure(self.operation)}
//    }
//
//    /// Create this archive on disk as a password protected sparse bundle
//    public func create() throws -> Void {
//        // If the archive already exists, then throw an error
//        if (self.exists) { throw ArchiveError.archiveExists }
//        
//        // Make sure we have a valid password to use
//        if (self.password == nil) { throw ArchiveError.noPasswordProvided }
//
//        // Try to make the archive using hdiutil
//        self.operation = try executeTask( executable: hdiutil, arguments: ["create", "-type", "SPARSEBUNDLE", "-size", "\(self.maxSize)Gb", "-fs", "Case-sensitive APFS", "-encryption", "AES-256", "-stdinpass", "-volname", self.name, self.bundleURL.path(percentEncoded: false)], inputPipeString: self.password)
//        
//        // If the operation does not work, then throw an error
//        if (!self.operation.success) { throw ArchiveError.operationFailure(self.operation)}
//        
//        // Ensure that the archive was created
//        if (!self.exists) { throw ArchiveError.notCreated }
//    }
//    
//    /// Remove the archive from disk
//    public func remove() throws -> Void {
//        // If this archive does not exist, then throw an error
//        if (!self.exists) { throw ArchiveError.archiveDoesNotExist }
//        
//        // If the archive is attached, then we should not remove it from disk. They should detach it first
//        if (self.attached) { throw ArchiveError.archiveAttached }
//        
//        // Try to remove the archive by moving it to trash
//        try fm.trashItem(at: self.bundleURL, resultingItemURL: nil)
//        
//        // Ensure that the archive was removed
//        if (self.exists) { throw ArchiveError.notRemoved }
//    }
//}
