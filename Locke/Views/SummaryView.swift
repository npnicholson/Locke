//
//  Summary.swift
//  Locke
//
//  Created by Norris Nicholson on 8/14/23.
//

import SwiftUI
import SFSafeSymbols
import CoreData

struct ArchiveGridTile: View {
    @ObservedObject var archive: ArchiveData
    @Binding var modified: Date?
    @Binding var size: String?
    @Binding var icon: String?
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerSize: .init(width: 20, height: 20))
                .fill(.blue)
                
            VStack (alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon ?? SFSymbol.folderFill.rawValue)
                        .foregroundColor(.blue)
                        .opacity(0.4)
                        .font(.system(size: 25))
                        .frame(width: 30, height: 25)
                    
                    Text("\(archive.name ?? "Unknown")")
                        .font(.system(.title, design: .monospaced))
                        .fontWeight(.regular)
                        .foregroundColor(.primary)
                }
                Text("ID: \(archive.id?.uuidString ?? "Unknown")")
                    .font(.system(.callout, design: .monospaced))
                    .fontWeight(.regular)
                    .foregroundColor(.primary)
                
                HStack {
                    VStack (alignment: .leading) {
                        Text("Size")
                            .font(.body)
                            .fontWeight(.regular)
                            .foregroundColor(.primary)
                        if let size = size {
                            Text("\(size)")
                                .font(.body)
                                .fontWeight(.regular)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Unknown")
                                .font(.body)
                                .fontWeight(.regular)
                                .foregroundColor(.secondary)
                        }
                    }
                    VStack (alignment: .leading) {
                        Text("Max")
                            .font(.body)
                            .fontWeight(.regular)
                            .foregroundColor(.primary)
                        Text("\(archive.maxSize) GB")
                            .font(.body)
                            .fontWeight(.regular)
                            .foregroundColor(.secondary)
                    }
                    VStack (alignment: .leading) {
                        Text("Modified")
                            .font(.body)
                            .fontWeight(.regular)
                            .foregroundColor(.primary)

                        if let modified = modified {
                            Text("\(modified.formatted(date: .abbreviated, time: .shortened))")
                                .font(.body)
                                .fontWeight(.regular)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Unknown")
                                .font(.body)
                                .fontWeight(.regular)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                
//                    Grid {
//                        GridRow(alignment: .lastTextBaseline) {
//                            Text("Size")
//                                .font(.body)
//                                .fontWeight(.regular)
//                                .foregroundColor(.primary)
//                            Text("Max")
//                                .font(.body)
//                                .fontWeight(.regular)
//                                .foregroundColor(.primary)
//                        }.frame(width: 75)
//                        GridRow {
//                            if let size = size {
//                                Text("\(size)")
//                                    .font(.body)
//                                    .fontWeight(.regular)
//                                    .foregroundColor(.secondary)
//                            } else {
//                                Text("Unknown")
//                                    .font(.body)
//                                    .fontWeight(.regular)
//                                    .foregroundColor(.secondary)
//                            }
//                            Text("\(archive.maxSize) GB")
//                                .font(.body)
//                                .fontWeight(.regular)
//                                .foregroundColor(.secondary)
//                        }
//                    }
                
                //            HStack {
                //                if let size = size {
                //                    Text("Size \(size)")
                //                        .font(.callout)
                //                        .fontWeight(.regular)
                //                        .foregroundColor(.secondary)
                //                } else {
                //                    Text("Size Unknown")
                //                        .font(.callout)
                //                        .fontWeight(.regular)
                //                        .foregroundColor(.secondary)
                //                }
                //                Text("Max \(archive.maxSize) GB")
                //                    .font(.callout)
                //                    .fontWeight(.regular)
                //                    .foregroundColor(.secondary)
                //            }
                
//                if let modified = modified {
//                    Text("Modified \(modified.formatted(date: .abbreviated, time: .shortened))")
//                        .font(.callout)
//                        .fontWeight(.regular)
//                        .foregroundColor(.secondary)
//                } else {
//                    Text("Modified Never")
//                        .font(.callout)
//                        .fontWeight(.regular)
//                        .foregroundColor(.secondary)
//                }
            }
        }
        .frame(minWidth: 350, maxWidth: 400, minHeight: 75, maxHeight: 100)
    }
}

