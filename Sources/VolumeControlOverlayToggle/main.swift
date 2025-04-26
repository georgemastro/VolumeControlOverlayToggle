import Cocoa
import HotKey

// Single-instance check: exit if another instance is running
if NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!).count > 1 {
    NSApp.terminate(nil)
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var isVolumeIconVisible = true
    private var menu: NSMenu!
    private var hotKey: HotKey?
    private var rightClickMonitor: Any?
    private var startAtLoginMenuItem: NSMenuItem!
    private let launchAgentId = "com.georgemastro.VolumeControlOverlayToggle"
    private var launchAgentPath: String {
        return (NSHomeDirectory() as NSString).appendingPathComponent("Library/LaunchAgents/\(launchAgentId).plist")
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupHotKey()
        setupRightClickMonitor()
        checkCurrentState()
        updateStartAtLoginMenuItem()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "speaker.wave.2", accessibilityDescription: "Volume Icon")
            button.target = self
            button.action = #selector(statusItemClicked(_:))
        }
        
        menu = NSMenu()
        let toggleMenuItem = NSMenuItem(title: "Toggle Volume Control Overlay", action: #selector(toggleVolumeIcon), keyEquivalent: "O")
        toggleMenuItem.keyEquivalentModifierMask = [.command, .option, .shift]
        menu.addItem(toggleMenuItem)
        
        // Start at Login menu item
        startAtLoginMenuItem = NSMenuItem(title: "Start at Login", action: #selector(toggleStartAtLogin), keyEquivalent: "")
        startAtLoginMenuItem.target = self
        menu.addItem(startAtLoginMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }
    
    private func setupHotKey() {
        hotKey = HotKey(key: .o, modifiers: [.command, .option, .shift])
        hotKey?.keyDownHandler = { [weak self] in
            self?.toggleVolumeIcon()
        }
    }
    
    private func setupRightClickMonitor() {
        rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseUp]) { [weak self] event in
            guard let self = self, let button = self.statusItem.button else { return event }
            let buttonFrame = button.window?.convertToScreen(button.frame) ?? .zero
            let mouseLocation = NSEvent.mouseLocation
            if buttonFrame.contains(mouseLocation) {
                self.statusItem.popUpMenu(self.menu)
                return nil // event handled
            }
            return event
        }
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
    
    @objc private func statusItemClicked(_ sender: Any?) {
        // Only handle left click
        toggleVolumeIcon()
    }
    
    @objc private func toggleStartAtLogin() {
        let isEnabled = isLaunchAgentEnabled()
        if isEnabled {
            unloadAndRemoveLaunchAgent()
        } else {
            createAndLoadLaunchAgent()
        }
        // Add a short delay before updating the checkmark
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.updateStartAtLoginMenuItem()
        }
    }
    
    private func updateStartAtLoginMenuItem() {
        let isEnabled = isLaunchAgentEnabled()
        startAtLoginMenuItem.state = isEnabled ? .on : .off
    }
    
    private func isLaunchAgentEnabled() -> Bool {
        // Check if the LaunchAgent plist exists
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: launchAgentPath)
    }
    
    private func createAndLoadLaunchAgent() {
        guard let executablePath = getExecutablePath() else { return }
        let plist: [String: Any] = [
            "Label": launchAgentId,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true
        ]
        let plistData = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        do {
            try plistData?.write(to: URL(fileURLWithPath: launchAgentPath))
            // Load the agent
            let task = Process()
            task.launchPath = "/bin/launchctl"
            task.arguments = ["load", launchAgentPath]
            try? task.run()
        } catch {
            print("Error creating/loading LaunchAgent: \(error)")
        }
    }
    
    private func unloadAndRemoveLaunchAgent() {
        // Unload the agent
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = ["unload", launchAgentPath]
        try? task.run()
        // Remove the plist
        try? FileManager.default.removeItem(atPath: launchAgentPath)
    }
    
    private func getExecutablePath() -> String? {
        // For Homebrew, this will be /usr/local/bin/VolumeControlOverlayToggle or /opt/homebrew/bin/VolumeControlOverlayToggle
        return Bundle.main.executablePath
    }
    
    private func updateMenuItemTitle() {
        if let menuItem = menu?.item(at: 0) {
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