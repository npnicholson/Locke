//
//  Backup.swift
//  Locke
//
//  Created by Norris Nicholson on 11/02/23.
//

import Foundation
import AppKit
import CoreData
import UniformTypeIdentifiers

import Zip

// MARK: - Close Archive Flow
extension ArchiveManager {
    // Show the mount url by opening it in Finder
    public func backupToDisk(_ id: NSManagedObjectID) {
        // Get just the specific archive from CoreData
        let archive = try! self.context.existingObject(with: id) as! ArchiveData
        
        guard let name = archive.name else { return }
        
        let savePanel = NSSavePanel()
        
        savePanel.title = "Backup '\(name)'"
        savePanel.showsTagField = false
        savePanel.showsHiddenFiles = true
        savePanel.directoryURL = fm.homeDirectoryForCurrentUser
        savePanel.level = .popUpMenu
        savePanel.prompt = "Copy Archive"
        savePanel.nameFieldStringValue = "\(name).sparsebundle"
        
        
        
        savePanel.allowedContentTypes = [UTType.bundle]
        savePanel.allowsOtherFileTypes = false
        
        savePanel.begin { response in
            if response == .OK, let destinationUrl = savePanel.url {
                print (destinationUrl)
                try? self.executeBackup(archive, destinationUrl)
            }
        }
    }
    
    public func backupToAWS(_ id: NSManagedObjectID) async {
        // Get just the specific archive from CoreData
        let archive = try! self.context.existingObject(with: id) as! ArchiveData
        
        guard let name = archive.name else { return }
        guard let id = archive.id else { return }
        guard let source = archive.bundleURL else { return }
        
        var dateString = ""
        if (UserDefaults.standard.bool(forKey: "setting.BackupAWSUseDate")) {
            let date = Date()
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            dateString = "-" + df.string(from: date)
        }
        
        guard let awsS3ResourcePath = UserDefaults.standard.string(forKey: "setting.AWSS3ResourcePath") else { return }
        if (awsS3ResourcePath.isEmpty) { return }
        
        let zipLocation = tempDirectory.appending(path: "\(id).zip")
        let destination = "\(awsS3ResourcePath)/\(name)\(dateString).zip"
        
        // Init the progress to 0 %
        startOperationProgress(archive: archive)
        
        do {

            // Zip the archive so we can upload it to AWS
            try Zip.zipFiles(paths: [source], zipFilePath: zipLocation, password: nil, progress: { (progress) -> () in
                updateOperationProgress(archive: archive, progress: progress / 2)
            })
            
            // Upload the zipped archive
            await lockeDelegate.AWSManager.upload(fromURL: zipLocation.path(percentEncoded: false), toURL: destination, progress: { (progress) -> () in
                updateOperationProgress(archive: archive, progress: (progress / 2) + 0.5)
            })
            
            // Clean up by removing the zipped archive from disk
            try! fm.removeItem(at: zipLocation)
        }
        
        catch {
            logger.error("Failed to backup to AWS")
        }
        
        // Set the operation to complete
        stopOperationProgress(archive: archive)
    }
}
