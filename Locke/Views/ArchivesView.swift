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
    var body: some View {
        HStack (spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(archive.name ?? "Unknown")
                    .font(.headline)
                    .help("ID: \(archive.id?.uuidString ?? "Unknwon")")
                HStack {
                    Text("Size \(formatBytes(archive.size))")
                        .font(.callout)
                        .fontWeight(.regular)
                        .foregroundColor(.secondary)
                    if let modified = archive.modified {
                        Text("Modified \(modified.formatted(date: .abbreviated, time: .shortened))")
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
                HStack {
                    ArchiveView(archive: archive)
                    Spacer()
                    Button {
                        if (archive.attached) {
                            archiveManager.close(archive.objectID)
                        } else {
                            archiveManager.open(archive.objectID)
                        }
                    } label: { 
                        Image(systemName: archive.attached ? "eject.fill" : "lock")
                            .frame(width: 15)
                    }
                    .buttonStyle(.plain)
                    .help(archive.attached ? "Lock archive" : "Unlock archive")
                    
                    
                    if (showFavorite) {
                        Button {
                            archive.favorite = !archive.favorite
                            try? moc.save()
                        } label: {
                            Image(systemName: archive.favorite ? "star.fill" : "star")
                        }
                        .buttonStyle(.plain)
                        .help(archive.favorite ? "Unfavorite archive" : "Favorite archive")
                    }
                    Menu {
                        Button (archive.attached ? "Lock" : "Unlock") {
                            if (archive.attached) {
                                archiveManager.close(archive.objectID)
                            } else {
                                archiveManager.open(archive.objectID)
                            }
                        }
                        .help(archive.attached ? "Lock this archive" : "Unlock this archive")
                        
                        Button ("Reveal in Finder") {
                            archiveManager.show(archive.objectID)
                        }
                        .disabled(!archive.attached)
                        .help(archive.attached ? "Open archive in Finder" : "")
                       
                        Button ("Compact") {
                            archiveManager.compact(archive.objectID)
                        }
                        .disabled(archive.attached)
                        .help(archive.attached ? "" : "Compact archive to recover free space")

                        Divider()

                        Button ("Remove Archive", role: .destructive) {
                            presentRemoveArchive = true
                        }
                        .disabled(archive.attached)
                        .help(archive.attached ? "" : "Remove archive")
                        
                        
                    } label: {
                        Image(systemSymbol: SFSymbol.line3Horizontal)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .confirmationDialog("Are you sure you want to remove \(archive.name ?? "this archive")?", isPresented: $presentRemoveArchive) {
            Button("Remove", role: .destructive) {
                archiveManager.remove(archive.objectID)
            }
        }
        .gesture(TapGesture(count: 2).onEnded {
            if (archive.attached) {
                archiveManager.show(archive.objectID)
            } else {
                archiveManager.open(archive.objectID)
            }
        })
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
//                    .contextMenu {
//                            Button {
//                                print("Change country setting")
//                            } label: {
//                                Label("Choose Country", systemImage: "globe")
//                            }
//
//                            Button {
//                                print("Enable geolocation")
//                            } label: {
//                                Label("Detect Location", systemImage: "location.circle")
//                            }
//                        }
            }
            .listStyle(.inset)
            .background(.clear)
        }
        .frame(minWidth: 550, maxWidth: .infinity, maxHeight: .infinity)
        .overlay(Group {
            if archives.isEmpty {
                Text("Create an Archive to get started!")
                    .font(.callout)
                    .foregroundColor(.primary)
            }
        })
//        .onAppear() {
//            print (archives)
//
//            archives.forEach { archive in
//                moc.delete(archive)
//            }
//
//            try? moc.save()
//
//        }
    }
}

struct Archives_Previews: PreviewProvider {
    static var previews: some View {
        @State var errorMessage: AlertData? = nil
        ArchivesView(errorMessage: $errorMessage)
    }
}
