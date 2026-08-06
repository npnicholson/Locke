//
//  Restic.swift
//  Locke
//
//  Created by Norris Nicholson on 10/31/24.
//

import Foundation

struct ResticBackupSummary {
    var snapshotId: String?
    var totalFilesProcessed: Int?
    var totalBytesProcessed: Int64?
    var filesNew: Int?
    var filesChanged: Int?
    var filesUnmodified: Int?
    
    var logDescription: String {
        var components: [String] = []
        if let files = totalFilesProcessed {
            components.append("\(files) files processed")
        }
        if let bytes = totalBytesProcessed {
            components.append("~\(formatBytes(bytes)) transferred")
        }
        if let snapshot = snapshotId {
            components.append("snapshot \(snapshot)")
        }
        return components.joined(separator: ", ")
    }
}

// MARK: - Restic Manager
final class ResticManager: @unchecked Sendable {
    static let keychainService = "Locke.Restic"
    private let stdoutQueue = DispatchQueue(label: "Locke.Restic.Stdout")
    private let stderrQueue = DispatchQueue(label: "Locke.Restic.Stderr")
    
    enum ResticError: Error {
        case repositoryMissing
        case passwordMissing(String)
        case unreadablePassword
        case executableNotFound(String)
        case processFailed(code: Int32, message: String)
    }
    
    // Store a stub password (or provided value) in the keychain so the user can complete it manually
    func storePassword(account: String, password: String) -> Bool {
        if account.isEmpty { return false }
        let currentPassword = try? Keychain.readPassword(service: ResticManager.keychainService, account: account)
        if currentPassword == nil {
            Task {
                try? await Keychain.save(password: password.data(using: .utf8) ?? Data(), service: ResticManager.keychainService, account: account)
            }
            return true
        }
        return false
    }
    
    func password(account: String) throws -> String {
        guard !account.isEmpty else {
            throw ResticError.passwordMissing("Keychain account not set")
        }
        let data = try Keychain.readPassword(service: ResticManager.keychainService, account: account)
        guard let password = String(data: data, encoding: .utf8) else {
            throw ResticError.unreadablePassword
        }
        if password.isEmpty {
            throw ResticError.passwordMissing("Password for account \(account) is empty")
        }
        return password
    }
    
