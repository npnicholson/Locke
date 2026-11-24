//
//  PasswordPromptView.swift
//  Locke
//
//  Created by Norris Nicholson on 8/28/23.
//

import SwiftUI
import SFSafeSymbols

// Possible results from button interaction with the prompt.
enum PromptResult {
    case submitted
    case cancelled
}

// Password Prompt Manager class which is responsible for creating and managing
// the password prompt
class PasswordPromptManager: ObservableObject {
    // The archive and prompt, to display to the user when prompted. Published so
    // That the prompt can update as this value changes between views. Note that though
    // the prompt is not visible when not in use, it still exists and therefore isnt
    // "redrawn" each time
    @Published public var archive: ArchiveData!
    @Published public var title: String = ""
    @Published public var subtitle: String = ""
    @Published public var prompt: String = ""
    @Published public var incorrectSleepTime: UInt32 = 1
    
    public var data: Any?
    
    // The handler, which should be set by the object which activated the handler. It returns true when
    // the prompt should close, or false to keep it open (e.g. after a wrong password)
    public typealias Handler = @MainActor (PromptResult, ArchiveData, String, Any?) async -> Bool
    public var handler: Handler? = nil
    
    // Private vars for the window and storage objects
    private let window: NSWindow
    private var hostingView: NSView?
    
    init() {
        // Create the basic window but do nothing else. The rest of the setup is done in the start() function,
        // which is to be called after the application has finished starting
        self.window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 175),
            styleMask: [.fullSizeContentView, .titled],
            backing: .buffered,
            defer: false)
    }
    
    // To be called after the application has finished starting
    func start() {
        // Set up the content view for this window, and pass a reference to this object through the environment
        let promptView = PasswordPromptView().environmentObject(self)
        
        // Set up the window
        
        // Allows the window to be reopened after being closed
        // @see: https://stackoverflow.com/questions/39385292/why-do-i-get-a-exc-bad-access-when-re-opening-an-nswindow-after-closing-it
        self.window.isReleasedWhenClosed = false
        
        // Movable by the background because there is no title bar
        self.window.isMovableByWindowBackground = true
        
        // Hide the close, zoom, and miniaturize buttons
        self.window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.window.standardWindowButton(.closeButton)?.isHidden = true
        self.window.standardWindowButton(.zoomButton)?.isHidden = true
        
        // Hide the title bar
        self.window.titlebarAppearsTransparent = true
        self.window.titleVisibility = .hidden
        
        // Change the collection behavior so that the prompt is always moved to your window when
        // activated (instead of moving the user to the window it is on)
        self.window.collectionBehavior = .moveToActiveSpace
        
        // Center the window on the screen
        self.window.center()
        
        // Save the window's state using the name PromptView. This will preserve its location and status
        // as far as MacOS is consurned
        self.window.setFrameAutosaveName("PromptView")
        
        // Let the Liquid Glass background show through: the window itself draws nothing
        self.window.isOpaque = false
        self.window.backgroundColor = .clear

        // Host the SwiftUI prompt inside a Liquid Glass view that fills the window
        let glass = NSGlassEffectView()
        glass.cornerRadius = 20
        let hostingView = NSHostingView(rootView: promptView)
        self.hostingView = hostingView
        glass.contentView = hostingView
        self.window.contentView = glass
    }
    
    // Function which is called when the prompt has finished (cancel or submit). This runs the
    // handler if it is set and returns the result back to the prompt so that it can display
    // errors if needed
    @MainActor
    func execute(_ result: PromptResult, password: String = "") async -> Bool {
        // If the handler has been set, then excecute it
        if let handler = self.handler, let archive = self.archive {
            return await handler(result, archive, password, self.data)
        }
        
        // If there was no handler, then I guess we can call this a success? Otherwise the
        // window will never go away. This should never happen
        return true
    }
    
    // Activate the prompt by showing it to the user
    func activate(_ handler: @escaping Handler, archive: ArchiveData, title: String? = nil, subtitle: String? = nil, prompt: String? = nil, sleepTimeIfWrong: UInt32? = nil, data: Any? = nil) {
        
        // Store the handler and archive name from the activating caller
        self.handler = handler
        self.archive = archive
        
        self.title = title ?? "Locke: Enter your password."
        self.subtitle = subtitle ?? "Please enter the password for '\(self.archive?.name ?? "Unknown")'."
        self.prompt = prompt ?? ""
        self.incorrectSleepTime = sleepTimeIfWrong ?? 1
        self.data = data
        
        // Show and center the window
        self.window.level = NSWindow.Level.init(rawValue: 1)
        self.window.makeKeyAndOrderFront(nil)
        self.window.center()

        // The title/subtitle/prompt text varies, so fit the window to the content once SwiftUI has
        // picked up the new values (published changes land on the next run loop pass)
        DispatchQueue.main.async {
            self.fitWindowToContent()
        }
    }

    // Resize the window so it hugs the SwiftUI content, keeping the window centered
    private func fitWindowToContent() {
        guard let hostingView = self.hostingView else { return }
        hostingView.layoutSubtreeIfNeeded()
        let size = hostingView.fittingSize
        guard size.width > 0, size.height > 0 else { return }
        self.window.setContentSize(size)
        self.window.center()
    }
    
    // Close the prompt window
    func deactivate() {
        self.window.close()
    }
}

