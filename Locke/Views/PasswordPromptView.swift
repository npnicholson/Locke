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
    case cancled
}

// Password Prompt Manager class which is responsible for creating and managing
// the password prompt
class PasswordPromptManager: ObservableObject {
    // The archive and prompt, to display to the user when prompted. Published so
    // That the prompt can update as this value changes between views. Note that though
    // the prompt is not visible when not in use, it still exists and therefore isnt
    // "redrawn" each time
    @Published public var archive: ArchiveData!
    @Published public var prompt: String!
    
    // The handler, which should be set by the object which activated the handler
    public var handler: ((PromptResult, ArchiveData, String) -> Bool)? = nil
    
    // Private vars for the window and storage objects
    private let window: NSWindow
    
    init() {
        // Create the basic window but do nothing else. The rest of the setup is done in the start() function,
        // which is to be called after the application has finished starting
        self.window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 0, height: 0),
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
        
        // Prep the blury background visual effect
        let visualEffect = NSVisualEffectView()
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .fullScreenUI
        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        
        // Apply the two views to the content view. This is a hacky way of doing this but the
        // best I could do after hours of work
        let pv = NSHostingView(rootView: promptView)
        self.window.contentView = pv
        addSubview(subView: pv, toView: visualEffect)
        self.window.contentView = visualEffect
    }
    
    // Function which is called when the prompt has finished (cancel or submit). This runs the
    // handler if it is set and returns the result back to the prompt so that it can display
    // errors if needed
    func execute(_ result: PromptResult, password: String = "") -> Bool {
        // If the handler has been set, then excecute it
        if let handler = self.handler {
            return handler(result, archive, password)
        }
        
        // If there was no handler, then I guess we can call this a success? Otherwise the
        // window will never go away. This should never happen
        return true
    }
    
    // Activate the prompt by showing it to the user
    func activate(_ handler: @escaping (PromptResult, ArchiveData, String) -> Bool, archive: ArchiveData, prompt: String) {
        // Store the handler and archive name from the activating caller
        self.handler = handler
        self.archive = archive
        self.prompt = prompt
        
        // Show and center the window
        self.window.level = NSWindow.Level.init(rawValue: 2)
        self.window.makeKeyAndOrderFront(nil)
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
    
    // Function called when this prompt is submitted
    func submit () {
        // Start the opening progress wheel
        opening = true
        
        // Run the handler for this button action
        let success = manager.execute(.submitted, password: password)
        
        // Stop the opening progress wheel
        opening = false
        
        // If this was a success, then close the window. Otherwise shake the display and wait
        // for a new submission
        if (success) {
            // Reset the password
            password = ""
            // Close the window
            manager.deactivate()
        } else {
            sleep(1)
            shake = true
        }
    }
    
    func cancel() {
        // Run the handler for this button action
        let _ = manager.execute(.cancled)
        // Reset the password
        password = ""
        // Close the window
        manager.deactivate()
    }
    
    var body: some View {
        HStack (alignment: .top) {
            VStack {
                Image(systemSymbol: SFSymbol.lockRectangleStack)
                    .foregroundColor(.black)
                    .opacity(0.4)
                    .font(.system(size: 50))
                    .frame(width: 70, height: 70)
                Spacer()
                if (opening) {
                    ProgressView()
                }
            }
            Spacer()
            VStack (alignment: .leading, spacing: 15) {
                Text ("Locke: Enter your password.")
                    .font(.system(.title3, design: .rounded))
                    .bold()
                    .foregroundColor(.primary)
                VStack (alignment: .leading, spacing: 0) {
                    Text ("Please enter the password for '\(manager.archive?.name ?? "Unknown")'.")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.primary)
                    Text (manager.prompt ?? "Unknown")
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
                            .frame(width: 80, height: 20)
                            .background(Color(.init(red: 93/255, green: 98/255, blue: 103/255, alpha: 0.5)))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                    
                    Button {
                        self.submit()
                    } label: {
                        Text("Submit")
                            .font(.system(.body, design: .rounded))
                            .frame(width: 80, height: 20)
                            .background(Color(.init(red: 93/255, green: 98/255, blue: 103/255, alpha: 0.5)))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                }
                Spacer()
            }
        }
        .frame(width: 400)
        .padding(.horizontal)
        .padding(.bottom)
        .shake($shake, repeatCount: 2, duration: 0.3, offsetRange: 8)
    }
    
}
