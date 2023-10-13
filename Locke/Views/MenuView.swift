//
//  MenuView.swift
//  Locke
//
//  Created by Norris Nicholson on 8/25/23.
//

import SwiftUI
import SFSafeSymbols
import Combine

func timeSince(_ from: Date?) -> String{
    if let from = from {
     
        let delta = from.distance(to: Date())
        
        
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional

        return formatter.string(from: TimeInterval(delta))!
        
        
    } else {
        return ""
    }
}

struct MenuArchiveButton: View {
    @EnvironmentObject var archiveManager: ArchiveManager
    @ObservedObject var archive: ArchiveData
    
    var body: some View {
        Button {
            if (archive.attached) {
                archiveManager.close(archive.objectID)
            } else {
                archiveManager.open(archive.objectID)
            }
        } label: {
            Image(systemSymbol: archive.attached ? SFSymbol.lockOpen : SFSymbol.lock)
            Text(" \(archive.name ?? "Unknown")")
        }
    }
}

struct MenuView: View {
    
    @EnvironmentObject var lockeDelegate: LockeDelegate

    // Function to set up a fetch request for the list recent archvies. Select archives that are not favorites
    // and that have been modified within the last 7 days. Then cap the number of results at 5
    static func recentsFetchRequest() -> NSFetchRequest<ArchiveData> {
        let request: NSFetchRequest<ArchiveData> = ArchiveData.fetchRequest()
        
        // Calculate the cuttoff date by subtracting 7 days from todat
        let cuttoffDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        request.fetchLimit = 5
        
        // Sort by modified date
        request.sortDescriptors = [globalArchiveSortDescriptorModified]
        
        // Apply the search predicate
        request.predicate = NSPredicate(format: "favorite == NO AND modified >= %@", argumentArray: [cuttoffDate])
        
        return request
    }
    
    // Favorites fetch request. Sorted by defined archive order. Select archives that are favorites
    @FetchRequest( sortDescriptors: [globalArchiveSortDescriptor], predicate: NSPredicate(format: "favorite == YES")
    ) var favorites: FetchedResults<ArchiveData>
    
    
    // Recents fetch request. Sorted by modified date. Select archives that are not favorites and
    // that have been modified within the last 7 days
    @FetchRequest(fetchRequest: recentsFetchRequest()) var recents: FetchedResults<ArchiveData>
    
    @State var menuItemNumber = 1
    
    var body: some View {
        if (favorites.count > 0 ) {
            Text("Favorite Archives")
            ForEach(favorites) { archive in
                MenuArchiveButton(archive: archive)
            }
        }
        if (recents.count > 0 ) {
            Text("Recent Archives")
            ForEach(recents) { archive in
                MenuArchiveButton(archive: archive)
            }
        }
        if (favorites.count == 0 && recents.count == 0) {
            Text("No Favorite or Recent Archives")
        }
        Divider()
        Button("Show Application") {
            NSApp.sendAction(#selector(lockeDelegate.openMainView), to: nil, from:nil)
        }
        Button("Quit Locke") {
            NSApplication.shared.terminate(nil)
        }.keyboardShortcut("q")
    }
}
