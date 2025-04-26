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
            button.image = NSImage(systemSymbolName: "speaker.fill", accessibilityDescription: "Volume Icon Toggle")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle Volume Icon", action: #selector(toggleVolumeIcon), keyEquivalent: "t"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    private func checkCurrentState() {
        // Check if the volume icon is currently visible
        let task = Process()
        task.launchPath = "/usr/bin/defaults"
        task.arguments = ["read", "com.apple.systemuiserver", "menuExtras"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                isVolumeIconVisible = output.contains("/System/Library/CoreServices/Menu Extras/Volume.menu")
                updateMenuItemTitle()
            }
        } catch {
            print("Error checking volume icon state: \(error)")
        }
    }
    
    @objc private func toggleVolumeIcon() {
        let task = Process()
        task.launchPath = "/usr/bin/defaults"
        
        if isVolumeIconVisible {
            // Remove volume icon
            task.arguments = ["delete", "com.apple.systemuiserver", "menuExtras"]
        } else {
            // Add volume icon
            task.arguments = ["write", "com.apple.systemuiserver", "menuExtras", "-array-add", "/System/Library/CoreServices/Menu Extras/Volume.menu"]
        }
        
        do {
            try task.run()
            task.waitUntilExit()
            
            // Restart SystemUIServer to apply changes
            let restartTask = Process()
            restartTask.launchPath = "/usr/bin/killall"
            restartTask.arguments = ["SystemUIServer"]
            try restartTask.run()
            
            isVolumeIconVisible.toggle()
            updateMenuItemTitle()
        } catch {
            print("Error toggling volume icon: \(error)")
        }
    }
    
    private func updateMenuItemTitle() {
        if let menuItem = statusItem.menu?.item(at: 0) {
            menuItem.title = isVolumeIconVisible ? "Hide Volume Icon" : "Show Volume Icon"
        }
    }
}

// Create and start the application
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run() 