//
//  Logger.swift
//  Locke
//
//  Created by Norris Nicholson on 10/16/23.
//

import Foundation

enum LogLevel {
    case trace
    case warning
    case error
}

struct LogEntry {
    let level: LogLevel
    let date: Date
    let text: String
    let predicate: Any?
}

class Logger: ObservableObject {
    public var console: [LogEntry]
    
    init() {
        self.console = []
    }
    
    
    public func clear() {
        self.console = []
    }
    
    public func log(_ level: LogLevel, _ str: String, _ predicate: Any? = nil) {
        let entry = LogEntry(level: level, date: Date(), text: str.trimmingCharacters(in: .whitespacesAndNewlines), predicate: predicate)
        console.append(entry)
        print (entry)
        
        // Prevent the console from growing past 500 entries to save memory
        while(console.count > 500) {
            console.remove(at: 0)
        }
    }
    
    public func trace(_ str: String, _ predicate: Any? = nil) {
        log(.trace, str, predicate)
    }
    
    public func warning(_ str: String, _ predicate: Any? = nil) {
        log(.warning, str, predicate)
    }
    
    public func error(_ str: String, _ predicate: Any? = nil) {
        log(.error, str, predicate)
    }
    
    public func export(name: String = "Locke.log") {
        var outputString: String = ""
        for entry in console {
            
            var predicate = ""
            if entry.predicate != nil {
                predicate = " :" + String(describing: entry.predicate)
            }
            
            outputString = outputString + "\(entry.date.description) | [\(entry.level)] \(entry.text)\(predicate)\n"
        }
        exportToFile(contents: outputString, name: name)
    }
    
    public func copy(_ entry: LogEntry) {
        var predicate = ""
        if entry.predicate != nil {
            predicate = " :" + String(describing: entry.predicate)
        }
        copyStringToClipboard("\(entry.date.description) | [\(entry.level)] \(entry.text)\(predicate)\n")
    }
}
