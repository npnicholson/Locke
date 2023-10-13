//
//  NewArchiveView.swift
//  Locke
//
//  Created by Norris Nicholson on 8/15/23.
//

import SwiftUI
import SFSafeSymbols

func mapSize(_ size: CGFloat) -> Int16 {
    return Int16(round(size * 96 + 4))
}

class NewArchiveViewModel: ObservableObject {
    var archiveNames: [String] = []
    
    // Input
    @Published var name = "" {
        didSet {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            isNameLengthValid = trimmedName.count >= 3
            isNameUnique = archiveNames.allSatisfy({ $0.caseInsensitiveCompare(trimmedName) != .orderedSame })
            
            validate()
        }
    }
    
    @Published var password = "" {
        didSet {
            isPasswordLengthValid = password.count >= 8
            isPasswordComplex = password.validatePassword()
            isPasswordConfirmValid = passwordConfirm == password
            
            validate()
        }
    }
    @Published var passwordConfirm = "" {
        didSet {
            isPasswordConfirmValid = passwordConfirm == password
            
            validate()
        }
    }
    
    @Published var maxSize: CGFloat = 4/100
    
    // Output
    @Published var isNameLengthValid = false
    @Published var isNameUnique = true
    @Published var isPasswordLengthValid = false
    @Published var isPasswordComplex = false
    @Published var isPasswordConfirmValid = false
    
    @Published var validated = false
    
    func validate() -> Void {
        validated = isNameLengthValid && isNameUnique && isPasswordLengthValid && isPasswordComplex && isPasswordConfirmValid
    }
}

struct NewArchiveView: View {
    @EnvironmentObject var archiveManager: ArchiveManager
    
    // Function to dismiss this views
    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) var moc

    @Binding var errorMessage: AlertData?
    
    @State var presentKeySheet: Bool = false
    @State var keyArchive: ArchiveDataAndKey?
    
    @StateObject private var newArchiveViewModel = NewArchiveViewModel()
    @FetchRequest(sortDescriptors: [globalArchiveSortDescriptor]) var archives: FetchedResults<ArchiveData>
    
    @State private var presentSymbolPicker = false
    @State var creating: Bool = false
    

    
    var body: some View {
        VStack(alignment: .center) {
            Text("Create an Archive")
                .font(.system(.title, design: .rounded))
                .bold()
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom)
            
            Group {
                VStack {
                    FormField(fieldName: "Archive Name", fieldValue: $newArchiveViewModel.name)
                    RequirementText(text: "A minimum of 3 characters", isConformedTo: newArchiveViewModel.isNameLengthValid)
                    RequirementText(text: "Must be unique", isConformedTo: newArchiveViewModel.isNameUnique)
                }.padding(.bottom)
            }
            
            Group {
                
                SecureFormField(fieldName: "Password", fieldValue: $newArchiveViewModel.password)
                
                VStack {
                    RequirementText(iconName: "lock.open", text: "A minimum of 8 characters", isConformedTo: newArchiveViewModel.isPasswordLengthValid)
                    RequirementText(iconName: "lock.open", text: "Complicated", isConformedTo: newArchiveViewModel.isPasswordComplex)
                }
                
                SecureFormField(fieldName: "Confirm Password", fieldValue: $newArchiveViewModel.passwordConfirm)
                
                RequirementText(iconName: "lock.open", text: "Passwords must match", isConformedTo: newArchiveViewModel.isPasswordConfirmValid)
                    .padding(.bottom)
                
            }
            
//            Button {
//                presentSymbolPicker = true
//            } label: {
//                VStack {
//                    Image(systemName: icon)
//                        .foregroundColor(Color("Icon"))
//                        .font(.system(size: 45))
//                        .frame(width: 50, height: 40)
//                    Text("Choose an Icon")
//                        .font(.system(.body, design: .rounded))
//                        .foregroundColor(.secondary)
//                }
//            }
//            .sheet(isPresented: $presentSymbolPicker) {
//                SymbolPicker(symbol: $icon)
//            }
//                .buttonStyle(.plain)
//                .padding(.bottom)
            
//            Group {
//                HStack {
//                    Text("Max Size:")
//                        .font(.system(.body, design: .rounded))
//                        .foregroundColor(.secondary)
//                    Spacer()
//                    Text("\(mapSize(newArchiveViewModel.maxSize)) Gb")
//                        .font(.system(.body, design: .rounded))
//                        .foregroundColor(.secondary)
//                }
//                    .font(.system(.title3, design: .rounded))
//                    .foregroundColor(.primary)
//
//                Slider(value: $newArchiveViewModel.maxSize)
//                    .padding(.bottom)
//            }
//            .padding(.horizontal)
            
            Button(action: {
                creating = true

                let name = newArchiveViewModel.name.trimmingCharacters(in: .whitespacesAndNewlines)
                
                keyArchive = try! archiveManager.create(
                    name: name,
                    password: newArchiveViewModel.password
                )
                
                presentKeySheet = true
            }) {
                Text(creating ? "Loading" : "Create")
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.white)
                    .bold()
                    .padding()
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .background(LinearGradient(gradient: Gradient(colors: [Color(red: 251/255, green: 128/255, blue: 128/255), Color(red: 253/255, green: 193/255, blue: 104/255)]), startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
            .buttonStyle(.plain)
            .disabled(!newArchiveViewModel.validated || creating)
            .keyboardShortcut(.defaultAction)
            .sheet(isPresented: $presentKeySheet, onDismiss: { dismiss() }) {
                if let keyArchive = keyArchive {
                    ManageKeyView(keyArchive: keyArchive)
                }
            }
        }
        .padding()
        .frame(minWidth: 300, maxWidth: 400, minHeight: 100, maxHeight: .infinity)
        .background(.clear)
        .onAppear(perform: {
            self.newArchiveViewModel.archiveNames = archives.map({ ($0 as ArchiveData).name ?? "unknown" })
        })
    }
}

struct NewArchiveView_Previews: PreviewProvider {
    static var previews: some View {
        @State var errorMessage: AlertData? = nil
        NewArchiveView(errorMessage: $errorMessage)
    }
}