    func isConfigured() -> Bool {
        let repository = (UserDefaults.standard.string(forKey: "setting.ResticRepositoryURL") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if repository.isEmpty { return false }
        let account = (UserDefaults.standard.string(forKey: "setting.ResticKeychainAccount") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if account.isEmpty { return false }
        return (try? Keychain.readPassword(service: ResticManager.keychainService, account: account)) != nil
    }
    
    static func sanitize(tag: String) -> String {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return ""
        }
        
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let components = trimmed.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        var sanitized = String(components)
        
        while sanitized.contains("--") {
            sanitized = sanitized.replacingOccurrences(of: "--", with: "-")
        }
        sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "-_."))
        return sanitized
    }
    
    func backup(bundleURL: URL, repository: String, binaryPath: String?, password: String, tags: [String], hostname: String?, progress: @escaping (Double) -> Void) async throws -> ResticBackupSummary {
        
        logger.trace("Backing up \(repository) : \(bundleURL)")
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let summary = try self.performBackup(bundleURL: bundleURL, repository: repository, binaryPath: binaryPath, password: password, tags: tags, hostname: hostname, progress: progress)
                    continuation.resume(returning: summary)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Private Helpers
    private func performBackup(bundleURL: URL, repository: String, binaryPath: String?, password: String, tags: [String], hostname: String?, progress: @escaping (Double) -> Void) throws -> ResticBackupSummary {
        let trimmedRepository = repository.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRepository.isEmpty else {
            throw ResticError.repositoryMissing
        }
        
        guard !password.isEmpty else {
            throw ResticError.passwordMissing("Password not found for Restic repository")
        }
        
        let (executableURL, argumentsPrefix) = try resolveExecutable(binaryPath: binaryPath)
        
        var arguments = argumentsPrefix
        arguments.append(contentsOf: ["-r", trimmedRepository, "--json"])
        if let hostname = hostname?.trimmingCharacters(in: .whitespacesAndNewlines), !hostname.isEmpty {
            arguments.append(contentsOf: ["--host", hostname])
        }
        let sanitizedTags = Array(Set(tags.compactMap { tag -> String? in
            let sanitized = ResticManager.sanitize(tag: tag)
            return sanitized.isEmpty ? nil : sanitized
        }))
        sanitizedTags.forEach { tag in
            arguments.append(contentsOf: ["--tag", tag])
        }
        arguments.append("backup")
        arguments.append(bundleURL.path(percentEncoded: false))
        
        var environment = ProcessInfo.processInfo.environment
        let defaultPath = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        if let path = environment["PATH"], !path.isEmpty {
            if !path.contains("/opt/homebrew/bin") {
                environment["PATH"] = defaultPath + ":" + path
            }
        } else {
            environment["PATH"] = defaultPath
        }
        environment["RESTIC_PASSWORD"] = password
        
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.environment = environment
        
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        var summary = ResticBackupSummary()
        var stdoutBuffer = Data()
        var stderrBuffer = Data()
        
        let decoder = JSONDecoder()
        let newline = Data([0x0a])
        
        let processLine: (Data) -> Void = { lineData in
            if let status = try? decoder.decode(ResticStatusMessage.self, from: lineData), status.messageType == "status" {
                if let percent = status.percentDone {
                    DispatchQueue.main.async {
                        progress(percent.clamped(0, 1))
                    }
                }
                return
            }
            if let summaryMessage = try? decoder.decode(ResticSummaryMessage.self, from: lineData), summaryMessage.messageType == "summary" {
                summary.update(from: summaryMessage)
                DispatchQueue.main.async {
                    progress(1.0)
                }
                if let snapshot = summaryMessage.snapshotId {
                    logger.trace("restic snapshot created: \(snapshot)")
                }
                return
            }
            if let message = try? decoder.decode(ResticGenericMessage.self, from: lineData) {
                if let level = message.level, level == "error" {
                    logger.error("restic: \(message.message ?? "unknown error")")
                } else if let text = message.message, !text.isEmpty {
                    logger.trace("restic: \(text)")
                }
                return
            }
            if let raw = String(data: lineData, encoding: .utf8), !raw.isEmpty {
                logger.trace("restic: \(raw)")
            }
        }
        
        let processBufferedLines: () -> Void = {
            while let range = stdoutBuffer.firstRange(of: newline) {
                let lineData = stdoutBuffer.subdata(in: 0..<range.lowerBound)
                stdoutBuffer.removeSubrange(0..<range.upperBound)
                guard !lineData.isEmpty else { continue }
                processLine(lineData)
            }
        }
        
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            self.stdoutQueue.async {
                stdoutBuffer.append(data)
                processBufferedLines()
            }
        }
        
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            self.stderrQueue.async {
                stderrBuffer.append(data)
                if let string = String(data: data, encoding: .utf8), !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    logger.error("restic stderr: \(string)")
                }
            }
        }
        
        DispatchQueue.main.async {
            progress(0)
        }
        
        try process.run()
        process.waitUntilExit()
        
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        
        var stdoutResidualMessage = ""
        let finalSummary: ResticBackupSummary = stdoutQueue.sync {
            if !stdoutBuffer.isEmpty {
                processBufferedLines()
                if !stdoutBuffer.isEmpty {
                    processLine(stdoutBuffer)
                    stdoutResidualMessage = String(data: stdoutBuffer, encoding: .utf8) ?? ""
                    stdoutBuffer.removeAll()
                }
            }
            return summary
        }
        
        let stderrMessage: String = stderrQueue.sync {
            String(data: stderrBuffer, encoding: .utf8) ?? ""
        }
        
        if process.terminationStatus != 0 {
            let combinedMessage = [stderrMessage, stdoutResidualMessage]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            throw ResticError.processFailed(code: process.terminationStatus, message: combinedMessage)
        }
        
        return finalSummary
    }
    
    private func resolveExecutable(binaryPath: String?) throws -> (URL, [String]) {
        if let binaryPath = binaryPath?.trimmingCharacters(in: .whitespacesAndNewlines), !binaryPath.isEmpty {
            let expanded = (binaryPath as NSString).expandingTildeInPath
            if !fm.isExecutableFile(atPath: expanded) {
                throw ResticError.executableNotFound(expanded)
            }
            return (URL(filePath: expanded), [])
        }
        return (URL(filePath: "/usr/bin/env"), ["restic"])
    }
}

// MARK: - Restic JSON Structures
private struct ResticStatusMessage: Decodable {
    let messageType: String
    let percentDone: Double?
    let totalFiles: Int?
    let filesDone: Int?
    let totalBytes: Int?
    let bytesDone: Int?
    
    enum CodingKeys: String, CodingKey {
        case messageType = "message_type"
        case percentDone = "percent_done"
        case totalFiles = "total_files"
        case filesDone = "files_done"
        case totalBytes = "total_bytes"
        case bytesDone = "bytes_done"
    }
}

private struct ResticSummaryMessage: Decodable {
    let messageType: String
    let totalFilesProcessed: Int?
    let totalBytesProcessed: Int?
    let filesNew: Int?
    let filesChanged: Int?
    let filesUnmodified: Int?
    let snapshotId: String?
    
    enum CodingKeys: String, CodingKey {
        case messageType = "message_type"
        case totalFilesProcessed = "total_files_processed"
        case totalBytesProcessed = "total_bytes_processed"
        case filesNew = "files_new"
        case filesChanged = "files_changed"
        case filesUnmodified = "files_unmodified"
        case snapshotId = "snapshot_id"
    }
}

private struct ResticGenericMessage: Decodable {
    let messageType: String
    let message: String?
    let level: String?
    
    enum CodingKeys: String, CodingKey {
        case messageType = "message_type"
        case message
        case level
    }
}

private extension ResticBackupSummary {
    mutating func update(from message: ResticSummaryMessage) {
        if let totalFilesProcessed = message.totalFilesProcessed {
            self.totalFilesProcessed = totalFilesProcessed
        }
        if let totalBytesProcessed = message.totalBytesProcessed {
            self.totalBytesProcessed = Int64(totalBytesProcessed)
        }
        if let filesNew = message.filesNew {
            self.filesNew = filesNew
        }
        if let filesChanged = message.filesChanged {
            self.filesChanged = filesChanged
        }
        if let filesUnmodified = message.filesUnmodified {
            self.filesUnmodified = filesUnmodified
        }
        if let snapshotId = message.snapshotId {
            self.snapshotId = snapshotId
        }
    }
}
