import Cocoa
import HotKey
import AVFoundation

import ApplicationServices
import CoreAudio

// Single-instance check: Enforce single instance
let bundleId = Bundle.main.bundleIdentifier ?? "com.georgemastro.VolumeControlOverlayToggle"
if NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).count > 1 {
    exit(0)
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var isVolumeIconVisible = true
    private var menu: NSMenu!
    private var hotKey: HotKey?
    private var rightClickMonitor: Any?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var startAtLoginMenuItem: NSMenuItem!
    private let launchAgentId = "com.georgemastro.VolumeControlOverlayToggle"
    private var launchAgentPath: String {
        return (NSHomeDirectory() as NSString).appendingPathComponent("Library/LaunchAgents/\(launchAgentId).plist")
    }
    
    // --- Add these properties for polling ---
    private var volumePollTimer: Timer?
    private var lastVolume: Int = -1
    // ----------------------------------------
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupHotKey()
        setupRightClickMonitor()
        setupEventTap()
        updateMenuItemTitle()
        updateIcon()
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
    
    private func setupEventTap() {
        let eventMask = (1 << 14) // kCGEventSystemDefined = 14
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                if let refcon = refcon {
                    let delegate = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
                    return delegate.handleEvent(proxy: proxy, type: type, event: event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            print("Failed to create event tap")
            return
        }
        
        self.eventTap = eventTap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout {
            CGEvent.tapEnable(tap: eventTap!, enable: true)
            return Unmanaged.passUnretained(event)
        }
        
        if type.rawValue == 14 { // kCGEventSystemDefined
            if let event = NSEvent(cgEvent: event) {
                if event.subtype.rawValue == 8 { // NX_SUBTYPE_AUX_CONTROL_BUTTONS
                    let keyCode = (event.data1 & 0xFFFF0000) >> 16
                    let keyFlags = (event.data1 & 0x0000FFFF)
                    let keyDown = ((keyFlags & 0xFF00) >> 8) == 0xA
                    
                    // 0 = Sound Up, 1 = Sound Down, 7 = Mute
                    if keyDown && (keyCode == 0 || keyCode == 1 || keyCode == 7) {
                        if !isVolumeIconVisible {
                            // Overlay is HIDDEN: Suppress event and manually change volume
                            handleVolumeChange(keyCode: Int(keyCode))
                            return nil
                        }
                    }
                }
            }
        }
        return Unmanaged.passUnretained(event)
    }
    
    private func handleVolumeChange(keyCode: Int) {
        var currentVol = getSystemVolume()
        let step: Float = 1.0/16.0 // Standard macOS volume step
        
        switch keyCode {
        case 0: // Up
            currentVol = min(currentVol + step, 1.0)
            setSystemVolume(currentVol)
        case 1: // Down
            currentVol = max(currentVol - step, 0.0)
            setSystemVolume(currentVol)
        case 7: // Mute
            toggleMute()
        default:
            break
        }
        
        // Update icon if needed (polling replacement)
        updateIcon()
    }

    // MARK: - Core Audio Helpers
    
    private func getSystemVolume() -> Float {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout.size(ofValue: defaultOutputDeviceID))
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize, &defaultOutputDeviceID)
        
        var volume = Float32(0.0)
        propertySize = UInt32(MemoryLayout.size(ofValue: volume))
        propertyAddress.mSelector = kAudioHardwareServiceDeviceProperty_VirtualMainVolume
        propertyAddress.mScope = kAudioDevicePropertyScopeOutput
        
        AudioObjectGetPropertyData(defaultOutputDeviceID, &propertyAddress, 0, nil, &propertySize, &volume)
        return volume
    }
    
    private func setSystemVolume(_ volume: Float) {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout.size(ofValue: defaultOutputDeviceID))
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize, &defaultOutputDeviceID)
        
        var volumeToSet = Float32(volume)
        propertySize = UInt32(MemoryLayout.size(ofValue: volumeToSet))
        propertyAddress.mSelector = kAudioHardwareServiceDeviceProperty_VirtualMainVolume
        propertyAddress.mScope = kAudioDevicePropertyScopeOutput
        
        AudioObjectSetPropertyData(defaultOutputDeviceID, &propertyAddress, 0, nil, propertySize, &volumeToSet)
    }
    
    private func toggleMute() {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout.size(ofValue: defaultOutputDeviceID))
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize, &defaultOutputDeviceID)
        
        var isMuted: UInt32 = 0
        propertySize = UInt32(MemoryLayout.size(ofValue: isMuted))
        propertyAddress.mSelector = kAudioDevicePropertyMute
        propertyAddress.mScope = kAudioDevicePropertyScopeOutput
        
        AudioObjectGetPropertyData(defaultOutputDeviceID, &propertyAddress, 0, nil, &propertySize, &isMuted)
        
        isMuted = (isMuted == 1) ? 0 : 1
        AudioObjectSetPropertyData(defaultOutputDeviceID, &propertyAddress, 0, nil, propertySize, &isMuted)
    }

    @objc private func toggleVolumeIcon() {
        isVolumeIconVisible.toggle()
        updateMenuItemTitle()
        updateIcon()
        NSSound.beep()
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
            button.title = ""
            button.attributedTitle = NSAttributedString(string: "")
        }
    }
    

}

// Create and start the application
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run() 