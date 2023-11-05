//
//  Notification.swift
//  Locke
//
//  Created by Norris Nicholson on 10/17/23.
//

import SwiftUI
import Foundation
import UserNotifications

enum NotificationCategory {
    case archiveClosure
    
    var id: String {
        switch self {
        case .archiveClosure:
            return "archiveClosure"
        }
    }
}
enum NotificationAction {
    case archiveClosureCancel
    case archiveClosurePostpone
    case archiveClosureDismiss

    var id: String {
        switch self {
        case .archiveClosureCancel:
            return "locke.notificationAction.\(NotificationCategory.archiveClosure.id).cancel"
        case .archiveClosurePostpone:
            return "locke.notificationAction.\(NotificationCategory.archiveClosure.id).postpone"
        case .archiveClosureDismiss:
            return "locke.notificationAction.\(NotificationCategory.archiveClosure.id).dismiss"
        }
    }
}

// Manager for dealing specifically with archive closure notifications
class ClosureNotificationManager {
    struct ClosureNotification {
        let archiveId: UUID
    }
    
    // List of notifications that are active
    private var activeNotifications: [UUID: ClosureNotification]
    
    // References to other parts of Locke
    private let lockeDelegate: LockeDelegate
    private let archiveManager: ArchiveManager
    
    init(lockeDelegate: LockeDelegate, archiveManager: ArchiveManager) {
        self.activeNotifications = [:]
        self.lockeDelegate = lockeDelegate
        self.archiveManager = archiveManager
    }
    
    deinit {
        // Remove any notifications that are pending
        for (key, _) in self.activeNotifications {
            // Clear any pending or delivered notifications for this archive
            globalNotificationCenter.removePendingNotificationRequests(withIdentifiers: [key.uuidString])
            globalNotificationCenter.removeDeliveredNotifications(withIdentifiers: [key.uuidString])
        }
        
        self.activeNotifications = [:]
    }
    
    // Start the manager and return a category to assign to the notification delegate
    public func start() -> UNNotificationCategory{
        // MARK: Archive Closure
        let archiveClosureCancelAction = UNNotificationAction(identifier: NotificationAction.archiveClosureCancel.id, title: "Cancel", options: [])
        let archiveClosurePostponeAction = UNNotificationAction(identifier: NotificationAction.archiveClosurePostpone.id, title: "Postpone", options: [])
        let archiveClosureDismissAction = UNNotificationAction(identifier: NotificationAction.archiveClosureDismiss.id, title: "Dismiss", options: [])

        let archiveClosureCategory = UNNotificationCategory (
            identifier: NotificationCategory.archiveClosure.id,
            actions: [archiveClosureCancelAction, archiveClosurePostponeAction, archiveClosureDismissAction],
            intentIdentifiers: []
        )
        
        return archiveClosureCategory
    }
    
    // Schedule a notification to occur with the given delay in seconds from now
    public func schedule(archive: ArchiveData, delay: Int, title: String? = nil, body: String? = nil) {
        guard let archiveId = archive.id else { return }
        let content = UNMutableNotificationContent()
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = NotificationCategory.archiveClosure.id
        
        if let title = title {
            content.title = title
        } else {
            content.title = "Archive Closure"
        }
        
        if let body = body {
            content.body = body
        } else {
            content.body = "\(archive.name ?? "Archive") is about to close"
        }
        
        // The trigger will fire at the given delay
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(delay), repeats: false)
        
        // Id for this notification
        let identifier = UUID()
        
        // Apply the identifier
        let request = UNNotificationRequest(identifier: identifier.uuidString, content: content, trigger: trigger)
        
        // Request the notification center to display the notification
        globalNotificationCenter.add(request)
        
        // Record that this notification exists
        self.activeNotifications[identifier] = ClosureNotification(archiveId: archiveId)
        
