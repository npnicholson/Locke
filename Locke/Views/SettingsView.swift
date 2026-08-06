//
//  SettingsView.swift
//  Locke
//
//  Created by Norris Nicholson on 10/14/23.
//

import SwiftUI
import Sparkle
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

    @AppStorage("setting.BackblazeKeyId") private var backblazeKeyId = ""
    @AppStorage("setting.BackblazeEndpoint") private var backblazeEndpoint = ""
    @AppStorage("setting.BackblazeResourcePath") private var backblazeResourcePath = ""

    @AppStorage("setting.ResticRepositoryURL") private var resticRepositoryURL = ""
    @AppStorage("setting.ResticExecutablePath") private var resticExecutablePath = ""
    @AppStorage("setting.ResticKeychainAccount") private var resticKeychainAccount = ""
    @AppStorage("setting.ResticExtraTags") private var resticExtraTags = ""
    
    @State var showConsole: Bool = false
    @State private var showKeychainAlert: Bool = false
    @State private var showKeychainError: Bool = false
    @State private var showAuthError: Bool = false
    @State private var showBackblazeKeychainAlert: Bool = false
    @State private var showBackblazeKeychainError: Bool = false
    @State private var showBackblazeAuthError: Bool = false
    @State private var showResticKeychainAlert: Bool = false
    @State private var showResticKeychainError: Bool = false
    @State private var resticKeychainErrorMessage: String = ""
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
                Toggle("Use date in cloud backup name", isOn: $backupAWSUseDate)
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
                Divider()
                Text("Backblaze Options")
                HStack {
                    Text("Backblaze Key ID")
                        .font(.callout)
                        .fontWeight(.regular)
                        .foregroundColor(.primary)
                    TextField("004abc...", text: $backblazeKeyId)
                }
                HStack {
                    Text("Backblaze S3 Endpoint")
                        .font(.callout)
                        .fontWeight(.regular)
                        .foregroundColor(.primary)
                    TextField("s3.us-west-004.backblazeb2.com", text: $backblazeEndpoint)
                }
                HStack {
                    Text("Backblaze Resource Path")
                        .font(.callout)
                        .fontWeight(.regular)
                        .foregroundColor(.primary)
                    TextField("s3://my-bucket/locke", text: $backblazeResourcePath)
                }
                Text("The Application Key should include write permissions for the bucket. The 'Use date in cloud backup name' setting above applies here as well.")
                    .font(.callout)
                    .fontWeight(.regular)
                    .foregroundColor(.secondary)
                HStack {
                    Button("Reauthenticate Backblaze") {
                        let success = lockeDelegate.BackblazeManager.authenticate()
                        if (!success) {
                            showBackblazeAuthError = true
                        }
                    }.alert(isPresented: $showBackblazeAuthError) {
                        Alert(title: Text("Error Authenticating"), message: Text("There was an error authenticating with Backblaze. Please check logs for more details"), primaryButton: .default(Text("Ok")), secondaryButton:
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
                        let created = lockeDelegate.BackblazeManager.storeCredentials(keyId: backblazeKeyId, applicationKey: "")
                        if (!created) {
                            showBackblazeKeychainError = true
                        } else {
                            showBackblazeKeychainAlert = true
                        }
                    }.alert(isPresented: $showBackblazeKeychainAlert) {
                        Alert(title: Text("Keychain Stub Created"), message: Text("A Keychain entry for \(backblazeKeyId) has been created. Add the Backblaze Application Key using the Keychain Access App in order to complete the setup."), primaryButton: .default(Text("Ok")), secondaryButton:
                            .default(
                                Text("Open Keychain Access"),
                                action: {
                                    let url = URL(filePath: "/System/Applications/Utilities/Keychain Access.app")
                                    let configuration = NSWorkspace.OpenConfiguration()
                                    NSWorkspace.shared.openApplication(at: url, configuration: configuration)
                                }
                            )
                        )
                    }.alert(isPresented: $showBackblazeKeychainError) {
                        Alert(title: Text("Keychain Store Error"), message: Text("A Keychain entry for \(backblazeKeyId) already exists. Please edit it directly in the Keychain Access App."), primaryButton: .default(Text("Ok")), secondaryButton:
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
                Divider()
                Text("Restic Options")
                HStack {
                    Text("Repository URL")
                        .font(.callout)
                        .fontWeight(.regular)
                        .foregroundColor(.primary)
                    TextField("sftp:user@host:/backups/locke", text: $resticRepositoryURL)
                }
                HStack {
                    Text("Restic Executable Path")
                        .font(.callout)
                        .fontWeight(.regular)
                        .foregroundColor(.primary)
                    TextField("/opt/homebrew/bin/restic", text: $resticExecutablePath)
                }
                HStack {
                    Text("Keychain Account")
                        .font(.callout)
                        .fontWeight(.regular)
                        .foregroundColor(.primary)
                    TextField("restic@example.com", text: $resticKeychainAccount)
                }
                HStack {
                    Text("Extra Tags (comma separated)")
                        .font(.callout)
                        .fontWeight(.regular)
                        .foregroundColor(.primary)
                    TextField("team,region", text: $resticExtraTags)
                }
                Text("Restic passwords are stored in Keychain under the service '\(ResticManager.keychainService)'. Update the entry with the correct password after creating it.")
                    .font(.callout)
                    .fontWeight(.regular)
                    .foregroundColor(.secondary)
                HStack {
                    Button("Create Restic Keychain Entry") {
                        let account = resticKeychainAccount.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !account.isEmpty else {
                            resticKeychainErrorMessage = "Enter a Keychain account before creating the Restic entry."
                            showResticKeychainError = true
                            return
                        }
                        let created = lockeDelegate.ResticManager.storePassword(account: account, password: "")
                        if created {
                            showResticKeychainAlert = true
                        } else {
                            resticKeychainErrorMessage = "A Keychain entry for \(account) already exists. Update it directly in Keychain Access."
                            showResticKeychainError = true
                        }
                    }.alert(isPresented: $showResticKeychainAlert) {
                        Alert(title: Text("Keychain Stub Created"), message: Text("A Keychain entry for \(resticKeychainAccount) has been created. Add the Restic password using the Keychain Access app."), primaryButton: .default(Text("Ok")), secondaryButton:
                            .default(
                                Text("Open Keychain Access"),
                                action: {
                                    let url = URL(filePath: "/System/Applications/Utilities/Keychain Access.app")
                                    let configuration = NSWorkspace.OpenConfiguration()
                                    NSWorkspace.shared.openApplication(at: url, configuration: configuration)
                                }
                            )
                        )
                    }.alert(isPresented: $showResticKeychainError) {
                        Alert(title: Text("Keychain Store Error"), message: Text(resticKeychainErrorMessage), primaryButton: .default(Text("Ok")), secondaryButton:
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
//                    CheckForUpdatesView(updater: lockeDelegate.UpdateManager.updaterController.updater)
                    Button("Relaunch Locke") {
                        let task = Process()
                        task.launchPath = "/bin/sh"
                        task.arguments = ["-c", "sleep 1; open \"\(Bundle.main.bundlePath)\""]
                        task.launch()
                        
                        NSApp.terminate(self)
                        exit(0)
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
