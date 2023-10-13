//
//  ContentView.swift
//  Locke
//
//  Created by Norris Nicholson on 8/14/23.
//

import SwiftUI

/// 1
struct Page : Identifiable, Hashable {
    var id = UUID()
    var title: String
    var systemImage: String
}

let summaryPage = Page(title: "Summary", systemImage: "line.3.horizontal")
let favoritesPage = Page(title: "Favotites", systemImage: "heart")
let archivesPage = Page(title: "Archives", systemImage: "archivebox")
let newPage = Page(title: "New", systemImage: "square.grid.3x1.folder.badge.plus")
let backupPage = Page(title: "Backup", systemImage: "square.and.arrow.up")
let restorePage = Page(title: "Restore", systemImage: "square.and.arrow.down")
let recoverPage = Page(title: "Recover", systemImage: "exclamationmark.lock")
let settingsPage = Page(title: "Settings", systemImage: "gearshape")


func NavLink(_ page: Page) -> some View {
    return NavigationLink (value: page) {
        Label {
            Text(page.title)
                .font(.body)
                .foregroundColor(.primary)
                .padding(.leading)
        } icon: {
            Image(systemName: page.systemImage)
                .font(.title3)
        }
    }
}

//struct ArchiveData {
//    // Decoded Variables
//    let id: UUID
//    let name: String
//    let bundleURL: URL
//    let mountURL: URL
//    let maxSize: Int16
//    var favorite: Bool
//
//    var order: Int16
//
//    // Non-decoded Variables
//    var password: String
//}

struct ContentView: View {
    @State public var selectedPage: Page? = favoritesPage
    @State var errorMessage: AlertData? = nil
    
    @Environment(\.managedObjectContext) var moc
    @FetchRequest(sortDescriptors: [globalArchiveSortDescriptor]) var archives: FetchedResults<ArchiveData>
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedPage) {
                NavLink(favoritesPage)
                NavLink(archivesPage)
                Divider()
                NavLink(settingsPage)
            }
            .navigationSplitViewColumnWidth(150)
        } detail: {
            if let selectedPage {
                switch (selectedPage.id) {
                case summaryPage.id: SummaryView(errorMessage: $errorMessage)
                        .navigationTitle("Summary")
                        .navigationSubtitle("Summary Details bla")
                case favoritesPage.id: FavoritesView(errorMessage: $errorMessage)
                        .navigationTitle("Favorites")
                        .navigationSubtitle("Favorites Details bla")
                case archivesPage.id: ArchivesView(errorMessage: $errorMessage)
                        .navigationTitle("Archive")
                        .navigationSubtitle("Archive Details bla")
                        .navigationSplitViewStyle(.balanced)
                        .background(.clear)
                case newPage.id: NewArchiveView(errorMessage: $errorMessage)
                        .navigationTitle("Archive")
                        .navigationSubtitle("Archive Details bla")
//                case backupPage.id: Home()
//                case restorePage.id: Home()
//                case recoverPage.id: Home()
//                case settingsPage.id: Home()
                default: Text ("Unknown Selection")
                }
            }
        }
        .alert(item: $errorMessage) { data in
            Alert(title: Text(data.title), message: Text(data.message), dismissButton: .cancel(Text("Dismiss")))
        }
        .frame(minHeight: 300)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(selectedPage: summaryPage)
    }
}