struct ArchiveGrid: View {
    @Binding var errorMessage: AlertData?
    
    @FetchRequest(sortDescriptors: [globalArchiveSortDescriptor]) var archives: FetchedResults<ArchiveData>
    
    
    @State var modified: Date? = Date()
    @State var size: String? = "57.3 Mb"
    @State var icon: String? = "folder"
    
    var body: some View {
        ArchiveGridTile(archive: archives[0], modified: $modified, size: $size, icon: $icon)
        
    }
}

//func generateArchive(context: NSManagedObjectContext) -> ArchiveDataAndKey {
//    let archive = ArchiveData(context: context)
//    // Store the ID and bundle/mount urls
//    let id = UUID()
//    archive.id = id
//    archive.bundleURL = defaultArchiveBundleURL(id: id)
//    archive.mountURL = defaultArchiveMountURL(id: id)
//
//    // Set up initial values
//    archive.attached = false
//    archive.favorite = false
//    archive.icon = SFSymbol.folderFill.rawValue
//    archive.lastOpened = Date.distantPast
//    archive.maxSize = 8
//    archive.modified = Date.distantPast
//    archive.name = "Test Archive"
//    archive.created = Date()
//    archive.size = 0
//    
//    return ArchiveDataAndKey(archive: archive, key: "oPveGGPn1DsP/lTKdkiKI8ObTZcVxREAZOq1Sx17AoiOAIn0Lhmp+x0invCj62/bBgaNFayAb9+gVRhHZZcyyA==")
//}

struct SummaryView: View {
    @Binding var errorMessage: AlertData?
    @State var presentNewArchiveModal: Bool = false
    @State var str: String = ""
    
    @State var hover: Bool = false
    @State var plusAppSize: Double = 20
    @State var plusSquareSize: Double = 1
    @State var buttonVerticalScale: Double = 1
    @State var buttonHorizontalScale: Double = 1


    @State var presentTest = true
    
    var body: some View {
        Button {
            presentNewArchiveModal = true
        } label: {
            ZStack {
                // Clear Rectangle to hold space for the button expansion
                Rectangle()
                    .fill(.clear)
                    .padding()
                    .frame(minWidth: 0, maxWidth: 200 * 1.02, minHeight: 50, maxHeight: 50 * 1.05)
                    .padding(.horizontal)

                // Background Rectangle which expands on hover
                Rectangle()
                    .fill(Color(red: 100/255, green: 184/255, blue: 207/255))
                    .padding()
                    .frame(minWidth: 0, maxWidth: 200 * buttonHorizontalScale, minHeight: 50, maxHeight: 50 * buttonVerticalScale)
                    .background(Color(red: 100/255, green: 184/255, blue: 207/255))
                    .cornerRadius(10)
                    .padding(.horizontal)
                HStack {
                    Text("New Archive")
                        .font(.system(.title2, design: .rounded))
                        .foregroundColor(.white)
                        .bold()
                    ZStack {
                        Image(systemName: SFSymbol.plusSquare.rawValue)
                            .foregroundColor(.white)
                            .frame(width: 25, height: 25)
                            .font(.system(size: plusAppSize))
                        Image(systemName: SFSymbol.plusRectangleOnRectangle.rawValue)
                            .foregroundColor(.white)
                            .frame(width: 25, height: 25)
                            .font(.system(size: plusSquareSize))
                    }
                }
            }
            .onHover(perform: { over in
                if (over && !hover) {
                    withAnimation(.linear(duration: 0.15)) {
                        plusAppSize = 1
                        plusSquareSize = 20
                        buttonVerticalScale = 1.05
                        buttonHorizontalScale = 1.02
                    }
                } else if (!over && hover) {
                    withAnimation(.linear(duration: 0.15)){
                        plusAppSize = 20
                        plusSquareSize = 1
                        buttonVerticalScale = 1
                        buttonHorizontalScale = 1
                    }
                }
                hover = over

            })
        }
        .shadow(radius: 5)
        .buttonStyle(.plain)
        .padding(.vertical)
        .sheet(isPresented: $presentNewArchiveModal) {
            NewArchiveView(errorMessage: $errorMessage)
        }
    }

}
