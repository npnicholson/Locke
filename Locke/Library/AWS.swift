//
//  AWS.swift
//  Locke
//
//  Created by Norris Nicholson on 3/31/24.
//

import Foundation
import SotoS3
import SotoS3FileTransfer
import NIO

// MARK: - Main Archive Manager (Start and Stop)
class AWSManager {
    let threadPool: NIOThreadPool
    let lockeDelegate: LockeDelegate
    
    var client: AWSClient?
    var s3: S3?
    var fileTransferManager: S3FileTransferManager?
    
    var authenticated: Bool
    
    init(_ delegate: LockeDelegate) {
        // Create an event loop group
        self.threadPool = NIOThreadPool(numberOfThreads: 4)
        threadPool.start()
        
        self.lockeDelegate = delegate
        
        authenticated = false
    }
    
    // On deinit, remove the observers
    deinit {
        try! self.fileTransferManager?.syncShutdown()
        try! self.client?.syncShutdown()
        try! self.threadPool.syncShutdownGracefully()
    }
    
    public func isAuthed() -> Bool{
        return self.authenticated
    }
    
    public func authenticate() -> Bool {
        
        // If we were already authenticated, then shutdown the file transfer manager before we re-authenticate
        if (self.authenticated) {
            try! self.fileTransferManager?.syncShutdown()
            try! self.client?.syncShutdown()
        }
        
        // Grab the timeout setting (convert min from setting to seconds here)
        guard let accessKeyId = UserDefaults.standard.string(forKey: "setting.AWSAccessKeyId") else {
            logger.error("AWS Authention Error. Error getting AWS Access Key ID from settings")
            self.authenticated = false
            return false
        }
        
        if (accessKeyId.isEmpty) {
            logger.error("AWS Authention Error. AWS Access Key ID not set")
            self.authenticated = false
            return false
        }
        
        do {
            // Get the secret access key from keychain
            let secretAccessKey = String(decoding: (try Keychain.readPassword(service: "Locke", account: accessKeyId)), as: UTF8.self)
            
            self.client = AWSClient(
                credentialProvider: .static(accessKeyId: accessKeyId, secretAccessKey: secretAccessKey),
                httpClientProvider: .createNew
            )
            
            // Set up S3 and the file transfer manager
            self.s3 = S3(client: self.client!, region: .useast2)
            self.fileTransferManager = S3FileTransferManager(s3: self.s3!, threadPoolProvider: .shared(threadPool))
            
        } catch {
            logger.error("AWS Authention Error. Unable to get Secret Access Key for Access ID \(accessKeyId)")
            self.authenticated = false
            return false
        }
        
        logger.trace("AWS Authenticated with Access ID \(accessKeyId)")
        
        self.authenticated = true
        return true
    }
    
    public func storeCredentials(accessKeyId: String, secretAccessKey: String) -> Bool {
        let currentPassword = try? Keychain.readPassword(service: "Locke", account: accessKeyId)
        if (currentPassword == nil) {
            Task {
                try! await Keychain.save(password: secretAccessKey.data(using: .utf8)!, service: "Locke", account: accessKeyId)
            }
        } else {
            logger.trace("AWS credential entry for id (\(accessKeyId)) already exists")
            return false
        }
        return true
    }
    
    public func upload (fromURL: String, toURL: String, progress: @escaping (Double) throws -> Void = { _ in }) async {
        try! await self.fileTransferManager!.copy(
            from: fromURL,
            to: S3File(url: toURL)!,
            progress: progress
        )
    }
}
