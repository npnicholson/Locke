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

// MARK: - Backup Archive Flow
extension ArchiveManager {
    // Copy the archive's bundle to a location the user picks
    public func backupToDisk(_ id: NSManagedObjectID) {
        guard let archive = self.archive(id), let name = archive.name else { return }
        
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
            guard response == .OK, let destinationUrl = savePanel.url else { return }
            Task { @MainActor in
                startOperationProgress(archive: archive)
                defer { stopOperationProgress(archive: archive) }
                do {
                    try await self.executeBackup(archive, destinationUrl)
                    logger.trace("Backed up '\(name)' to \(destinationUrl.path(percentEncoded: false))")
                } catch {
                    presentError("Unable to back up '\(name)'", error)
                }
            }
        }
    }
    
    @MainActor
    public func backupToAWS(_ id: NSManagedObjectID) async {
        let resourcePath = UserDefaults.standard.trimmedString(.awsS3ResourcePath)
        await self.zipAndUpload(id, service: "AWS", resourcePath: resourcePath) { zip, destination, progress in
            try await self.lockeDelegate.AWSManager.upload(fromURL: zip, toURL: destination, progress: progress)
        }
    }

    @MainActor
    public func backupToBackblaze(_ id: NSManagedObjectID) async {
        let resourcePath = UserDefaults.standard.trimmedString(.backblazeResourcePath)
        await self.zipAndUpload(id, service: "Backblaze", resourcePath: resourcePath) { zip, destination, progress in
            try await self.lockeDelegate.BackblazeManager.upload(fromURL: zip, toURL: destination, progress: progress)
        }
    }

    // Zip the archive's bundle into the temp folder, upload it with the given uploader, then remove the zip.
    // Progress runs 0-50% for zipping and 50-100% for the upload. Failures are shown to the user
    @MainActor
    private func zipAndUpload(_ id: NSManagedObjectID, service: String, resourcePath: String,
                              upload: @escaping (String, String, @escaping (Double) throws -> Void) async throws -> Void) async {
        guard let archive = self.archive(id), let name = archive.name, let archiveId = archive.id, let source = archive.bundleURL else { return }

        if (resourcePath.isEmpty) {
            presentError("Unable to back up '\(name)' to \(service)", message: "Set the \(service) resource path in Settings first.")
            return
        }
        if (archive.attached) {
            presentError("Unable to back up '\(name)' to \(service)", ArchiveError.archiveAttached)
            return
        }

        var dateString = ""
        if (UserDefaults.standard.bool(.backupUseDate)) {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            dateString = "-" + df.string(from: Date())
        }

        let zipLocation = tempDirectory.appending(path: "\(archiveId).zip")
        let destination = "\(resourcePath)/\(name)\(dateString).zip"

        // Init the progress to 0 %
        startOperationProgress(archive: archive)

        // Always clean up the temporary zip, even if the upload fails
        defer {
            try? fm.removeItem(at: zipLocation)
            stopOperationProgress(archive: archive)
        }

        do {
            // Zipping a large archive takes a while, so do it off the main thread
            try await Task.detached(priority: .userInitiated) {
                try Zip.zipFiles(paths: [source], zipFilePath: zipLocation, password: nil, progress: { progress in
                    updateOperationProgress(archive: archive, progress: progress / 2)
                })
            }.value

            // Upload the zipped archive
            try await upload(zipLocation.path(percentEncoded: false), destination) { progress in
                updateOperationProgress(archive: archive, progress: (progress / 2) + 0.5)
            }
            logger.trace("Backed up '\(name)' to \(destination)")
        } catch {
            presentError("Unable to back up '\(name)' to \(service)", error)
        }
    }

    @MainActor
    public func backupToRestic(_ id: NSManagedObjectID) async {
        guard let archive = self.archive(id), let bundleURL = archive.bundleURL else { return }
        let title = "Unable to back up '\(archive.name ?? "archive")' with Restic"
        
        guard !archive.attached else {
            presentError(title, ArchiveError.archiveAttached)
            return
        }
        
        let repository = UserDefaults.standard.trimmedString(.resticRepositoryURL)
        if repository.isEmpty {
            presentError(title, message: "Set the Restic repository URL in Settings first.")
            return
        }
        
        let account = UserDefaults.standard.trimmedString(.resticKeychainAccount)
        if account.isEmpty {
            presentError(title, message: "Set the Restic Keychain account in Settings first.")
            return
        }
        
        let extraTagsString = UserDefaults.standard.trimmedString(.resticExtraTags)
        let extraTags = extraTagsString
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        let binaryPath = UserDefaults.standard.trimmedString(.resticExecutablePath)
        let tags = resticTags(for: archive, extraTags: extraTags)
        let hostname = Host.current().localizedName
        
        let password: String
        do {
            password = try lockeDelegate.ResticManager.password(account: account)
        } catch {
            presentError(title, error, message: "Unable to read the Restic password for '\(account)' from Keychain: \(error.localizedDescription)")
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
            let message: String
            switch resticError {
            case .repositoryMissing:
                message = "The repository URL is missing."
            case .passwordMissing(let detail):
                message = detail
            case .unreadablePassword:
                message = "The Restic password could not be read from Keychain."
            case .executableNotFound(let path):
                message = "The restic executable was not found (or is not executable) at \(path)."
            case .processFailed(let code, let detail):
                message = detail.isEmpty ? "restic exited with code \(code)." : "restic exited with code \(code): \(detail)"
            }
            presentError(title, message: message)
        } catch {
            presentError(title, error)
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
