//
//  RemoveArchiveView.swift
//  Locke
//
//  Created by Norris Nicholson on 8/16/23.
//

import SwiftUI
import SFSafeSymbols

// TODO: Remove

//struct RemoveArchiveView: View {
//    @Binding var errorMessage: AlertData?
//    @EnvironmentObject var archiveManager: ArchiveManager
//    @StateObject var archive: ArchiveData
//    
//    // Function to dismiss this view
//    @Environment(\.managedObjectContext) var moc
//    @Environment(\.dismiss) var dismiss
//    
//    
//    var body: some View {
//        VStack{
//            Text("Remove this Archive?")
//                .font(.system(.title, design: .rounded))
//                .foregroundColor(.primary)
//                .bold()
//                .padding(.top)
//            
//            Text("Archive will be moved to the trash.")
//                .font(.system(.body, design: .rounded))
//                .foregroundColor(.secondary)
//            
//            ArchiveView(archive: archive)
//                .padding()
//
//            HStack(spacing: 0) {
//                Button(role: .cancel, action: { dismiss() }) {
//                    Text("Cancel")
//                        .font(.system(.title3, design: .rounded))
//                        .foregroundColor(.blue)
//                        .bold()
//                        .padding()
//                        .frame(minWidth: 0, maxWidth: .infinity)
//                        .background(Color.white)
//                        .cornerRadius(0)
//                }
//                .buttonStyle(.plain)
//                .overlay(Divider(), alignment: .trailing)
//                
//                Button(role: .destructive, action: {
//                    archiveManager.remove(archive.objectID)
//                    dismiss()
//                }) {
//                    Text("Remove")
//                        .font(.system(.title3, design: .rounded))
//                        .foregroundColor(.red)
//                        .bold()
//                        .padding()
//                        .frame(minWidth: 0, maxWidth: .infinity)
//                        .background(Color.white)
//                        .cornerRadius(0)
//                }.buttonStyle(.plain)
//            }.overlay(Divider(), alignment: .top)
//        }
//        
//        .frame(minWidth: 300, maxWidth: 400, minHeight: 100, maxHeight: .infinity)
//        .background(Color.white)
//        
//    }
//}
//
//struct RemoveArchiveView_Previews: PreviewProvider {
//    static var previews: some View {
//        @State var errorMessage: AlertData? = nil
//        @ObservedObject var a = ArchiveData()
//        RemoveArchiveView(errorMessage: $errorMessage, archive: a)
//    }
//}
