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

    public func backupToBackblaze(_ id: NSManagedObjectID) async {
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

        guard let resourcePath = UserDefaults.standard.string(forKey: "setting.BackblazeResourcePath") else { return }
        if (resourcePath.isEmpty) { return }

        let zipLocation = tempDirectory.appending(path: "\(id).zip")
        let destination = "\(resourcePath)/\(name)\(dateString).zip"

        // Init the progress to 0 %
        startOperationProgress(archive: archive)

        // Always clean up the temporary zip, even if the upload fails
        defer {
            try? fm.removeItem(at: zipLocation)
            stopOperationProgress(archive: archive)
        }

        do {
            // Zip the archive so we can upload it to Backblaze
            try Zip.zipFiles(paths: [source], zipFilePath: zipLocation, password: nil, progress: { (progress) -> () in
                updateOperationProgress(archive: archive, progress: progress / 2)
            })

            // Upload the zipped archive
            try await lockeDelegate.BackblazeManager.upload(fromURL: zipLocation.path(percentEncoded: false), toURL: destination, progress: { (progress) -> () in
                updateOperationProgress(archive: archive, progress: (progress / 2) + 0.5)
            })
        }

        catch {
            logger.error("Failed to backup to Backblaze: \(error.localizedDescription)")
        }
    }

    public func backupToRestic(_ id: NSManagedObjectID) async {
        let archive = try! self.context.existingObject(with: id) as! ArchiveData
        
        guard !archive.attached else {
            logger.error("Cannot back up '\(archive.name ?? "Unknown")' with Restic because it is currently attached")
            return
        }
        guard let bundleURL = archive.bundleURL else { return }
        
        let repository = (UserDefaults.standard.string(forKey: "setting.ResticRepositoryURL") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if repository.isEmpty {
            logger.error("Restic repository URL is not configured")
            return
        }
        
        let account = (UserDefaults.standard.string(forKey: "setting.ResticKeychainAccount") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if account.isEmpty {
            logger.error("Restic keychain account is not configured")
            return
        }
        
        let extraTagsString = UserDefaults.standard.string(forKey: "setting.ResticExtraTags") ?? ""
        let extraTags = extraTagsString
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        let binaryPath = UserDefaults.standard.string(forKey: "setting.ResticExecutablePath")
        let tags = resticTags(for: archive, extraTags: extraTags)
        let hostname = Host.current().localizedName
        
        let password: String
        do {
            password = try lockeDelegate.ResticManager.password(account: account)
        } catch {
            logger.error("Unable to fetch Restic password for account \(account): \(error.localizedDescription)")
            return
        }
        
        startOperationProgress(archive: archive)
        defer {
            stopOperationProgress(archive: archive)
        }
        
        do {
            let summary = try await lockeDelegate.ResticManager.backup(
                bundleURL: bundleURL,
                repository: repository,
                binaryPath: binaryPath,
                password: password,
                tags: tags,
                hostname: hostname) { percent in
                    updateOperationProgress(archive: archive, progress: percent)
                }
            if let name = archive.name {
                logger.trace("Restic backup complete for '\(name)': \(summary.logDescription)")
            } else {
                logger.trace("Restic backup complete: \(summary.logDescription)")
            }
        } catch let resticError as ResticManager.ResticError {
            switch resticError {
            case .repositoryMissing:
                logger.error("Restic backup failed: repository URL is missing")
            case .passwordMissing(let message):
                logger.error("Restic backup failed: \(message)")
            case .unreadablePassword:
                logger.error("Restic backup failed: restic password could not be read from keychain")
            case .executableNotFound(let path):
                logger.error("Restic backup failed: executable not found or not executable at \(path)")
            case .processFailed(let code, let message):
                if message.isEmpty {
                    logger.error("Restic backup failed with exit code \(code)")
                } else {
                    logger.error("Restic backup failed with exit code \(code): \(message)")
                }
            }
        } catch {
            logger.error("Restic backup failed: \(error.localizedDescription)")
        }
    }
    
    private func resticTags(for archive: ArchiveData, extraTags: [String]) -> [String] {
        var tagSet: Set<String> = ["locke"]
        if let id = archive.id {
            tagSet.insert("locke-id-\(id.uuidString)")
        }
        if let name = archive.name {
            let sanitized = ResticManager.sanitize(tag: "locke-name-\(name)")
            if !sanitized.isEmpty {
                tagSet.insert(sanitized)
            }
        }
        extraTags.forEach { tag in
            let sanitized = ResticManager.sanitize(tag: tag)
            if !sanitized.isEmpty {
                tagSet.insert(sanitized)
            }
        }
        return Array(tagSet).sorted()
    }
}
