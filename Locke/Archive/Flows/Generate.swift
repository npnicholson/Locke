//
//  Generate.swift
//  Locke
//
//  Created by Norris Nicholson on 10/30/23.
//

import Foundation
import CoreData
import CryptoKit

// MARK: - Open Archive Flow
extension ArchiveManager {
    
    public enum GenerateCommand {
        case copy
        case store
    }
    
    // Start the open archive flow with the given archive
    public func generate(_ objectId: NSManagedObjectID, _ command: GenerateCommand) {
        // Get just the specific archive from CoreData
        let archive = try! self.context.existingObject(with: objectId) as! ArchiveData
        guard let archiveId = archive.id else { return }
        
        if (!archive.attached) {
            // Activate the passwordPromptManager
            self.passwordPromptManager.activate(self.generateHandle, archive: archive,
                                                title: "Locke: Enter your password.",
                                                subtitle: "Please enter the password for '\(archive.name ?? "Unknown")'.",
                                                prompt: "This is required to generate the key.", data: command)
            
            // Activate Locke if it is not already. This will force the user to interact with the new password prompt
            self.lockeDelegate.activate()
        } else if (self.openArchives[archiveId] == nil || self.openArchives[archiveId] == "") {
            // Activate the passwordPromptManager
            self.passwordPromptManager.activate(self.generateHandle, archive: archive,
                                                title: "Locke: Enter your password.",
                                                subtitle: "Please enter the password for '\(archive.name ?? "Unknown")'.",
                                                prompt: "The key is not stored and must be regenerated.", data: command)
            // Activate Locke if it is not already. This will force the user to interact with the new password prompt
            self.lockeDelegate.activate()
        } else {
            exportKey(archive, command)
        }
    }
    
    private func generateHandle(_ result: PromptResult, _ archive: ArchiveData, _ password: String, _ data: Any) -> Bool {
        if (result == .cancled) { return false }
        guard let archiveId = archive.id else { return false }
        do {
            
            // Calculate the password for this archive
            let hashString = Keychain.deriveKey(password: password, archiveId: archiveId)
            
            // Attach the archive
            try self.executeAttach(archive, password: hashString)
            
            // Note it as open for recordkeeping
            self.openArchives[archiveId] = hashString
            
            // Update the list of mounted archives
            self.scanArchiveMounts()
            
            // Copy
            let command = data as! GenerateCommand
            exportKey(archive, command)
            
            return true
        } catch {
            return false
        }
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
