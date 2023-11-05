//
//  ArchiveWatchdog.swift
//  Locke
//
//  Created by Norris Nicholson on 10/16/23.
//

import Foundation
import CoreData
import UserNotifications

struct WatchdogItem {
    let work: DispatchWorkItem
    let time: DispatchTime
}

class ArchiveWatchdog {
    public var manager: ArchiveManager! = nil
    
    public var watches: [UUID: WatchdogItem]
    
    init() {
        self.watches = [:]
    }
    
    deinit {
        for (_, item) in self.watches {
            item.work.cancel()
        }
        
        self.watches = [:]
    }
    
    // Set up a watchdog on the given archive to close it after a timeout
    public func watch (archive: ArchiveData, customDelay: Int? = nil) {
        logger.trace("Watching Archive \(archive.name ?? "")")
        
        guard let archiveId = archive.id else { return }
        
        // Cancel the old watchdog if it exists
        if let oldItem = watches[archiveId] {
            oldItem.work.cancel()
        }
        
        // Only set up watches if auto eject is enabled
        if (!UserDefaults.standard.bool(forKey: "setting.AutoEject")) { return }
        
        // Grab the timeout setting (convert min from setting to seconds here)
        let timeout = customDelay ?? UserDefaults.standard.integer(forKey: "setting.AutoEjectTimeout") * 60
        
        // Build a new watchdog for this archive
        let work = DispatchWorkItem(block: {
            logger.trace("Closing archive due to timeout (\(timeout) m): \(archive.name ?? "Unknown Archive") / \(archive.id?.uuidString ?? "Unknown Id")")
            let fetchRequest = NSFetchRequest<ArchiveData>(entityName: "ArchiveData")
            fetchRequest.predicate = NSPredicate(format: "id == %@", archiveId as CVarArg)
            
            if let fetchedArchive: ArchiveData = try? self.manager.context.fetch(fetchRequest).first {
                self.manager.close(fetchedArchive.objectID)
            }

            self.watches[archiveId] = nil
        })
        
        let dispatchTime: DispatchTime = .now() + .seconds(timeout)
        DispatchQueue.main.asyncAfter(deadline: dispatchTime, execute: work)
        
        // Store a reference to the work
        watches[archiveId] = WatchdogItem(work: work, time: dispatchTime)
        
        // Clear any pending or delivered notifications for this archive
        globalNotificationCenter.removePendingNotificationRequests(withIdentifiers: [archiveId.uuidString])
        globalNotificationCenter.removeDeliveredNotifications(withIdentifiers: [archiveId.uuidString])
        
        // Get a notifications going if the timeout is longer than 3 minutes
        if (timeout >= 3 * 60) {
            // 1 minute notification
            self.manager.lockeDelegate.notificationDelegate.closureManager.schedule(archive: archive, delay: timeout - 60)
        }
        
        // Prepare the string describing the time this watchdog will fire
        let calendar = Calendar.current
        guard let closeDate = calendar.date(byAdding: .second, value: timeout, to: Date()) else { return }
        
        archive.scheduledClose = "Closes \(closeDate.formatted(date: .numeric, time: .shortened))"
        archive.watched = true
        
        // Update the context to save the changes to the archive
        try! self.manager.context.save()
    }
    
    // Cancel a watchdog on the given archive if it exists
    public func unwatch (archive: ArchiveData) {
        logger.trace("Unwatching Archive \(archive.name ?? "")")
        if let archiveId = archive.id {
            if let item = self.watches[archiveId] {
                item.work.cancel()
                self.watches[archiveId] = nil
            }
            
            archive.scheduledClose = ""
            archive.watched = false
            
            // Clear any pending or delivered notifications for this archive
            self.manager.lockeDelegate.notificationDelegate.closureManager.cancel(archive: archive)
            
            globalNotificationCenter.removePendingNotificationRequests(withIdentifiers: [archiveId.uuidString])
            globalNotificationCenter.removeDeliveredNotifications(withIdentifiers: [archiveId.uuidString])
            
            // Update the context to save the changes to the archive
            try! self.manager.context.save()
        }
    }
    
    
}
