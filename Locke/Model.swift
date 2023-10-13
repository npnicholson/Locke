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

// List all of the attached archives
//func listAttached() throws -> [Archive] {
//    // Get all files in the archives directory
//    let allFiles = try fm.contentsOfDirectory(at: mountDirectory, includingPropertiesForKeys: nil)
//    
//    // Go through each URL and convert it to the file name only, without the extension
//    var result: [Archive] = []
//    allFiles.forEach { url in
//        let name = url.lastPathComponent
//        result.append(Archive(name: name))
//    }
//    
//    return result
//}


//class LockeModel: ObservableObject {
//    let container = NSPersistentContainer(name: "Locke")
//    
//    init() {
//        container.loadPersistentStores { description, error in
//            if let error = error {
//                print("Core Data failed to load: \(error.localizedDescription)")
//            }
//        }
//    }
//}
