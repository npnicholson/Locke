//
//  Archives.swift
//  Locke
//
//  Created by Norris Nicholson on 8/14/23.
//

import SwiftUI
import SFSafeSymbols

struct ArchiveView: View {
    @ObservedObject var archive: ArchiveData
    @EnvironmentObject var archiveManager: ArchiveManager
    
    var body: some View {
        HStack (spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(archive.name ?? "Unknown")
                        .font(.headline)
                        .help("ID: \(archive.id?.uuidString ?? "Unknwon")")
                    Text(archive.scheduledClose ?? "")
                        .font(.callout)
                        .fontWeight(.regular)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Size \(formatBytes(archive.size))")
                        .font(.callout)
                        .fontWeight(.regular)
                        .foregroundColor(.secondary)
                    if let modified = archive.modified {
                        Text("Modified \(modified.formatted(date: .numeric, time: .shortened))")
                            .font(.callout)
                            .fontWeight(.regular)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Modified Never")
                            .font(.callout)
                            .fontWeight(.regular)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

struct Observers {
    let mount: NSObjectProtocol
    let unmount: NSObjectProtocol
}

struct ArchiveContextMenu: View {
    @EnvironmentObject var archiveManager: ArchiveManager
    @ObservedObject var archive: ArchiveData
    @Binding var presentRemoveArchive: Bool
    
    var body: some View {
        Button (archive.attached ? "Lock" : "Unlock") {
            if (archive.attached) {
                archiveManager.close(archive.objectID)
            } else {
                archiveManager.open(archive.objectID)
            }
        }
        .help(archive.attached ? "Lock this archive" : "Unlock this archive")
        .keyboardShortcut("l")
        
        Button ("Reveal in Finder") {
            archiveManager.show(archive.objectID)
        }
        .disabled(!archive.attached)
        .help(archive.attached ? "Open archive in Finder" : "")
        .keyboardShortcut("o")
        
        Button ("Show Archive File") {
            archiveManager.showBundle(archive.objectID)
        }
        .help("Open encrypted archive in Finder")
        .keyboardShortcut("s")
        
        Button ("Compact") {
            archiveManager.compact(archive.objectID)
        }
        .disabled(archive.attached)
        .help(archive.attached ? "" : "Compact archive to recover free space")
        .keyboardShortcut("c")
        
        Button ("Backup") {
            archiveManager.backup(archive.objectID)
        }
        .disabled(archive.attached)
        .help(archive.attached ? "" : "Back up the archive")
        .keyboardShortcut("c")
        
        Divider()
        Text("Auto Closure")
        Button (" Schedule Closure") {
            if (!archive.watched && archive.attached) {
                self.archiveManager.watchdog.watch(archive: archive)
            }
        }
        .help("Schedule automatic closure of this archive")
        .disabled(archive.watched || !archive.attached)
        Button (" Cancel Closure") {
            self.archiveManager.watchdog.unwatch(archive: archive)
        }
        .help("Cancel automatic closure of this archive")
        .disabled(!archive.watched)
        Button (" Reset Closure") {
            self.archiveManager.watchdog.unwatch(archive: archive)
            self.archiveManager.watchdog.watch(archive: archive)
        }
        .help("Postpone automatic closure of this archive")
        .disabled(!archive.watched)
        
        Divider()
        Text("Recovery")
        Button (" Recover with Key") {
            archiveManager.recover(archive.objectID)
        }
        .disabled(archive.attached)
        .help(archive.attached ? "Recover Archive using a recovery key" : "")
        
        Button (" Copy Key to Clipboard") {
            archiveManager.generate(archive.objectID, .copy)
        }
        .help("Generate the recovery key and copy to clipboard")
        
        Button (" Save Key to Disk") {
            archiveManager.generate(archive.objectID, .store)
        }
        .help("Generate the recovery key and save to disk")
        
        Divider()
        
        Button ("Remove Archive", role: .destructive) {
            presentRemoveArchive = true
        }
        .disabled(archive.attached)
        .help(archive.attached ? "" : "Remove archive")
    }
}

struct ArchiveListItemView: View {
    @Environment(\.managedObjectContext) var moc
    @EnvironmentObject var archiveManager: ArchiveManager
    
    @Binding var errorMessage: AlertData?
    @ObservedObject var archive: ArchiveData
    @State var showFavorite: Bool
    @State private var isConfirming = false
    
    @State var presentRemoveArchive: Bool = false
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
            VStack {
                HStack(spacing: 0) {
                    ArchiveView(archive: archive)
                    Spacer()
                    Button {
                        if (archive.attached) {
                            archiveManager.close(archive.objectID)
                        } else {
                            archiveManager.open(archive.objectID)
                        }
                    } label: { 
                        ZStack {
                            Rectangle()
                                .fill(.clear)
                                .contentShape(Rectangle())
                                .frame(maxWidth: 25, maxHeight: 25)
                            Image(systemName: archive.attached ? "eject.fill" : "lock")
                                .frame(width: 15)
                        }
                    }
                    .buttonStyle(.plain)
                    .help(archive.attached ? "Lock archive" : "Unlock archive")
                    
                    
                    if (showFavorite) {
                        Button {
                            archive.favorite = !archive.favorite
                            try? moc.save()
                        } label: {
                            ZStack {
                                Rectangle()
                                    .fill(.clear)
                                    .contentShape(Rectangle())
                                    .frame(maxWidth: 25, maxHeight: 25)
                                Image(systemName: archive.favorite ? "star.fill" : "star")
                            }
                            
                        }
                        .buttonStyle(.plain)
                        .help(archive.favorite ? "Unfavorite archive" : "Favorite archive")
                    }
                    Menu {
                        ArchiveContextMenu(archive: archive, presentRemoveArchive: $presentRemoveArchive)
                    } label: {
                        ZStack {
                            Rectangle()
                                .fill(.clear)
                                .contentShape(Rectangle())
                                .frame(maxWidth: 25, maxHeight: 25)
                            Image(systemSymbol: SFSymbol.line3Horizontal)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .contextMenu {
            ArchiveContextMenu(archive: archive, presentRemoveArchive: $presentRemoveArchive)
        }
        .confirmationDialog("Are you sure you want to remove \(archive.name ?? "this archive")?", isPresented: $presentRemoveArchive) {
            Button("Remove", role: .destructive) {
                archiveManager.remove(archive.objectID)
            }
        }
    }
}

struct ArchivesView: View {
    @Binding var errorMessage: AlertData?
    @State var showFavorites = true
    
    @Environment(\.managedObjectContext) var moc
    @FetchRequest(sortDescriptors: [globalArchiveSortDescriptor]) var archives: FetchedResults<ArchiveData>
    
    var body: some View {
        VStack {
            List(archives) { archive in
                ArchiveListItemView(errorMessage: $errorMessage, archive: archive, showFavorite: showFavorites)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 3))
                    .listRowSeparator(.visible)
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
        }
        .overlay(Group {
            if archives.isEmpty {
                Text("Create an Archive to get started!")
                    .font(.callout)
                    .foregroundColor(.primary)
            }
        })
    }
}

struct Archives_Previews: PreviewProvider {
    static var previews: some View {
        @State var errorMessage: AlertData? = nil
        ArchivesView(errorMessage: $errorMessage)
    }
}