        logger.trace("Setup new notification for \"\(archive.name ?? "an archive")\". Timeout: \(delay)")
    }
    
    // Cancel any notifications associated with the given archive
    public func cancel(archive: ArchiveData) {
        guard let archiveId = archive.id else { return }
        
        
        // Go through each item in our list of active notifications and look for a reference to the given archive.
        // If found, request to remove that notification
        for (notificationId, closureNotification) in self.activeNotifications {
            if (closureNotification.archiveId == archiveId) {
                self.clear(notificationId: notificationId)
                logger.trace("Request removal of notification for \"\(archive.name ?? "an archive")\"")
            }
        }
    }
    
    // Clear the given notification and remove it from the active list
    public func clear(notificationId: UUID) {
        // Clear any pending or delivered notifications
        globalNotificationCenter.removePendingNotificationRequests(withIdentifiers: [notificationId.uuidString])
        globalNotificationCenter.removeDeliveredNotifications(withIdentifiers: [notificationId.uuidString])
        
        // Remove the notification from the internal list
        self.activeNotifications[notificationId] = nil
        
        logger.trace("Request removal of notification ID: \(notificationId)")
    }
    
    // Handler for managing notification actions
    public func notificationHandler(actionIdentifier: String, notificationidentifier: String) {
        // Get the closure notification object associated with this action
        guard let notificationIdentifierUUID = UUID(uuidString: notificationidentifier) else { return }
        guard let closureNotification = self.activeNotifications[notificationIdentifierUUID] else { return }
        
        switch actionIdentifier {
        case NotificationAction.archiveClosureCancel.id:
            let archiveId = closureNotification.archiveId
            
            logger.trace("Notification Action - Cancel Closure", archiveId)
        
            // Get the archive associated with this notification and unwatch it
            let fetchRequest = NSFetchRequest<ArchiveData>(entityName: "ArchiveData")
            fetchRequest.predicate = NSPredicate(format: "id == %@", archiveId as CVarArg)
            do {
                guard let fetchedArchive: ArchiveData = try self.archiveManager.context.fetch(fetchRequest).first else {
                    return logger.error("Error handling Notification Postpone Closure Action - Archive Does Not Exist")
                }
                self.archiveManager.watchdog.unwatch(archive: fetchedArchive)
            } catch {
                logger.error("Error handling Notification Postpone Closure Action")
            }
            
            break
        case NotificationAction.archiveClosurePostpone.id:
            let archiveId = closureNotification.archiveId
            
            logger.trace("Notification Action - Postpone Closure", archiveId)
            
            // Get the archive associated with this notification. Unwatch and rewatch it to postpone its closure
            let fetchRequest = NSFetchRequest<ArchiveData>(entityName: "ArchiveData")
            fetchRequest.predicate = NSPredicate(format: "id == %@", archiveId as CVarArg)
            do {
                guard let fetchedArchive: ArchiveData = try self.archiveManager.context.fetch(fetchRequest).first else {
                    return logger.error("Error handling Notification Postpone Closure Action - Archive Does Not Exist")
                }
                self.archiveManager.watchdog.unwatch(archive: fetchedArchive)
                self.archiveManager.watchdog.watch(archive: fetchedArchive, customDelay: 2 * 60)
            } catch {
                logger.error("Error handling Notification Postpone Closure Action")
            }
            
            break
        case NotificationAction.archiveClosureDismiss.id:
            print ("Dismiss Action", notificationidentifier)
            
            // Remove this notification
            globalNotificationCenter.removePendingNotificationRequests(withIdentifiers: [notificationidentifier])
            globalNotificationCenter.removeDeliveredNotifications(withIdentifiers: [notificationidentifier])
            self.activeNotifications[notificationIdentifierUUID] = nil
            
            break
        default:
            break
        }
    }
}


class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    
    private var authorized = false
    
    private let lockeDelegate: LockeDelegate
    private let archiveManager: ArchiveManager
    public let closureManager: ClosureNotificationManager
    
    init(lockeDelegate: LockeDelegate, archiveManager: ArchiveManager) {
        self.lockeDelegate = lockeDelegate
        self.archiveManager = archiveManager
        self.closureManager = ClosureNotificationManager(lockeDelegate: lockeDelegate, archiveManager: archiveManager)
        
        super.init()
        // Assign self to the current notification center. This allows this class to manage notifications
        globalNotificationCenter.delegate = self
    }
    
    public func start() {
        // Request permission to send notifications from the OS
        globalNotificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            if success {
                logger.trace("Notifications Authorized")
                self.authorized = true
            } else if let error = error {
                logger.error("Notifications Not Authorized: \(error.localizedDescription)")
                self.authorized = false
            }
        }
        
        // Create any actions and categories that need to be created
        let archiveClosureCategory = self.closureManager.start()
        globalNotificationCenter.setNotificationCategories([archiveClosureCategory])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        print (response.notification)
        
        // Route notification as neede to the appropriate handler
        if (response.actionIdentifier == NotificationAction.archiveClosureCancel.id ||
            response.actionIdentifier == NotificationAction.archiveClosureDismiss.id ||
            response.actionIdentifier == NotificationAction.archiveClosurePostpone.id) {
            self.closureManager.notificationHandler(actionIdentifier: response.actionIdentifier, notificationidentifier: response.notification.request.identifier)
        } else {
            print ("Default Action", response)
            NSApp.sendAction(#selector(self.lockeDelegate.openMainView), to: nil, from:nil)
            
            // If this notification is a closure notification, then clear it from the manager
            if (response.notification.request.content.categoryIdentifier == NotificationCategory.archiveClosure.id) {
                if let notificationIdentifierUUID = UUID(uuidString: response.notification.request.identifier) {
                    self.closureManager.clear(notificationId: notificationIdentifierUUID)
                }
            }
        }
        
        completionHandler()
    }
    
}
