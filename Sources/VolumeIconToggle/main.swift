import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var isVolumeIconVisible = true
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        checkCurrentState()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "speaker.wave.2", accessibilityDescription: "Volume Icon")
        }
        
        let menu = NSMenu()
        let toggleMenuItem = NSMenuItem(title: "Toggle Volume Control Overlay", action: #selector(toggleVolumeIcon), keyEquivalent: "T")
        toggleMenuItem.keyEquivalentModifierMask = [.command, .option, .shift]
        menu.addItem(toggleMenuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    private func checkCurrentState() {
        // Check if the volume icon is currently visible by checking if OSDUIHelper is loaded
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = ["list"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                isVolumeIconVisible = output.contains("com.apple.OSDUIHelper")
                updateMenuItemTitle()
                updateIcon()
            }
        } catch {
            print("Error checking volume icon state: \(error)")
        }
    }
    
    @objc private func toggleVolumeIcon() {
        let task = Process()
        task.launchPath = "/bin/launchctl"
        if isVolumeIconVisible {
            // Remove volume icon
            task.arguments = ["unload", "-F", "/System/Library/LaunchAgents/com.apple.OSDUIHelper.plist"]
        } else {
            // Show volume icon
            task.arguments = ["load", "-F", "/System/Library/LaunchAgents/com.apple.OSDUIHelper.plist"]
        }
        do {
            try task.run()
            task.waitUntilExit()
            isVolumeIconVisible.toggle()
            updateMenuItemTitle()
            updateIcon()
        } catch {
            print("Error toggling volume icon: \(error)")
        }
    }
    
    private func updateMenuItemTitle() {
        if let menuItem = statusItem.menu?.item(at: 0) {
            menuItem.title = isVolumeIconVisible ? "Hide Volume Control Overlay" : "Show Volume Control Overlay"
        }
    }
    
    private func updateIcon() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: isVolumeIconVisible ? "speaker.wave.2.fill" : "speaker.wave.2",
                                 accessibilityDescription: "Volume Icon")
        }
    }
}

// Create and start the application
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run() 