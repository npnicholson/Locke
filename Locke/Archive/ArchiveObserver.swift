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
    
    // A reference to the archive manager
    public var manager: ArchiveManager! = nil
    
    // Handler that is called after an archive is mounted or unmounted
    public var handler: (() -> Void)?
    
    init(context: NSManagedObjectContext, handler: (() -> Void)? = nil) {
        self.context = context
        self.handler = handler
        
        // Set up the observers to watch for mounts and unmounts
        mountObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didMountNotification, object: NSWorkspace.shared, queue: .main, using: self.mounted)
        unmountObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didUnmountNotification, object: NSWorkspace.shared, queue: .main, using: self.unmounted)
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
        if let devicePath = notification.userInfo?["NSDevicePath"] as? String {
            // Get all of the archives from core data
            let archives = self.manager.fetchArchives()
            
            // Flag to tell us if we need to store core data later
            var contextChanged = false
            
            archives.forEach { archive in
                // Ensure that the drive that was mounted was one of Locke's archives
                if (devicePath == archive.mountURL?.path(percentEncoded: false)) {
                    
                    // If it is, note it as attached and run the compleation handler
                    archive.attached = true
                    archive.lastOpened = Date()
                    
                    // Set up the watchdog
                    self.manager.watchdog.watch(archive: archive)
                    
                    contextChanged = true
                    if let handler = self.handler {
                        handler()
                    }
                }
            }
            
            // If the context was changed then save it
            if (contextChanged) {
                self.manager.saveContext()
            }
        }
    }
    
    // Called when any drive is unmounted
    private func unmounted(_ notification: Notification) {
        guard let devicePath = notification.userInfo?["NSDevicePath"] as? String else { return }

        // Only react to Locke's own archives
        guard let archive = self.manager.fetchArchives().first(where: { $0.mountURL?.path(percentEncoded: false) == devicePath }) else { return }

        // Delay one second to allow the OS to actually finish ejecting the archive
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))

            // Note it as detached
            archive.attached = false
            archive.scheduledClose = ""
            
            // Unwatch the archive
            self.manager.watchdog.unwatch(archive: archive)
            
            // Compact it if required. Archives closed through Locke are compacted by the close flow
            // (which also forgets the key), so this only covers archives ejected from Finder
            if (UserDefaults.standard.bool(.compactOnDetach)), let id = archive.id, let hash = self.manager.openArchives[id] {
                self.manager.openArchives[id] = nil
                logger.trace("Compacting Archive from Observer")
                startOperationProgress(archive: archive)
                do {
                    try await self.manager.executeCompact(archive, password: hash)
                } catch {
                    logger.error("Unable to compact '\(archive.name ?? "archive")' after eject: \(error.localizedDescription)")
                }
                stopOperationProgress(archive: archive)
            }
            
            // Update size and modified date
            if let url = archive.bundleURL {
                archive.size = directorySize(url: url)
                archive.modified = directoryModified(url: url)
            }
            self.manager.saveContext()
            self.handler?()
        }
    }
}