struct PasswordPromptView: View {
    @EnvironmentObject var manager: PasswordPromptManager
    @State var shake = false
    @State var opening: Bool = false
    @State var password: String = ""
    
    // Function called when this prompt is submitted. The handler runs asynchronously so the prompt
    // stays responsive (and shows a spinner) while the archive is opened
    func submit () {
        guard !opening else { return }
        opening = true
        
        Task { @MainActor in
            // Run the handler for this button action
            let success = await manager.execute(.submitted, password: password)
            
            // If this was a success, then close the window. Otherwise wait briefly (to slow down
            // guessing), shake the display and wait for a new submission
            if (success) {
                password = ""
                opening = false
                manager.deactivate()
            } else {
                try? await Task.sleep(for: .seconds(Double(manager.incorrectSleepTime)))
                opening = false
                shake = true
            }
        }
    }
    
    func cancel() {
        Task { @MainActor in
            // Run the handler for this button action
            _ = await manager.execute(.cancelled)
            // Reset the password
            password = ""
            // Close the window
            manager.deactivate()
        }
    }
    
    var body: some View {
        HStack (alignment: .top) {
            VStack {
                Image(systemSymbol: SFSymbol.lockRectangleStack)
                    .foregroundStyle(.secondary)
                    .font(.system(size: 50))
                    .frame(width: 70, height: 70)
                Spacer()
                if (opening) {
                    ProgressView()
                }
            }
            Spacer()
            VStack (alignment: .leading, spacing: 15) {
                Text (manager.title)
                    .font(.system(.title3, design: .rounded))
                    .bold()
                    .foregroundColor(.primary)
                VStack (alignment: .leading, spacing: 0) {
                    Text (manager.subtitle)
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.primary)
                    Text (manager.prompt)
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.primary)
                }
                HStack {
                    Text("Password:")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.primary)
                    SecureField("", text: $password)
                        .font(.system(size: 15, weight: .regular, design: .monospaced))
                        .frame(height: 30)
                        .onSubmit() {
                            self.submit()
                        }
                }
                
                HStack {
                    Spacer()
                    Button {
                        self.cancel()
                    } label: {
                        Text("Cancel")
                            .font(.system(.body, design: .rounded))
                            .frame(width: 80)
                    }
                    .buttonStyle(.glass)
                    .keyboardShortcut(.cancelAction)

                    Button {
                        self.submit()
                    } label: {
                        Text("Submit")
                            .font(.system(.body, design: .rounded))
                            .frame(width: 80)
                    }
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(opening)
                }
                .controlSize(.large)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: 400)
        .padding(.horizontal)
        .padding(.bottom)
        .shake($shake, repeatCount: 2, duration: 0.3, offsetRange: 8)
    }
    
}
