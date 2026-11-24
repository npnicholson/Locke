//
//  ArchiveManager.swift
//  Locke
//
//  Created by Norris Nicholson on 8/28/23.
//

import Foundation
import CoreData

// Errors associated with the Archive Class
enum ArchiveError: Error {
    case archiveExists
    case archiveDoesNotExist
    case archiveAttached
    case archiveNotAttached
    
    case noPasswordProvided
    
    case notCreated
    case notRemoved
    case notAttached
    case notDetached
    
    case operationFailure(Operation)
}

extension ArchiveError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .archiveExists: return "An archive already exists at this location."
        case .archiveDoesNotExist: return "The archive could not be found on disk."
        case .archiveAttached: return "The archive is open. Close it first."
        case .archiveNotAttached: return "The archive is not open."
        case .noPasswordProvided: return "No password was provided."
        case .notCreated: return "The archive was not created."
        case .notRemoved: return "The archive could not be removed."
        case .notAttached: return "The archive could not be opened."
        case .notDetached: return "The archive could not be closed. A file inside it may still be in use."
        case .operationFailure(let operation):
            let detail = operation.stderr?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return detail.isEmpty ? "hdiutil failed with exit code \(operation.code)." : detail
        }
    }
}

func defaultArchiveBundleURL(id: UUID) -> URL {
    return archivesDirectory.appending(path: "/\(id).sparsebundle")
}

func defaultArchiveMountURL(id: UUID) -> URL {
    return mountDirectory.appending(path: "/\(id)")
}

// Generate a json string that can be used to store an archive and key recovery
func generateArchiveJsonString (archive: ArchiveData, key: String) -> String {
    // Create Date
    let date = Date()
    let dateFormatter = DateFormatter()
    let exportJson: [String: Any] = [
        "info": "Locke Recovery Key",
        "archive": [
            "name": archive.name ?? "Archive",
            "id": archive.id?.uuidString
        ],
        "date": dateFormatter.string(from: date),
        "key": key,
    ]

    // Only strings go into this dictionary, so serialization cannot fail
    guard let jsonData = try? JSONSerialization.data(withJSONObject: exportJson) else { return "" }
    return String(decoding: jsonData, as: UTF8.self)
}

// MARK: - Main Archive Manager (Start and Stop)
class ArchiveManager: NSObject, ObservableObject {
    // Main CoreData context
    var context: NSManagedObjectContext
    
    // Reference to ephemeral storage
    var storage: LockeEphemeralStorage
    
    // A reference to the main Locke Delegate
    let lockeDelegate: LockeDelegate
    
    // A reference to the used Archive Observer
    internal let observer: ArchiveObserver!
    
    // A reference to the watchdog, which manages auto-closing archives
    internal let watchdog: ArchiveWatchdog!
    
    // A reference to the used Password Prompt Manager
    internal let passwordPromptManager: PasswordPromptManager
    
    // A list of open archives and their keys
    var openArchives: [UUID: String]
    
    init(context: NSManagedObjectContext, storage: LockeEphemeralStorage, lockeDelegate: LockeDelegate, passwordPromptManager: PasswordPromptManager) {
        self.context = context
        self.storage = storage
        self.passwordPromptManager = passwordPromptManager
        self.lockeDelegate = lockeDelegate
        self.openArchives = [:]
        self.observer = ArchiveObserver(context: context)
        self.watchdog = ArchiveWatchdog()
        
        super.init()
        self.observer.manager = self
        self.watchdog.manager = self
    }
    
