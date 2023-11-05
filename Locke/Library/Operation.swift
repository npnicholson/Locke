//
//  Operation.swift
//  Locke
//
//  Created by Norris Nicholson on 8/14/23.
//

import Foundation
import AppKit
let encoding: String.Encoding = .utf8
let hdiutil = URL(filePath: "/usr/bin/hdiutil")

struct Operation {
    let code: Int32
    let success: Bool
    let stdout: String?
    let stderr: String?
}

// Execute a command line task
func executeTask(executable: URL, arguments: [String] = [], inputPipeString: String? = nil) throws -> Operation {
    // Start a new process
    let task = Process()
    
    // Assign the launch path and arguments string array right away
    task.executableURL = executable
    task.arguments = arguments
    
    // Create and assign the output pipe
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    task.standardOutput = stdoutPipe
    task.standardError = stderrPipe
    
    // If innput pipe string has been defined, then also create and assign an input pipe
    if (inputPipeString != nil) {
        let inputPipe = Pipe()
        task.standardInput = inputPipe
        inputPipe.fileHandleForWriting.write(inputPipeString!.data(using: encoding)!)
        inputPipe.fileHandleForWriting.closeFile()
    }
    
    logger.trace("Task \(executable) \(arguments)")
    
    // Launch the task
    try task.run()
    task.waitUntilExit()
    
    // Grab the result from the output pipe. If it is nil, throw an error. Otherwise return the result
    let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: encoding)
    let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: encoding)

    return Operation(code: task.terminationStatus, success: task.terminationStatus == 0, stdout: stdout, stderr: stderr)
}

//func detachAll() throws {
//    let archives = try listAttached()
//    try archives.forEach { archive in
//        try archive.detach()
//    }
//}
//
//func attachAll() throws {
//    let archives = try listArchives(EmptySettings)
//    try archives.forEach { archive in
//        archive.password = "saffie"
//        try archive.attach()
//    }
//}
