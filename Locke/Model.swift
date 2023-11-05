//
//  Model.swift
//  Locke
//
//  Created by Norris Nicholson on 8/16/23.
//

import Foundation
import CoreData

struct ArchiveBundlePath {
    let id: UUID
    let url: URL
}

// List all of the archives stored on disk as a list of UUID
func listArchives() -> [ArchiveBundlePath] {
    // Get all files in the archives directory
    do {
        let allFiles = try fm.contentsOfDirectory(at: archivesDirectory, includingPropertiesForKeys: nil)
        
        // Filter those files so that we only have
        let filtered = allFiles.filter { $0.pathExtension == "sparsebundle" }
        
        // Go through each URL and convert it to the file name only, without the extension
        var result: [ArchiveBundlePath] = []
        filtered.forEach { url in
            let id = NSString(string: url.lastPathComponent).deletingPathExtension
            if let uuid = UUID(uuidString: id) {
                result.append(ArchiveBundlePath(id: uuid, url: url))
            }
        }
        
        return result
    } catch {
        return [ ]
    }
}
