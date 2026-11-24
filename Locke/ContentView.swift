//
//  ContentView.swift
//  Locke
//
//  Created by Norris Nicholson on 8/14/23.
//

import SwiftUI
import SFSafeSymbols

struct Page : Identifiable, Hashable {
    var id = UUID()
    var title: String
    var systemImage: String
}

let favoritesPage = Page(title: "Favotites", systemImage: "heart")
let archivesPage = Page(title: "Archives", systemImage: "archivebox")
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



struct ContentView: View {
    @State public var selectedPage: Page? = favoritesPage
    @State var errorMessage: AlertData? = nil
    @State var presentNewArchiveModal: Bool = false
    @State var isExporting = false
    
    @Environment(\.managedObjectContext) var moc
    @Environment(\.colorScheme) var colorScheme
    @FetchRequest(sortDescriptors: [globalArchiveSortDescriptor]) var archives: FetchedResults<ArchiveData>
    
    var body: some View {
        
        
        NavigationSplitView(columnVisibility: .constant(.all), sidebar: {
            List(selection: $selectedPage) {
                NavLink(favoritesPage)
                NavLink(archivesPage)
                Divider()
                NavLink(settingsPage)
            }
            .navigationSplitViewColumnWidth(170)
            .toolbar(removing: .sidebarToggle)
            .safeAreaInset(edge: .bottom) {
                Button {
                    presentNewArchiveModal = true
                } label: {
                    Label("New Archive", systemImage: SFSymbol.plus.rawValue)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                .padding(10)
            }
        }, detail: {
            if let selectedPage {
                switch (selectedPage.id) {
                case favoritesPage.id: FavoritesView(errorMessage: $errorMessage)
                case archivesPage.id: ArchivesView(errorMessage: $errorMessage)
                case settingsPage.id: SettingsView(errorMessage: $errorMessage)
                default: Text ("Unknown Selection")
                }
            }
        })
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $presentNewArchiveModal) {
            NewArchiveView(errorMessage: $errorMessage)
        }
        .alert(item: $errorMessage) { data in
            Alert(title: Text(data.title), message: Text(data.message), dismissButton: .cancel(Text("Dismiss")))
        }
        .frame(minWidth: 550, maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(selectedPage: archivesPage)
    }
}
