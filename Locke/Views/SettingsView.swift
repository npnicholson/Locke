//
//  SettingsView.swift
//  Locke
//
//  Created by Norris Nicholson on 10/14/23.
//

import SwiftUI

private enum Tabs: Hashable {
    case general, advanced
}

struct SettingsView: View {
    @Binding var errorMessage: AlertData?
    
    @AppStorage("setting.EjectOnClose") private var ejectOnClose = true
    @AppStorage("setting.CompactOnDetach") private var compactOnDetach = true
    @AppStorage("setting.AutoEject") private var autoEject = true
    @AppStorage("setting.AutoEjectTimeout") private var autoEjectTimeout = 100
    
    @State var showConsole: Bool = false
    @EnvironmentObject var lockeDelegate: LockeDelegate
    
    var body: some View {
        HStack {
            VStack (alignment: .leading) {
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
                Spacer()
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
