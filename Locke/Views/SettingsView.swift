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
    
    @AppStorage(.ejectOnClose) private var ejectOnClose = true
    @AppStorage(.compactOnDetach) private var compactOnDetach = true
    @AppStorage(.autoEject) private var autoEject = true
    @AppStorage(.autoEjectTimeout) private var autoEjectTimeout = 100
    
    @AppStorage(.showRecentsInMenu) private var showRecentsInMenu = true
    
    @AppStorage(.backupUseDate) private var backupAWSUseDate = false
    
    @AppStorage(.awsAccessKeyId) private var awsAccessKeyId = ""
    @AppStorage(.awsS3ResourcePath) private var awsS3ResourcePath = ""

    @AppStorage(.backblazeKeyId) private var backblazeKeyId = ""
    @AppStorage(.backblazeEndpoint) private var backblazeEndpoint = ""
    @AppStorage(.backblazeResourcePath) private var backblazeResourcePath = ""

    @AppStorage(.resticRepositoryURL) private var resticRepositoryURL = ""
    @AppStorage(.resticExecutablePath) private var resticExecutablePath = ""
    @AppStorage(.resticKeychainAccount) private var resticKeychainAccount = ""
    @AppStorage(.resticExtraTags) private var resticExtraTags = ""
    
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
        Form {
            Section("General") {
                LaunchAtLogin.Toggle()
                Toggle("Show Recently Accessed Archives in Menu (Requires Restart)", isOn: $showRecentsInMenu)
                Toggle("Eject all archives on application close", isOn: $ejectOnClose)
                Toggle("Compact archives when detaching", isOn: $compactOnDetach)
                Toggle("Auto eject archives", isOn: $autoEject)
                if (autoEject) {
                    Slider(value: .convert(from: $autoEjectTimeout), in: 1...480) {
                        Text("Timeout (minutes): \(autoEjectTimeout)")
                    } minimumValueLabel: {
                        Text("1")
                    } maximumValueLabel: {
                        Text("480")
                    }
                }
            }
            Section {
                Toggle("Use date in cloud backup name", isOn: $backupAWSUseDate)
                TextField("AWS Access Key ID", text: $awsAccessKeyId, prompt: Text("SomeAccessKeyId"))
                TextField("AWS S3 Resource Path", text: $awsS3ResourcePath, prompt: Text("s3://amu-backups/someone"))
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
            } header: {
                Text("AWS")
            }
            Section {
                TextField("Backblaze Key ID", text: $backblazeKeyId, prompt: Text("004abc..."))
                TextField("Backblaze S3 Endpoint", text: $backblazeEndpoint, prompt: Text("s3.us-west-004.backblazeb2.com"))
                TextField("Backblaze Resource Path", text: $backblazeResourcePath, prompt: Text("s3://my-bucket/locke"))
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
            } header: {
                Text("Backblaze")
            }
            Section {
                TextField("Repository URL", text: $resticRepositoryURL, prompt: Text("sftp:user@host:/backups/locke"))
                TextField("Restic Executable Path", text: $resticExecutablePath, prompt: Text("/opt/homebrew/bin/restic"))
                TextField("Keychain Account", text: $resticKeychainAccount, prompt: Text("restic@example.com"))
                TextField("Extra Tags (comma separated)", text: $resticExtraTags, prompt: Text("team,region"))
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
            } header: {
                Text("Restic")
            }
            Section {
                HStack {
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
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showConsole) {
            ConsoleView()
        }
    }
}
