//
//  Generate.swift
//  Locke
//
//  Created by Norris Nicholson on 10/30/23.
//

import Foundation
import CoreData

// MARK: - Generate Recovery Key Flow
extension ArchiveManager {
    
    public enum GenerateCommand {
        case copy
        case store
    }
    
    // Start the generate recovery key flow with the given archive
    public func generate(_ objectId: NSManagedObjectID, _ command: GenerateCommand) {
        // Get just the specific archive from CoreData
        guard let archive = self.archive(objectId), let archiveId = archive.id else { return }
        
        if (!archive.attached) {
            // Activate the passwordPromptManager
            self.passwordPromptManager.activate(self.generateHandle, archive: archive,
                                                title: "Locke: Enter your password.",
                                                subtitle: "Please enter the password for '\(archive.name ?? "Unknown")'.",
                                                prompt: "This is required to generate the key.", data: command)
            
            // Activate Locke if it is not already. This will force the user to interact with the new password prompt
            self.lockeDelegate.activate()
        } else if (self.openArchives[archiveId] == nil || self.openArchives[archiveId] == "") {
            // The archive was opened outside this session, so its key is not known and the password
            // cannot be verified while it is attached. Exporting an unverified key would be unsafe
            presentError("Close '\(archive.name ?? "the archive")' first",
                         message: "Locke does not have this archive's key in memory. Close the archive, then generate the recovery key again.")
        } else {
            exportKey(archive, command)
        }
    }
    
    @MainActor
    private func generateHandle(_ result: PromptResult, _ archive: ArchiveData, _ password: String, _ data: Any?) async -> Bool {
        if (result == .cancelled) { return false }
        guard let archiveId = archive.id, let command = data as? GenerateCommand else { return false }

        // Calculate the password for this archive
        let hashString: String
        do {
            hashString = try Keychain.deriveKey(password: password, archiveId: archiveId)
        } catch {
            presentError("Unable to read the key for '\(archive.name ?? "archive")'", error)
            return true
        }

        // Opening the archive verifies the password before the key is exported
        do {
            try await self.executeAttach(archive, password: hashString)
        } catch {
            logger.error("Unable to verify password for '\(archive.name ?? "archive")': \(error.localizedDescription)")
            return false
        }

        // Note it as open for recordkeeping
        self.openArchives[archiveId] = hashString

        // Update the list of mounted archives
        self.scanArchiveMounts()

        exportKey(archive, command)
        return true
    }
    
    private func exportKey(_ archive: ArchiveData, _ command: GenerateCommand) {
        guard let archiveId = archive.id, let key = self.openArchives[archiveId] else {
            logger.error("Unable to export archive key. Key is not stored.")
            return
        }
        if (command == .store) {
            let jsonString = generateArchiveJsonString(archive: archive, key: key)
            exportToFile(contents: jsonString, name: "\(archive.name ?? "Archive").locke")
        } else if (command == .copy) {
            copyStringToClipboard(key)
        }
    }
}
