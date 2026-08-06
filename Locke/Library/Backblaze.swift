//
//  Backblaze.swift
//  Locke
//

import Foundation
import SotoS3
import SotoS3FileTransfer
import NIO

// MARK: - Backblaze B2 Manager (S3-compatible API)
class BackblazeManager {
    let threadPool: NIOThreadPool
    let lockeDelegate: LockeDelegate

    var client: AWSClient?
    var s3: S3?
    var fileTransferManager: S3FileTransferManager?

    var authenticated: Bool

    init(_ delegate: LockeDelegate) {
        self.threadPool = NIOThreadPool(numberOfThreads: 4)
        threadPool.start()

        self.lockeDelegate = delegate

        authenticated = false
    }

    deinit {
        try! self.fileTransferManager?.syncShutdown()
        try! self.client?.syncShutdown()
        try! self.threadPool.syncShutdownGracefully()
    }

    // Split a Backblaze endpoint into its host and region.
    // Accepts "s3.us-west-004.backblazeb2.com" with an optional scheme and trailing slash.
    public static func parse(endpoint: String) -> (host: String, region: String)? {
        var host = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        if host.hasPrefix("https://") { host = String(host.dropFirst("https://".count)) }
        if host.hasPrefix("http://") { host = String(host.dropFirst("http://".count)) }
        while host.hasSuffix("/") { host = String(host.dropLast()) }

        let parts = host.split(separator: ".")
        guard parts.count == 4,
              parts[0] == "s3",
              parts[2] == "backblazeb2",
              parts[3] == "com",
              !parts[1].isEmpty else {
            return nil
        }

        return (host: host, region: String(parts[1]))
    }

    public func isAuthed() -> Bool {
        return self.authenticated
    }

    public func authenticate() -> Bool {
        // If we were already authenticated, shut down before re-authenticating
        if (self.authenticated) {
            try! self.fileTransferManager?.syncShutdown()
            try! self.client?.syncShutdown()
        }

        self.authenticated = false

        guard let keyId = UserDefaults.standard.string(forKey: "setting.BackblazeKeyId"), !keyId.isEmpty else {
            logger.error("Backblaze Authentication Error. Backblaze Key ID not set")
            return false
        }

        guard let rawEndpoint = UserDefaults.standard.string(forKey: "setting.BackblazeEndpoint"), !rawEndpoint.isEmpty else {
            logger.error("Backblaze Authentication Error. Backblaze endpoint not set")
            return false
        }

        guard let endpoint = BackblazeManager.parse(endpoint: rawEndpoint) else {
            logger.error("Backblaze Authentication Error. Endpoint '\(rawEndpoint)' is not of the form s3.<region>.backblazeb2.com")
            return false
        }

        do {
            let applicationKey = String(decoding: (try Keychain.readPassword(service: "Locke", account: keyId)), as: UTF8.self)

            self.client = AWSClient(
                credentialProvider: .static(accessKeyId: keyId, secretAccessKey: applicationKey),
                httpClientProvider: .createNew
            )

            self.s3 = S3(
                client: self.client!,
                region: Region(rawValue: endpoint.region),
                endpoint: "https://\(endpoint.host)"
            )
            self.fileTransferManager = S3FileTransferManager(s3: self.s3!, threadPoolProvider: .shared(threadPool))

        } catch {
            logger.error("Backblaze Authentication Error. Unable to get Application Key for Key ID \(keyId)")
            return false
        }

        logger.trace("Backblaze Authenticated with Key ID \(keyId) in region \(endpoint.region)")

        self.authenticated = true
        return true
    }

    public func storeCredentials(keyId: String, applicationKey: String) -> Bool {
        let currentPassword = try? Keychain.readPassword(service: "Locke", account: keyId)
        if (currentPassword == nil) {
            Task {
                try! await Keychain.save(password: applicationKey.data(using: .utf8)!, service: "Locke", account: keyId)
            }
        } else {
            logger.trace("Backblaze credential entry for id (\(keyId)) already exists")
            return false
        }
        return true
    }

    public func upload(fromURL: String, toURL: String, progress: @escaping (Double) throws -> Void = { _ in }) async throws {
        guard let fileTransferManager = self.fileTransferManager else {
            throw BackblazeError.notAuthenticated
        }
        guard let destination = S3File(url: toURL) else {
            throw BackblazeError.invalidResourcePath(toURL)
        }
        try await fileTransferManager.copy(from: fromURL, to: destination, progress: progress)
    }

    enum BackblazeError: Error {
        case notAuthenticated
        case invalidResourcePath(String)
    }
}
