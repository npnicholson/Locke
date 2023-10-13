//
//  OpenArchiveView.swift
//  Locke
//
//  Created by Norris Nicholson on 8/15/23.
//

import SwiftUI

// TODO: Remove this file

//
//func openArchive(context: NSManagedObjectContext, archive: ArchiveData, password: String) -> Bool {
//
//    // TODO: Complete
////    let archive = Archive.fromData(data: archive)
////    archive.password = password
////    do {
////        try archive.attach()
////
////    } catch let error {
////        print (error)
////        return false
////    }
//
//    return true
//}
//
//struct OpenArchiveView: View {
//    @ObservedObject var archive: ArchiveData
//    @EnvironmentObject var ephemeralStorage: LockeEphemeralStorage
//
//    @Binding var modified: Date?
//    @Binding var size: Int64?
//
//    @State var password: String = ""
//    @State var shake: Bool = false
//    @State var opening: Bool = false
//
//    // Function to dismiss this view
//    @Environment(\.dismiss) var dismiss
//    @Environment(\.managedObjectContext) var moc
//
//    var body: some View {
//        VStack{
//            Text("Open an Archive")
//                .font(.system(.title, design: .rounded))
//                .foregroundColor(.primary)
//                .bold()
//                .padding(.bottom)
//
//            ArchiveView(archive: archive)
//                .padding(.horizontal)
//
//            SecureFormField(fieldName: "Password", fieldValue: $password)
//                .onSubmit {
//                    opening = true
//
//                    // Store the password in ephemeralStorage
//                    if let id = archive.id {
//                        ephemeralStorage.setPassword(id: id, password: password)
//                    }
//
//                    if (openArchive(context: moc, archive: archive, password: password)) {
//                        dismiss()
//                    } else {
//                        sleep(1)
//                        opening = false
//                        shake = true
//                    }
//                }
//
//            Button(action: {
//                opening = true
//
//                // Store the password in ephemeralStorage
//                if let id = archive.id {
//                    ephemeralStorage.setPassword(id: id, password: password)
//                }
//
//                if (openArchive(context: moc, archive: archive, password: password)) {
//                    dismiss()
//                } else {
//                    sleep(1)
//                    opening = false
//                    shake = true
//                }
//
//            }) {
//                Text(opening ? "Opening" : "Open")
//                .font(.system(.body, design: .rounded))
//                .foregroundColor(.white)
//                .bold()
//                .padding()
//                .frame(minWidth: 0, maxWidth: .infinity)
//                .background(LinearGradient(gradient: Gradient(colors: [Color(red: 251/255, green: 128/255, blue: 128/255), Color(red: 253/255, green: 193/255, blue: 104/255)]), startPoint: .leading, endPoint: .trailing))
//                .cornerRadius(10)
//                .padding(.horizontal)
//            }
//                .buttonStyle(.plain)
//                .disabled(opening)
//        }
//        .padding()
//        .frame(minWidth: 300, maxWidth: 400, minHeight: 100, maxHeight: .infinity)
//        .background(Color.white)
//        .shake($shake, repeatCount: 2, duration: 0.3, offsetRange: 8)
//
//    }
//}
//
//struct OpenArchiveView_Previews: PreviewProvider {
//    static var previews: some View {
//        @ObservedObject var archive = ArchiveData()
//        @State var modified: Date? = nil
//        @State var size: Int64? = nil
//        OpenArchiveView(archive: archive, modified: $modified, size: $size)
//    }
//}
