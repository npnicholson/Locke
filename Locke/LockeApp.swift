//
//  LockeApp.swift
//  Locke
//
//  Created by Norris Nicholson on 8/14/23.
//

import SwiftUI
import AppKit
import SFSafeSymbols
import CryptoKit
import UserNotifications

let fm = FileManager.default
let globalNotificationCenter = UNUserNotificationCenter.current()

// Directories
let appSupportURL = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
let directoryURL = appSupportURL.appendingPathComponent("Locke")

let archivesDirectory = directoryURL.appending(path: "Archives")
let mountDirectory = directoryURL.appending(path: "Mount")
let orphansDirectory = directoryURL.appending(path: "Orphans")
let tempDirectory = directoryURL.appending(path: "Temp")

// Build a fetch request which can be used to access archives in order
let globalArchiveFetchRequest = NSFetchRequest<ArchiveData>(entityName: "ArchiveData")
let globalArchiveSortDescriptor = NSSortDescriptor(key: "created", ascending: false)
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

// @see: https://stackoverflow.com/questions/65736518/how-do-i-create-a-slider-in-swiftui-for-an-int-type-property
public extension Binding {
    static func convert<TInt, TFloat>(from intBinding: Binding<TInt>) -> Binding<TFloat>
    where TInt:   BinaryInteger,
          TFloat: BinaryFloatingPoint{
        Binding<TFloat> (
            get: { TFloat(intBinding.wrappedValue) },
            set: { intBinding.wrappedValue = TInt($0) }
        )
    }
    static func convert<TFloat, TInt>(from floatBinding: Binding<TFloat>) -> Binding<TInt>
    where TFloat: BinaryFloatingPoint,
          TInt:   BinaryInteger {
        Binding<TInt> (
            get: { TInt(floatBinding.wrappedValue) },
            set: { floatBinding.wrappedValue = TFloat($0) }
        )
    }
}

// @see: https://stackoverflow.com/questions/25965239/how-do-i-get-the-app-version-and-build-number-using-swift
public extension Bundle {
    var appName: String           { getInfo("CFBundleName") }
    var displayName: String       { getInfo("CFBundleDisplayName") }
    var language: String          { getInfo("CFBundleDevelopmentRegion") }
    var identifier: String        { getInfo("CFBundleIdentifier") }
    var copyright: String         { getInfo("NSHumanReadableCopyright").replacingOccurrences(of: "\\\\n", with: "\n") }

    var appBuild: String          { getInfo("CFBundleVersion") }
    var appVersionLong: String    { getInfo("CFBundleShortVersionString") }
    //public var appVersionShort: String { getInfo("CFBundleShortVersion") }
    
    var buildDate: Date {
        if let infoPath = Bundle.main.path(forResource: "Info", ofType: "plist"),
            let infoAttr = try? FileManager.default.attributesOfItem(atPath: infoPath),
            let infoDate = infoAttr[.modificationDate] as? Date {
            return infoDate
        }
        return Date()
    }

    fileprivate func getInfo(_ str: String) -> String { infoDictionary?[str] as? String ?? "⚠️" }
}



// MARK: - Ephemeral Storage
class LockeEphemeralStorage: NSObject, ObservableObject {
    @Published public var archiveOpen: Bool = false
}

// Define the global logger
let logger = Logger()

// MARK: - LockeDelegate

class LockeDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let container = NSPersistentContainer(name: "Locke")
    
    public var mainWindow: NSWindow!
    public var archiveManager: ArchiveManager!
    public var passwordPromptManager: PasswordPromptManager!
    public var notificationDelegate: NotificationDelegate!
    public var AWSManager: AWSManager!
    public var BackblazeManager: BackblazeManager!
    public var ResticManager: ResticManager!
    public var UpdateManager: UpdateManager = Locke.UpdateManager()
    
    override init() {
        super.init()
        
        // Apply a sort to the global archive fetch request
        globalArchiveFetchRequest.sortDescriptors = [globalArchiveSortDescriptor]
        
        container.loadPersistentStores { description, error in
            if let error = error {
                logger.error("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        self.passwordPromptManager = PasswordPromptManager()
        self.archiveManager = ArchiveManager(
            context: self.container.viewContext,
            storage: globalEphemeralStorage,
            lockeDelegate: self,
            passwordPromptManager: passwordPromptManager)
        
        self.AWSManager = Locke.AWSManager(self);
        self.BackblazeManager = Locke.BackblazeManager(self)
        self.ResticManager = Locke.ResticManager()

        // Attempt to authenticate the cloud managers with stored credentials
        let _ = self.AWSManager.authenticate()
        let _ = self.BackblazeManager.authenticate()
        
        
        // MARK: Main Window
        // Make a new NS Window
        self.mainWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        
        // Init a new notification delegate to handle application notifications
        self.notificationDelegate = NotificationDelegate(lockeDelegate: self, archiveManager: self.archiveManager)
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
        
        // Host the SwiftUI view in a controller and let SwiftUI drive the window's toolbar and title.
        // Only the minimum size is taken from SwiftUI so the autosaved frame is not overridden.
        let hostingController = NSHostingController(rootView: mainView)
        hostingController.sizingOptions = [.minSize]
        hostingController.sceneBridgingOptions = [.toolbars]
        self.mainWindow.contentViewController = hostingController

        // A unified toolbar is what gives the window the macOS 26 Liquid Glass chrome
        // (larger corner radius and the floating glass sidebar). Without one, the window keeps the older flat look.
        self.mainWindow.toolbar = NSToolbar(identifier: "MainToolbar")
        self.mainWindow.toolbarStyle = .unified
        
        // Allows the window to be reopened after being closed
        // @see: https://stackoverflow.com/questions/39385292/why-do-i-get-a-exc-bad-access-when-re-opening-an-nswindow-after-closing-it
        self.mainWindow.isReleasedWhenClosed = false
        
        // General Settings
        self.mainWindow.center()
        self.mainWindow.setFrameAutosaveName("MainView")
        self.mainWindow.title = "Locke"
        self.mainWindow.titleVisibility = .visible
        self.mainWindow.collectionBehavior = .moveToActiveSpace
        self.mainWindow.level = NSWindow.Level.init(rawValue: 1)
        
        self.notificationDelegate.start()
        
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
        }
        .menuBarExtraStyle(.menu)
    }
}
