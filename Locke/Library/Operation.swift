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

// Last time a throttled progress update was applied. Only touched on the main thread
private var lastProgressUpdate = Date.distantPast

// Update an archive's operation progress on the main thread (Core Data objects belong to the main
// context). Start (0), finish (1) and reset (-1) always apply; intermediate values are throttled to
// one update every 0.3 seconds. Safe to call from any thread
func updateOperationProgress(archive: ArchiveData, progress: Double) {
    DispatchQueue.main.async {
        let isMilestone = progress == -1 || progress == 0 || progress == 1
        if isMilestone || abs(lastProgressUpdate.timeIntervalSinceNow) > 0.3 {
            lastProgressUpdate = Date()
            archive.operationProgress = progress
        }
    }
}

func startOperationProgress(archive: ArchiveData) {
    updateOperationProgress(archive: archive, progress: 0)
}
func stopOperationProgress(archive: ArchiveData) {
    updateOperationProgress(archive: archive, progress: -1)
}

// Run a command line task off the main thread and return its result
func runTask(executable: URL, arguments: [String] = [], inputPipeString: String? = nil) async throws -> Operation {
    try await withCheckedThrowingContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                continuation.resume(returning: try executeTask(executable: executable, arguments: arguments, inputPipeString: inputPipeString))
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

// Execute a command line task, blocking the calling thread until it exits. Prefer runTask, which
// keeps this off the main thread
func executeTask(executable: URL, arguments: [String] = [], inputPipeString: String? = nil) throws -> Operation {
    let task = Process()
    task.executableURL = executable
    task.arguments = arguments

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    task.standardOutput = stdoutPipe
    task.standardError = stderrPipe

    // Feed the input (e.g. a password for -stdinpass) through stdin, then close it
    if let input = inputPipeString {
        let inputPipe = Pipe()
        task.standardInput = inputPipe
        inputPipe.fileHandleForWriting.write(Data(input.utf8))
        try? inputPipe.fileHandleForWriting.close()
    }

    logger.trace("Task \(executable.path(percentEncoded: false)) \(arguments)")

    try task.run()

    // Drain both pipes while the task runs. Waiting for exit first deadlocks once a pipe's buffer
    // (64 KB) fills, which long-running commands with progress output can easily do
    var stderrData = Data()
    let stderrDone = DispatchGroup()
    stderrDone.enter()
    DispatchQueue.global(qos: .utility).async {
        stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        stderrDone.leave()
    }
    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    stderrDone.wait()
    task.waitUntilExit()

    return Operation(
        code: task.terminationStatus,
        success: task.terminationStatus == 0,
        stdout: String(data: stdoutData, encoding: encoding),
        stderr: String(data: stderrData, encoding: encoding))
}
