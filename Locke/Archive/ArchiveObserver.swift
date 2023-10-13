//
//  ArchiveObserver.swift
//  Locke
//
//  Created by Norris Nicholson on 8/30/23.
//

import Foundation
import CoreData
import AppKit

// Class that is responsible for observing and updating archives as they are mounted and unmounted
class ArchiveObserver {
    
    // The two observers that are set up by this class
    private var mountObserver: NSObjectProtocol? = nil
    private var unmountObserver: NSObjectProtocol? = nil
    
    // A reference to the global context for CoreData storage
    private let context: NSManagedObjectContext
    
    // Handler that is called after an archive is mounted or unmounted
    public var handler: (() -> Void)?
    
    init(context: NSManagedObjectContext, handler: (() -> Void)? = nil) {
        self.context = context
        self.handler = handler
        
        // Set up the observers to watch for mounts and unmounts
        mountObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didMountNotification, object: NSWorkspace.shared, queue: nil, using: self.mounted)
        unmountObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didUnmountNotification, object: NSWorkspace.shared, queue: nil, using: self.unmounted)
    }
    
    // On deinit, remove the observers
    deinit {
        if let mount = self.mountObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(mount)
            self.mountObserver = nil
        }
        if let unmount = self.unmountObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(unmount)
            self.unmountObserver = nil
        }
    }
    
    // Called when any drive is mounted
    private func mounted(_ notification: Notification) {
        if let devicePath = notification.userInfo!["NSDevicePath"] as? String {
            // Get all of the archives from core data
            let archives: [ArchiveData] = try! self.context.fetch(globalArchiveFetchRequest)
            
            // Flag to tell us if we need to store core data later
            var contextChanged = false
            
            archives.forEach { archive in
                // Ensure that the drive that was mounted was one of Locke's archives
                if (devicePath == archive.mountURL?.path(percentEncoded: false)) {
                    
                    // If it is, note it as attached and run the compleation handler
                    archive.attached = true
                    archive.lastOpened = Date()
                    contextChanged = true
                    if let handler = self.handler {
                        handler()
                    }
                }
            }
            
            // If the context was changed then save it
            if (contextChanged) {
                try? self.context.save()
            }
        }
    }
    
    // Called when any drive is unmounted
    private func unmounted(_ notification: Notification) {
        if let devicePath = notification.userInfo!["NSDevicePath"] as? String {
            // Get all of the archives from core data
            let archives: [ArchiveData] = try! self.context.fetch(globalArchiveFetchRequest)
            
            // Flag to tell us if we need to store core data later
            var contextChanged = false
            
            archives.forEach { archive in
                // Ensure that the drive that was mounted was one of Locke's archives
                if (devicePath == archive.mountURL?.path(percentEncoded: false)) {
                    
                    // If it is, note it as detached and update the archives size. Then run the
                    // compleation handler
                    archive.attached = false
                    if let url = archive.bundleURL {
                        archive.size = directorySize(url: url)
                        archive.modified = directoryModified(url: url)
                    }
                    if let handler = self.handler {
                        handler()
                    }
                    contextChanged = true
                }
            }
            
            // If the context was changed then save it
            if (contextChanged) {
                try? self.context.save()
            }
        }
    }
}
