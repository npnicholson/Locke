//
//  Favorites.swift
//  Locke
//
//  Created by Norris Nicholson on 8/15/23.
//

import SwiftUI

struct FavoritesView: View {
    @Binding var errorMessage: AlertData?
    
    @FetchRequest(sortDescriptors: [globalArchiveSortDescriptor]) var archives: FetchedResults<ArchiveData>
    @Environment(\.managedObjectContext) var moc
    
    var body: some View {
        VStack {
            List(archives.filter({ $0.favorite })) { archive in
                ArchiveListItemView(errorMessage: $errorMessage, archive: archive, showFavorite: false)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 3))
                    .listRowSeparator(.visible)
            }
            .listStyle(.inset)
        }
        .frame(minWidth: 550, maxWidth: .infinity, maxHeight: .infinity)
        .overlay(Group {
            if archives.isEmpty {
                Text("Star an Archive to view it here!")
                    .font(.callout)
                    .foregroundColor(.primary)
            }
        })
    }
}

struct Favorites_Previews: PreviewProvider {
    static var previews: some View {
        @State var errorMessage: AlertData? = nil
        FavoritesView(errorMessage: $errorMessage)
    }
}
