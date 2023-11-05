//
//  File.swift
//  Locke
//
//  Created by Norris Nicholson on 8/30/23.
//

import Foundation
import AppKit

// Get the size of a directory
// @see: https://stackoverflow.com/questions/32814535/how-to-get-directory-size-with-swift-on-os-x
func directorySize(url: URL) -> Int64 {
    // Get a list of contents at this URL (files and folders)
    let contents: [URL]
    do {
        contents = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey])
    } catch {
        return 0
    }

    // Initial size for this folder
    var size: Int64 = 0

    // Go through each element in this folder. If it is a folder, recurse in. If it is a file, then get its size
    for url in contents {
        // Figure out if this is a folder or a file
        let isDirectoryResourceValue: URLResourceValues
        do {
            isDirectoryResourceValue = try url.resourceValues(forKeys: [.isDirectoryKey])
        } catch {
            continue
        }
    
        
        if isDirectoryResourceValue.isDirectory == true {
            // If it is a folder, then recursively call self on that new folder and add its size.
            size += directorySize(url: url)
        } else {
            // If it is a file, then get the size of the file and add it to the total
            let fileSizeResourceValue: URLResourceValues
            do {
                fileSizeResourceValue = try url.resourceValues(forKeys: [.fileSizeKey])
            } catch {
                continue
            }
        
            size += Int64(fileSizeResourceValue.fileSize ?? 0)
        }
    }
    return size
}

// Get the date a directory was last modified on disk
func directoryModified(url: URL) -> Date? {
    do {
        let attributes = try fm.attributesOfItem(atPath: url.path(percentEncoded: false))
        return attributes[.modificationDate] as? Date ?? Date()
    } catch {
        return nil
    }
}

// Bring up a prompt to ask the user where to store a given file
func exportToFile(contents: String, name: String) {
    let savePanel = NSSavePanel()
    savePanel.level = .popUpMenu
    savePanel.nameFieldStringValue = "\(name)"
    savePanel.begin { response in
        if response == .OK, let fileURL = savePanel.url {
            do {
                try contents.write(to: fileURL, atomically: true, encoding: .utf8)
                logger.trace("File saved successfully at \(fileURL)")
            } catch {
                logger.error("Error saving file: \(error)")
            }
        }
    }
}

// Copy a given string to the clipboard
func copyStringToClipboard (_ stringToCopy: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.declareTypes([.string], owner: nil)
    pasteboard.setString(stringToCopy, forType: .string)
}
