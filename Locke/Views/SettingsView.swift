//
//  SettingsView.swift
//  Locke
//
//  Created by Norris Nicholson on 10/14/23.
//

import SwiftUI
import LaunchAtLogin

private enum Tabs: Hashable {
    case general, advanced
}

struct SettingsView: View {
    @Binding var errorMessage: AlertData?
    
    @AppStorage("setting.EjectOnClose") private var ejectOnClose = true
    @AppStorage("setting.CompactOnDetach") private var compactOnDetach = true
    @AppStorage("setting.AutoEject") private var autoEject = true
    @AppStorage("setting.AutoEjectTimeout") private var autoEjectTimeout = 100
    
    @AppStorage("setting.ShowRecentsInMenu") private var showRecentsInMenu = true
    
    @AppStorage("setting.BackupAWSUseDate") private var backupAWSUseDate = false
    
    @AppStorage("setting.AWSAccessKeyId") private var awsAccessKeyId = ""
    @AppStorage("setting.AWSS3ResourcePath") private var awsS3ResourcePath = ""
    
    @State var showConsole: Bool = false
    @State private var showKeychainAlert: Bool = false
    @State private var showKeychainError: Bool = false
    @State private var showAuthError: Bool = false
    @EnvironmentObject var lockeDelegate: LockeDelegate
    
    var body: some View {
        HStack {
            VStack (alignment: .leading) {
                LaunchAtLogin.Toggle()
                Toggle("Show Recently Accessed Archives in Menu (Requires Restart)", isOn: $showRecentsInMenu)
                Toggle("Eject all archives on application close", isOn: $ejectOnClose)
                Toggle("Compact archives when detaching", isOn: $compactOnDetach)
                Toggle("Auto eject archives", isOn: $autoEject)
                if (autoEject) {
                    HStack {
                        HStack {
                            Text("Timeout (minutes): \(autoEjectTimeout)")
                            Spacer()
                        }
                        Slider(value: .convert(from: $autoEjectTimeout), in: 1...480) {
                        } minimumValueLabel: {
                            Text("1")
                        } maximumValueLabel: {
                            Text("480")
                        }
                    }
                }
                Divider()
                Text("AWS Options")
                Toggle("Use date in AWS backup name", isOn: $backupAWSUseDate)
                HStack {
                    Text("AWS Access Key ID")
                        .font(.callout)
                        .fontWeight(.regular)
                        .foregroundColor(.primary)
                    TextField("SomeAccessKeyId", text: $awsAccessKeyId)
                }
                HStack {
                    Text("AWS S3 Resource Path")
                        .font(.callout)
                        .fontWeight(.regular)
                        .foregroundColor(.primary)
                    TextField("s3://amu-backups/someone", text: $awsS3ResourcePath)
                }
                Text("The Access Key should include S3 write permissions for the S3 Resource Path.")
                    .font(.callout)
                    .fontWeight(.regular)
                    .foregroundColor(.secondary)
                HStack{
                    Button("Reauthenticate AWS") {
                        let success = lockeDelegate.AWSManager.authenticate()
                        if (!success) {
                            showAuthError = true
                        }
                    }.alert(isPresented: $showAuthError) {
                        Alert(title: Text("Error Authenticating"), message: Text("There was an error authenticating with AWS. Please check logs for more details"), primaryButton: .default(Text("Ok")), secondaryButton:
                            .default(
                                Text("Open Keychain Access"),
                                action: {
                                    let url = URL(filePath: "/System/Applications/Utilities/Keychain Access.app")
                                    let configuration = NSWorkspace.OpenConfiguration()
                                    NSWorkspace.shared.openApplication(at: url, configuration: configuration)
                                }
                            )
                        )
                    }
                    Button("Create Keychain Entry") {
                        let duplicateFound = lockeDelegate.AWSManager.storeCredentials(accessKeyId: awsAccessKeyId, secretAccessKey: "")
                        if (!duplicateFound) {
                            showKeychainError = true
                        } else {
                            showKeychainAlert = true
                        }
                    }.alert(isPresented: $showKeychainAlert) {
                        Alert(title: Text("Keychain Stub Created"), message: Text("A Keychain entry for \(awsAccessKeyId) has been created. Add the AWS Secret Access Key using the Keychain Access App in order to compleate the setup."), primaryButton: .default(Text("Ok")), secondaryButton:
                            .default(
                                Text("Open Keychain Access"),
                                action: {
                                    let url = URL(filePath: "/System/Applications/Utilities/Keychain Access.app")
                                    let configuration = NSWorkspace.OpenConfiguration()
                                    NSWorkspace.shared.openApplication(at: url, configuration: configuration)
                                }
                            )
                        )
                    }.alert(isPresented: $showKeychainError) {
                        Alert(title: Text("Keychain Store Error"), message: Text("A Keychain entry for \(awsAccessKeyId) already exists. Please edit it directly in the Keychain Access App."), primaryButton: .default(Text("Ok")), secondaryButton:
                            .default(
                                Text("Open Keychain Access"),
                                action: {
                                    let url = URL(filePath: "/System/Applications/Utilities/Keychain Access.app")
                                    let configuration = NSWorkspace.OpenConfiguration()
                                    NSWorkspace.shared.openApplication(at: url, configuration: configuration)
                                }
                            )
                        )
                    }
                }
                Spacer()
                HStack {
                    Spacer()
                    Text("\(Bundle.main.appName) Version \(Bundle.main.appVersionLong)")
                        .font(.callout)
                        .fontWeight(.regular)
                        .foregroundColor(.secondary)
                    Divider().frame(maxHeight: 20)
                    Text("Build Date \(Bundle.main.buildDate.formatted(date: .numeric, time: .shortened))")
                        .font(.callout)
                        .fontWeight(.regular)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Spacer()
                    Button("Show Console") {
                        showConsole = true
                    }
                    Button("Show Archive Folder") {
                        NSWorkspace.shared.selectFile(archivesDirectory.path(percentEncoded: false), inFileViewerRootedAtPath: "")
                    }
                }
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showConsole) {
            ConsoleView()
        }
    }
}
