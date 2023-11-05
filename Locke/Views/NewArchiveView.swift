//
//  NewArchiveView.swift
//  Locke
//
//  Created by Norris Nicholson on 8/15/23.
//

import SwiftUI
import SFSafeSymbols

class NewArchiveViewModel: ObservableObject {
    var archiveNames: [String] = []
    
    // Input
    @Published var name = "" {
        didSet {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            isNameLengthValid = trimmedName.count >= 3
            isNameUnique = name.count > 0 && archiveNames.allSatisfy({ $0.caseInsensitiveCompare(trimmedName) != .orderedSame })
            
            validate()
        }
    }
    
    @Published var password = "" {
        didSet {
            isPasswordLengthValid = password.count >= 8 || password.count == 0
            isPasswordComplex = (isPasswordLengthValid && password.validatePassword()) || password.count == 0
            isPasswordConfirmValid = password.count > 0 && passwordConfirm == password
            
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
    @Published var isNameUnique = false
    @Published var isPasswordLengthValid = false
    @Published var isPasswordComplex = false
    @Published var isPasswordConfirmValid = false
    
    @Published var validated = false
    
    init() {
        password = ""
        passwordConfirm = ""
        name = ""
        validate()
    }
    
    func validate() -> Void {
        validated = isNameLengthValid && isNameUnique && isPasswordLengthValid && isPasswordComplex && isPasswordConfirmValid
    }
}

struct StoreKeyView: View {
    @State var keyArchive: ArchiveDataAndKey
    @Environment(\.dismiss) var dismiss
    @State var keyStoreCopy = true
    @State var keyStoreFile = true
    
    var book: NSDocument = NSDocument()
    
    var body: some View {
        VStack (alignment: .leading, spacing: 0) {
            Text ("Locke: Archive Created")
                .font(.system(.title3, design: .rounded))
                .bold()
                .foregroundColor(.primary)
            Text ("Please choose how you would like to store the recovery key")
                .font(.system(.body, design: .rounded))
                .foregroundColor(.primary)
            Form {
                Toggle("Copy to clipboard", isOn: $keyStoreCopy)
                Toggle("Generate Key File", isOn: $keyStoreFile)
            }.padding()
            
            HStack{
                Spacer()
                Button {
                    let jsonString = generateArchiveJsonString(archive: keyArchive.archive, key: keyArchive.key)
                    if (keyStoreFile) {
                        exportToFile(contents: jsonString, name: "\(keyArchive.archive.name ?? "Archive").locke")
                    }
                    if (keyStoreCopy) {
                        copyStringToClipboard(jsonString)
                    }
                    dismiss()
                } label: {
                    Text("Submit")
                        .font(.system(.body, design: .rounded))
                        .frame(width: 80, height: 20)
                        .cornerRadius(5)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(minWidth: 350, maxWidth: 350, minHeight: 160, maxHeight: 160)
        .padding(.horizontal)
    }
}

struct NewArchiveDataEntry: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var archiveManager: ArchiveManager
    
    @FetchRequest(sortDescriptors: [globalArchiveSortDescriptor]) var archives: FetchedResults<ArchiveData>
    
    @State var creating: Bool = false
    @StateObject private var newArchiveViewModel = NewArchiveViewModel()
    
    @State var selectedStorageDirectory: URL = archivesDirectory
    @State var selectedMountDirectory: URL = mountDirectory
    
    @Binding var keyArchive: ArchiveDataAndKey?
    @Binding var activeSheet: ActiveSheet
    
    var body: some View {
        VStack(alignment: .center) {
            Text ("Create an Archive")
                .font(.system(.title3, design: .rounded))
                .bold()
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading) {
                FormField(fieldName: "Archive Name", fieldValue: $newArchiveViewModel.name)
                RequirementText(text: "A minimum of 3 characters", isConformedTo: newArchiveViewModel.isNameLengthValid)
                RequirementText(text: "Must be unique", isConformedTo: newArchiveViewModel.isNameUnique)
                
                SecureFormField(fieldName: "Password", fieldValue: $newArchiveViewModel.password)
                RequirementText(iconName: "lock.open", text: "A minimum of 8 characters", isConformedTo: newArchiveViewModel.isPasswordLengthValid)
                RequirementText(iconName: "lock.open", text: "Complicated", isConformedTo: newArchiveViewModel.isPasswordComplex)
                
                SecureFormField(fieldName: "Confirm Password", fieldValue: $newArchiveViewModel.passwordConfirm)
                RequirementText(iconName: "lock.open", text: "Passwords must match", isConformedTo: newArchiveViewModel.isPasswordConfirmValid)
                
                VStack (alignment: .leading, spacing: 0) {
                    Text("Archive Path")
                        .font(.system(.title3, design: .rounded))
                        .bold()
                        .foregroundColor(.primary)
                    HStack {
                        Text(selectedStorageDirectory == archivesDirectory ? "Default" : fm.displayName(atPath: selectedStorageDirectory.path(percentEncoded: false)))
                            .font(.system(.callout, design: .monospaced))
                        Spacer(minLength: 0)
                        Button {
                            
                            // Set up an NSOpenPanel to select a directory
                            let savePanel = NSOpenPanel()
                            savePanel.level = .popUpMenu
                            savePanel.title = "Choose Archive Save Location"
                            savePanel.prompt = "Select Folder"
                            savePanel.showsTagField = false
                            savePanel.canChooseFiles = false
                            savePanel.canChooseDirectories = true
                            savePanel.allowsMultipleSelection = false
                            savePanel.showsHiddenFiles = true
                            savePanel.directoryURL = fm.homeDirectoryForCurrentUser
                            
                            // Open the panel and if the user selects a folder, update the selectedDirectory state
                            savePanel.begin { response in
                                if response == .OK, let destinationUrl = savePanel.url {
                                    selectedStorageDirectory = destinationUrl
                                }
                            }
                        } label: {
                            Text("Select")
                        }
                    }
                }.padding([.horizontal, .top])
                
                VStack (alignment: .leading, spacing: 0) {
                    Text("Mount Path")
                        .font(.system(.title3, design: .rounded))
                        .bold()
                        .foregroundColor(.primary)
                    HStack {
                        Text(selectedMountDirectory == mountDirectory ? "Default" : fm.displayName(atPath: selectedMountDirectory.path(percentEncoded: false)))
                            .font(.system(.callout, design: .monospaced))
                        Spacer(minLength: 0)
                        Button {
                            
                            // Set up an NSOpenPanel to select a directory
                            let savePanel = NSOpenPanel()
                            savePanel.level = .popUpMenu
                            savePanel.title = "Choose Archive Mount Location"
                            savePanel.prompt = "Select Folder"
                            savePanel.showsTagField = false
                            savePanel.canChooseFiles = false
                            savePanel.canChooseDirectories = true
                            savePanel.allowsMultipleSelection = false
                            savePanel.showsHiddenFiles = true
                            savePanel.directoryURL = fm.homeDirectoryForCurrentUser
                            
                            // Open the panel and if the user selects a folder, update the selectedDirectory state
                            savePanel.begin { response in
                                if response == .OK, let destinationUrl = savePanel.url {
                                    selectedMountDirectory = destinationUrl
                                }
                            }
                        } label: {
                            Text("Select")
                        }
                    }
                }.padding([.horizontal, .bottom])
            }
                
            HStack {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(.body, design: .rounded))
                        .frame(width: 80, height: 20)
                        .cornerRadius(5)
                }
                .keyboardShortcut(.cancelAction)
                
                Button {
                    if (newArchiveViewModel.validated) {
                        creating = true
                        let name = newArchiveViewModel.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        keyArchive = try! archiveManager.create(
                            name: name,
                            password: newArchiveViewModel.password,
                            bundleURL: selectedStorageDirectory == archivesDirectory ? nil : selectedStorageDirectory.appending(path: "/\(name).sparsebundle"),
                            mountURL: selectedMountDirectory == mountDirectory ? nil : selectedMountDirectory.appending(path: "/\(name)/")
                        )
                        activeSheet = .storeKey
                    }
                } label: {
                    Text(creating ? "Loading" : "Create")
                        .font(.system(.body, design: .rounded))
                        .frame(width: 80, height: 20)
                        .cornerRadius(5)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 260, maxWidth: 260, minHeight: 360, maxHeight: 450)
        .background(.clear)
        .onAppear(perform: {
            self.newArchiveViewModel.archiveNames = archives.map({ ($0 as ArchiveData).name ?? "unknown" })
        })
    }
}

enum ActiveSheet: Identifiable {
    case dataEntry
    case storeKey

    var id: Int {
        hashValue
    }
}

struct NewArchiveView: View {
    @Binding var errorMessage: AlertData?
    
    @State var activeSheet: ActiveSheet = .dataEntry
    @State var keyArchive: ArchiveDataAndKey?
    
    var body: some View {
        switch activeSheet {
        case .dataEntry:
            NewArchiveDataEntry(keyArchive: $keyArchive, activeSheet: $activeSheet)
        case .storeKey:
            if let keyArchive = keyArchive {
                StoreKeyView(keyArchive: keyArchive)
            }
        }
    }
}

struct NewArchiveView_Previews: PreviewProvider {
    static var previews: some View {
        @State var errorMessage: AlertData? = nil
        NewArchiveView(errorMessage: $errorMessage)
    }
}
