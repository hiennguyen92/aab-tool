import SwiftUI
import AppKit

@main
struct AABToolApp: App {
    init() {
        // Force the app to be a regular app (Dock icon, UI) even if run as a CLI executable
        NSApplication.shared.setActivationPolicy(.regular)
        
        // Single Instance Check
        // If we have a bundle identifier, check if another app is already running with it
        if let bundleID = Bundle.main.bundleIdentifier {
            let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            let otherApps = runningApps.filter { $0 != NSRunningApplication.current }
            
            if !otherApps.isEmpty {
                // Another instance found. Activate it and terminate self.
                otherApps.first?.activate(options: [.activateIgnoringOtherApps])
                NSApplication.shared.terminate(nil)
            }
        }
        
        // Manual Icon Loading for Swift Package Executables
        // When running as a raw executable, Info.plist icon keys are often ignored by the Dock.
        // We must load the image from the Asset Catalog and set it manually.
        if let image = NSImage(named: "AppIcon") {
            NSApplication.shared.applicationIconImage = image
        } else {
            // Fallback: try loading from module bundle if main bundle scan fails
            // Accessing assets in a Swift Package usually works via Bundle.module
            // However, NSImage(named:) in a package looks in main bundle usually.
            // Using image resource accessor if available (Swift 5.9+ has generated accessors but strict usage varies)
            // Let's try explicit bundle load:
            if let image = Bundle.module.image(forResource: "AppIcon") {
                 NSApplication.shared.applicationIconImage = image
            } else {
                // Fallback 2: Try finding the raw png file if it exists (backup for CLI mode)
                if let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
                   let image = NSImage(contentsOf: iconURL) {
                    NSApplication.shared.applicationIconImage = image
                }
            }
        }
        
        // Bring to front
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    var body: some Scene {
        // 'Window' creates a single, unique window for the app. 
        // This prevents creating multiple windows via File > New or Cmd+N.
        Window("AAB to APK Converter", id: "main") {
            ContentView()
                // Fixed frame to prevent resizing, with increased height
                .frame(width: 800, height: 550)
        }
        .windowResizability(.contentSize) // Respects the fixed frame
        .commands {
            // Remove "New Window" command to avoid confusion
            CommandGroup(replacing: .newItem) { }
        }
    }
}
