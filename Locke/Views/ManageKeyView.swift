//
//  ManageKeyView.swift
//  Locke
//
//  Created by Norris Nicholson on 9/3/23.
//

import SwiftUI
import SFSafeSymbols

func copyKeyToClipboard (_ key: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.declareTypes([.string], owner: nil)
    pasteboard.setString(key, forType: .string)
}

struct ManageKeyView: View {
    @State var keyArchive: ArchiveDataAndKey
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        
        HStack (alignment: .top) {
            VStack {
                Image(systemSymbol: SFSymbol.lockRectangleStack)
                    .foregroundColor(.black)
                    .opacity(0.4)
                    .font(.system(size: 50))
                    .frame(width: 70, height: 70)
            }
            Spacer()
            VStack (alignment: .leading, spacing: 15) {
                Text ("Locke: Save your Key")
                    .font(.system(.title3, design: .rounded))
                    .bold()
                    .foregroundColor(.primary)
                VStack (alignment: .leading, spacing: 0) {
                    Text ("The key has been copied to your clipboard. Store it somewhere safe (LastPass).")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.primary)
                }
                HStack {
                    Spacer()
                    Button {
                        copyKeyToClipboard(keyArchive.key)
                    } label: {
                        Text("Copy Again")
                            .font(.system(.body, design: .rounded))
                            .frame(width: 80, height: 20)
                            .background(Color(.init(red: 93/255, green: 98/255, blue: 103/255, alpha: 0.5)))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.system(.body, design: .rounded))
                            .frame(width: 80, height: 20)
                            .background(Color(.init(red: 93/255, green: 98/255, blue: 103/255, alpha: 0.5)))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                }
                Spacer()
            }
        }
        .frame(width: 400)
        .padding(.horizontal)
        .padding(.top)
        .onAppear() {
            copyKeyToClipboard(keyArchive.key)
        }
    }
}

//struct ManageKeyView_Previews: PreviewProvider {
//    static func generateArchive() -> ArchiveData {
//        let archive = ArchiveData()
//        // Store the ID and bundle/mount urls
//        let id = UUID()
//        archive.id = id
//        archive.bundleURL = defaultArchiveBundleURL(id: id)
//        archive.mountURL = defaultArchiveMountURL(id: id)
//
//        // Set up initial values
//        archive.attached = false
//        archive.favorite = false
//        archive.icon = SFSymbol.folderFill.rawValue
//        archive.lastOpened = Date.distantPast
//        archive.maxSize = 8
//        archive.modified = Date.distantPast
//        archive.name = "Test Archive"
//        archive.created = Date()
//        archive.size = 0
//        return archive
//    }
//
//    static var previews: some View {
//        @State var key = "oPveGGPn1DsP/lTKdkiKI8ObTZcVxREAZOq1Sx17AoiOAIn0Lhmp+x0invCj62/bBgaNFayAb9+gVRhHZZcyyA=="
//        @State var archive = generateArchive()
//        ManageKeyView(archive: archive, key: key)
//            .frame(width: 250, height: 250)
//    }
//}
