//
//  LockeApp.swift
//  Locke
//
//  Created by Norris Nicholson on 8/14/23.
//

/*
 
 Todo Features
 - Recently deleted archives
 - Display key to the user when an archive is created
 - Upload key to lastpass
 - Recover from lastpass
 - Recover from key
 - Backup to S3 or iCloud
 - Restore from S3 or iCloud
 - Change password / generate new key
 - Add hidden .dat file to the top level of the archive for recovery of core data info
 - Remove compact and add it to the close function
 - Add a ... with more options
 */

import SwiftUI
import AppKit
import SFSafeSymbols
import CryptoKit

let fm = FileManager.default

// Directories
let appSupportURL = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
let directoryURL = appSupportURL.appendingPathComponent("Locke")

let archivesDirectory = directoryURL.appending(path: "Archives")
let mountDirectory = directoryURL.appending(path: "Mount")
let orphansDirectory = directoryURL.appending(path: "Orphans")

// Build a fetch request which can be used to access archives in order
let globalArchiveFetchRequest = NSFetchRequest<ArchiveData>(entityName: "ArchiveData")
let globalArchiveSortDescriptor = NSSortDescriptor(key: "created", ascending: false)
let globalArchiveSortDescriptorName = NSSortDescriptor(key: "name", ascending: true)
let globalArchiveSortDescriptorModified = NSSortDescriptor(key: "modified", ascending: false)

// Extension to string for validating the complexity of a password
extension String {
    func validatePassword() -> Bool  {
        guard rangeOfCharacter(from: .uppercaseLetters) != nil
            else { return false }
        guard rangeOfCharacter(from: .lowercaseLetters) != nil
            else { return false }
        guard rangeOfCharacter(from: .decimalDigits) != nil
            else { return false }
        return true
    }
}

// @see: https://stackoverflow.com/questions/36110620/standard-way-to-clamp-a-number-between-two-values-in-swift
extension Comparable {
    func clamped(_ f: Self, _ t: Self)  ->  Self {
        var r = self
        if r < f { r = f }
        if r > t { r = t }
        // (use SIMPLE, EXPLICIT code here to make it utterly clear
        // whether we are inclusive, what form of equality, etc etc)
        return r
    }
}

// @see: https://www.fivestars.blog/articles/swiftui-share-layout-information/
struct SizePreferenceKey: PreferenceKey {
  static var defaultValue: CGSize = .zero
  static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}
extension View {
  func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
    background(
      GeometryReader { geometryProxy in
        Color.clear
          .preference(key: SizePreferenceKey.self, value: geometryProxy.size)
      }
    )
    .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
  }
}

struct ArchiveMonitorData {
    let id: UUID
    let mountURL: URL
    let bundleURL: URL
}

// MARK: - Ephemeral Storage
class LockeEphemeralStorage: NSObject, ObservableObject {
    @Published public var passwordDict: [UUID: String] = [:]
    @Published public var archiveOpen: Bool = false
    
    var archiveManager: ArchiveManager!

    public func setPassword(id: UUID, password: String) -> Void {
        passwordDict[id] = password
    }
    
    public func getPassword(id: UUID) -> String? {
        return passwordDict[id]
    }
}

func addSubview(subView:NSView, toView parentView:NSView) {
         parentView.addSubview(subView)
         var viewBindingsDict = [String: AnyObject]()
         viewBindingsDict["subView"] = subView
         parentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[subView]|", options: [], metrics: nil, views: viewBindingsDict))
         parentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[subView]|", options: [], metrics: nil, views: viewBindingsDict))
 }

// MARK: - LockeDelegate

class LockeDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let container = NSPersistentContainer(name: "Locke")
    
    public var mainWindow: NSWindow!
    public var archiveManager: ArchiveManager!
    public var passwordPromptManager: PasswordPromptManager!
    
    override init() {
        super.init()
        
        // Apply a sort to the global archive fetch request
        globalArchiveFetchRequest.sortDescriptors = [globalArchiveSortDescriptor]
        
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        self.passwordPromptManager = PasswordPromptManager()
        self.archiveManager = ArchiveManager(context: self.container.viewContext, storage: globalEphemeralStorage, lockeDelegate: self, passwordPromptManager: passwordPromptManager)
        globalEphemeralStorage.archiveManager = archiveManager
        
        // MARK: Main Window
        // Make a new NS Window
        self.mainWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // End the archive manager
        self.archiveManager.end()
    }
    
    func applicationDidFinishLaunching(_ Notification: Notification) {
        // Start the required managers
        self.archiveManager.start()
        self.passwordPromptManager.start()
        
        // MARK: - Main View
        // Set up the content view for this window
        let mainView = ContentView()
            .environment(\.managedObjectContext, self.container.viewContext)
            .environmentObject(globalEphemeralStorage)
            .environmentObject(self.archiveManager)
            .environmentObject(self)
        
        // Apply the view and controller based on the SwiftUI View
        self.mainWindow.contentViewController = NSHostingController(rootView: mainView)
        self.mainWindow.contentView = NSHostingView(rootView: mainView)
        
        // Allows the window to be reopened after being closed
        // @see: https://stackoverflow.com/questions/39385292/why-do-i-get-a-exc-bad-access-when-re-opening-an-nswindow-after-closing-it
        self.mainWindow.isReleasedWhenClosed = false
        
        // General Settings
        self.mainWindow.center()
        self.mainWindow.setFrameAutosaveName("MainView")
        self.mainWindow.titlebarAppearsTransparent = false
        self.mainWindow.title = "Locke"
        self.mainWindow.titleVisibility = .visible
        self.mainWindow.titlebarSeparatorStyle = .none
        self.mainWindow.collectionBehavior = .moveToActiveSpace
        self.mainWindow.level = NSWindow.Level.init(rawValue: 1)
    }
    
    @objc func openMainView() {
        self.activate()
        self.mainWindow.center()
        self.mainWindow.orderFrontRegardless()
    }
    
    func activate() {
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct AlertData : Identifiable {
    let id = UUID()
    var title: String
    var message: String
}

let globalEphemeralStorage = LockeEphemeralStorage()

@main
struct LockeApp: App {
    // Set up the app delegte so that we can use AppKit stuff with this SwiftUI project
    @NSApplicationDelegateAdaptor(LockeDelegate.self) var lockeDelegate: LockeDelegate
    @ObservedObject var ephemeralStorage = globalEphemeralStorage
    
    var body: some Scene {
        MenuBarExtra() {
            MenuView()
                .environment(\.managedObjectContext, lockeDelegate.container.viewContext)
                .environmentObject(lockeDelegate.archiveManager)
                .environmentObject(lockeDelegate)
        } label: {
            HStack {
                Image(systemSymbol: SFSymbol.lockRectangleStack)
                Text(ephemeralStorage.archiveOpen ? "Open" : "")
                    .transition(.opacity)
                    .id("MenuBarExtraTitle-" + (ephemeralStorage.archiveOpen ? "Open" : "Closed"))
            }
        }.menuBarExtraStyle(.menu)
    }
}