    // Should be called when the application has finished launching. Ensure all of the folders exist, then verify
    // that CoreData and the archives on disk match. Finally update the list of attached archives
    public func start() {
        // Set the observer's handler so that it updates the list of attached archives wheneber an archive is
        // mounted or unmounted
        self.observer.handler = self.scanArchiveMounts
        
        // Init the important directories if they don't already exist
        for directory in [archivesDirectory, orphansDirectory, mountDirectory, tempDirectory] {
            do {
                try fm.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                presentError("Unable to create Locke's folders", error)
            }
        }
        
        // Make sure the temp directory is empty on startup
        do {
            let fileURLs = try fm.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
            for fileURL in fileURLs {
                try fm.removeItem(at: fileURL)
            }
        } catch { logger.error("Unable to clear temp directory: \(error.localizedDescription)") }
        
        // Get ArchiveData in CoreData as 'archives'
        let archives = self.fetchArchives()
        
        // Ensure that all of the archives in CoreData actually exist on disk
        var dataChanged = false
        for archiveData in archives {
            if (!self.exists(archiveData)) {
                logger.error("Found orphaned archive in CoreData", archiveData)
                self.context.delete(archiveData)
                dataChanged = true
            }
        }
        if (dataChanged) {
            // Save the changes to CoreData
            self.saveContext()
        }
        
        // Ensure that all of the archives on disk have references in CoreData
        let bundles = listArchives()
        for bundle in bundles {
            if (!archives.contains(where: { ($0 as ArchiveData).id == bundle.id })) {
                logger.error("Found orphaned sparsebundle on disk: \(bundle.id) at \(bundle.url.path(percentEncoded: false))")
                try? fm.moveItem(at: bundle.url, to: orphansDirectory.appending(path: "\(bundle.id).sparsebundle"))
            }
        }
        
        // Scan for open archives
        self.scanArchiveMounts()
        
        // Set the "lastOpened" time of any archives that are currently open to now. Since we don't
        // know when they were opened, we will consider them just opened. Also set up the watchdog for
        // those archives
        dataChanged = false
        archives.forEach { archive in
            if (archive.attached) {
                archive.lastOpened = Date()
                dataChanged = true
                self.watchdog.watch(archive: archive)
            }
        }
        
        // Set all archive's progress flag to denote no ongoing operations
        archives.forEach { archive in
            stopOperationProgress(archive: archive)
        }
        
        if (dataChanged) {
            self.saveContext()
        }
    }
    
    // To be called before the application terminates. This closes all of the archives
    @MainActor
    public func end() async {
        if (UserDefaults.standard.bool(.ejectOnClose)) {
            // If any archives are attached, then detach them
            for archiveData in self.fetchArchives() where self.attached(archiveData) {
                do {
                    try await self.executeDetach(archiveData)
                } catch {
                    logger.error("Unable to eject '\(archiveData.name ?? "archive")' on quit: \(error.localizedDescription)")
                }
            }
        }
        // Take note of which archives are still open for next time
        self.scanArchiveMounts()
    }
    
    // Scan all of the archive's mount points and update each archive's 'attached' value
    // as needed. Then save the context
    public func scanArchiveMounts() {
        // Assume to start that no archives are open
        var anyArchivesOpen = false
        
        // Get a list of all archives
        let archives = self.fetchArchives()
        
        var newOpenArchives: [UUID: String] = [:]
        
        archives.forEach { archive in
            // Query the disk to see if this archive is mounted
            archive.attached = self.attached(archive)
            
            if (archive.attached) {
                // If it is mounted, then we have at least one archive that is open
                anyArchivesOpen = true
                
                // Add this archive to our new archive list and grab the key from our
                // old list, if it exists
                if let id = archive.id {
                    if let oldKey = self.openArchives[id] {
                        newOpenArchives[id] = oldKey
                    } else {
                        newOpenArchives[id] = ""
                    }
                }
            }
        }
        
        // Store any changes to Core Data
        self.saveContext()
        
        // Reassign our list of open archives based on this new data
        self.openArchives = newOpenArchives
        
        // Update the ephemeral storage so that the menuBarExtra text can update
        // if any archives are open
        self.storage.archiveOpen = anyArchivesOpen
    }
}

// MARK: - Core Data helpers
extension ArchiveManager {
    // Look up an archive by its object ID. Returns nil (and logs) if it no longer exists, for example
    // when it was removed while a menu or notification still referenced it
    func archive(_ objectId: NSManagedObjectID) -> ArchiveData? {
        do {
            if let archive = try self.context.existingObject(with: objectId) as? ArchiveData {
                return archive
            }
        } catch {
            logger.error("Archive no longer exists: \(error.localizedDescription)")
        }
        return nil
    }

    // Look up an archive by its UUID
    func archive(id: UUID) -> ArchiveData? {
        let request = NSFetchRequest<ArchiveData>(entityName: "ArchiveData")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return (try? self.context.fetch(request))?.first
    }

    // Fetch every archive, logging and returning an empty list if Core Data fails
    func fetchArchives() -> [ArchiveData] {
        do {
            return try self.context.fetch(globalArchiveFetchRequest)
        } catch {
            logger.error("Unable to fetch archives: \(error.localizedDescription)")
            return []
        }
    }

    // Save the context if it has changes, logging any failure rather than crashing
    func saveContext() {
        guard self.context.hasChanges else { return }
        do {
            try self.context.save()
        } catch {
            logger.error("Unable to save archive data: \(error.localizedDescription)")
        }
    }
}
