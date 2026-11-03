import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let stateItem = NSMenuItem(title: "Checking sleep state…", action: nil, keyEquivalent: "")
    private let toggleItem = NSMenuItem(title: "", action: #selector(toggleSleep), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
    private var sleepless: Bool?
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        stateItem.isEnabled = false
        menu.addItem(stateItem)
        toggleItem.target = self
        menu.addItem(toggleItem)
        let hint = NSMenuItem(title: "Keep the Mac ventilated when closed.", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        menu.addItem(.separator())
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Sleepless", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)
        statusItem.menu = menu
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        refresh()
    }

    private func readSleepState() throws -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g"]
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "Unknown pmset error"
            throw SleepError(message: message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard let result = String(data: data, encoding: .utf8) else {
            throw SleepError(message: "Could not read the system sleep setting.")
        }
        for line in result.components(separatedBy: .newlines) {
            let parts = line.split(whereSeparator: { $0.isWhitespace })
            if parts.count == 2 && parts[0] == "SleepDisabled" {
                if parts[1] == "1" { return true }
                if parts[1] == "0" { return false }
            }
        }
        throw SleepError(message: "The system sleep setting was not present in pmset output.")
    }

    private func refresh() {
        do {
            sleepless = try readSleepState()
        } catch {
            sleepless = nil
            NSLog("Could not read sleep state: %@", error.localizedDescription)
        }
        let symbol: String
        let description: String
        switch sleepless {
        case true:
            stateItem.title = "Sleepless is On"
            toggleItem.title = "Turn Sleepless Off"
            symbol = "eye.fill"
            description = "Sleepless is on"
        case false:
            stateItem.title = "Sleepless is Off"
            toggleItem.title = "Turn Sleepless On"
            symbol = "eye.slash"
            description = "Sleepless is off"
        case nil:
            stateItem.title = "Sleep state unavailable"
            toggleItem.title = "Unable to change sleep state"
            symbol = "exclamationmark.triangle"
            description = "Sleep state unavailable"
        }
        toggleItem.isEnabled = sleepless != nil
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)
        statusItem.button?.toolTip = description
        let service = SMAppService.mainApp
        loginItem.state = service.status == .enabled ? .on : .off
        loginItem.title = service.status == .requiresApproval ? "Allow in Login Items…" : "Open at Login"
        loginItem.isEnabled = service.status != .notFound
    }

    @objc private func toggleSleep() {
        do {
            let current = try readSleepState()
            if current != sleepless { refresh() }
        } catch {
            refresh()
            showError(error.localizedDescription)
            return
        }
        guard let previous = sleepless else { return }
        let desired = !previous
        let command = "do shell script \"/usr/bin/pmset -a disablesleep \(desired ? 1 : 0)\" with administrator privileges"
        toggleItem.isEnabled = false
        Task {
            let failure = await Task.detached { () -> (number: Int?, message: String)? in
                guard let script = NSAppleScript(source: command) else {
                    return (nil, "Could not prepare the system sleep command.")
                }
                var error: NSDictionary?
                script.executeAndReturnError(&error)
                guard let error else { return nil }
                return (error[NSAppleScript.errorNumber] as? Int,
                        error[NSAppleScript.errorMessage] as? String ?? "Could not change the system sleep setting.")
            }.value
            refresh()
            if let failure {
                if failure.number != -128 { showError(failure.message) }
            } else if sleepless != desired {
                showError("The system did not confirm the requested sleep setting.")
            }
        }
    }

    @objc private func toggleLogin() {
        do {
            let service = SMAppService.mainApp
            switch service.status {
            case .enabled: try service.unregister()
            case .requiresApproval: SMAppService.openSystemSettingsLoginItems()
            default: try service.register()
            }
            refresh()
        } catch {
            refresh()
            showError(error.localizedDescription)
        }
    }

    private func showError(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Sleepless could not change the setting"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}

private struct SleepError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
