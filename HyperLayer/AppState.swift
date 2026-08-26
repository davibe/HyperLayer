import AppKit
import Combine
import Foundation
import OSLog
import ServiceManagement

enum RecordingTarget: Equatable {
    case trigger(UUID)
    case output(UUID)
}

final class AppState: ObservableObject {
    @Published var config: HyperLayerConfig {
        didSet {
            store.save(config)
            engine.update(config: config)
            reconcileRuntime(refreshPermissions: false)
        }
    }

    @Published private(set) var runtimeStatus = "Starting"
    @Published private(set) var opensAtLogin = false
    @Published private(set) var openAtLoginStatus = ""
    @Published private(set) var openAtLoginError: String?
    @Published var recordingTarget: RecordingTarget?

    let permissions = PermissionManager()
    let engine = KeyboardEngine()
    let remapper = CapsLockRemapper()

    private let store = ConfigStore()
    private let menuBarController = MenuBarController()
    private let recordingEventTap = RecordingEventTap()
    private let logger = Logger(subsystem: "com.dade.HyperLayer", category: "runtime")
    private var localMonitor: Any?
    private weak var mainWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    private var workspaceObservers = [NSObjectProtocol]()
    private var recoveryWorkItems = [DispatchWorkItem]()

    init() {
        config = store.load()
        engine.update(config: config)
        configureMenuBarController()

        permissions.$accessibilityGranted
            .merge(with: permissions.$inputMonitoringGranted)
            .sink { [weak self] _ in
                self?.updateRuntimeStatus()
            }
            .store(in: &cancellables)

        engine.$isRunning
            .sink { [weak self] _ in
                self?.updateRuntimeStatus()
            }
            .store(in: &cancellables)

        remapper.$isInstalled
            .sink { [weak self] _ in
                self?.updateRuntimeStatus()
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
        observeWorkspaceWakeEvents()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displayConfigurationDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        refreshOpenAtLoginStatus()
        applyPresentationOptions()
        permissions.startPolling(every: 10.0) { [weak self] in
            self?.reconcileRuntime(refreshPermissions: false)
        }
        reconcileRuntime()
    }

    deinit {
        recordingEventTap.stop()
        recoveryWorkItems.forEach { $0.cancel() }
        let workspaceNotificationCenter = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach { workspaceNotificationCenter.removeObserver($0) }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        NotificationCenter.default.removeObserver(self)
    }

    func setEnabled(_ isEnabled: Bool) {
        config.isEnabled = isEnabled
    }

    func setShowsMenuBarIcon(_ isVisible: Bool) {
        var nextConfig = config
        nextConfig.showsMenuBarIcon = isVisible
        if !nextConfig.showsMenuBarIcon && !nextConfig.showsDockIcon {
            nextConfig.showsDockIcon = true
        }
        config = nextConfig
    }

    func setShowsDockIcon(_ isVisible: Bool) {
        var nextConfig = config
        nextConfig.showsDockIcon = isVisible
        if !nextConfig.showsDockIcon {
            nextConfig.showsMenuBarIcon = true
        }
        config = nextConfig
    }

    func setOpenAtLogin(_ shouldOpenAtLogin: Bool) {
        openAtLoginError = nil

        do {
            switch (shouldOpenAtLogin, SMAppService.mainApp.status) {
            case (true, .enabled), (true, .requiresApproval):
                break
            case (true, _):
                try SMAppService.mainApp.register()
            case (false, .enabled), (false, .requiresApproval):
                try SMAppService.mainApp.unregister()
            case (false, _):
                break
            }
        } catch {
            openAtLoginError = error.localizedDescription
        }

        refreshOpenAtLoginStatus()
    }

    func refreshOpenAtLoginStatus() {
        switch SMAppService.mainApp.status {
        case .enabled:
            opensAtLogin = true
            openAtLoginStatus = "Enabled"
        case .requiresApproval:
            opensAtLogin = true
            openAtLoginStatus = "Needs approval in Login Items"
        case .notRegistered:
            opensAtLogin = false
            openAtLoginStatus = "Disabled"
        case .notFound:
            opensAtLogin = false
            openAtLoginStatus = "Unavailable"
        @unknown default:
            opensAtLogin = false
            openAtLoginStatus = "Unknown"
        }
    }

    func addMapping() {
        config.mappings.append(LayerMapping())
    }

    func removeMappings(at offsets: IndexSet) {
        config.mappings.remove(atOffsets: offsets)
    }

    func removeMapping(id: UUID) {
        config.mappings.removeAll { $0.id == id }
    }

    func updateMapping(id: UUID, triggerKeyCode: UInt16? = nil, output: Shortcut? = nil, isEnabled: Bool? = nil) {
        guard let index = config.mappings.firstIndex(where: { $0.id == id }) else {
            return
        }

        if let triggerKeyCode {
            config.mappings[index].triggerKeyCode = triggerKeyCode
        }
        if let output {
            config.mappings[index].output = output
        }
        if let isEnabled {
            config.mappings[index].isEnabled = isEnabled
        }
    }

    func beginRecording(_ target: RecordingTarget) {
        recordingEventTap.stop()
        removeLocalMonitor()
        recordingTarget = target
        let didStartRecordingTap = recordingEventTap.start(
            onRecord: { [weak self] recordedKeyStroke in
                self?.handleRecordedKeyStroke(recordedKeyStroke)
            },
            onCancel: { [weak self] in
                self?.cancelRecording()
            }
        )

        if !didStartRecordingTap {
            installLocalMonitorIfNeeded()
        }
    }

    func cancelRecording() {
        recordingTarget = nil
        recordingEventTap.stop()
        removeLocalMonitor()
    }

    func recheckPermissions() {
        permissions.refresh()
        reconcileRuntime(refreshPermissions: false)
    }

    func reconcileRuntime(refreshPermissions: Bool = true) {
        if refreshPermissions {
            permissions.refresh()
        }

        guard config.isEnabled else {
            engine.stop()
            remapper.restore()
            updateRuntimeStatus()
            return
        }

        guard permissions.accessibilityGranted && permissions.inputMonitoringGranted else {
            engine.stop()
            remapper.restore()
            updateRuntimeStatus()
            return
        }

        if !remapper.isInstalled {
            remapper.install()
        }

        guard remapper.isInstalled else {
            engine.stop()
            updateRuntimeStatus()
            return
        }

        if !engine.isRunning && !engine.start() {
            remapper.restore()
        }
        updateRuntimeStatus()
    }

    func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)

        if let window = mainWindow ?? NSApp.windows.first(where: { !$0.isMiniaturized }) ?? NSApp.windows.first {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
        }
    }

    func registerMainWindow(_ window: NSWindow) {
        mainWindow = window
        window.isReleasedWhenClosed = false
    }

    private func installLocalMonitorIfNeeded() {
        guard localMonitor == nil else {
            return
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.handleRecordingEvent(event)
        }
    }

    private func removeLocalMonitor() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        localMonitor = nil
    }

    private func handleRecordingEvent(_ event: NSEvent) -> NSEvent? {
        guard let recordingTarget else {
            removeLocalMonitor()
            return event
        }

        if event.keyCode == 53 {
            cancelRecording()
            return nil
        }

        switch recordingTarget {
        case .trigger(let id):
            updateMapping(id: id, triggerKeyCode: event.keyCode)
        case .output(let id):
            updateMapping(id: id, output: Shortcut.output(from: event))
        }

        self.recordingTarget = nil
        recordingEventTap.stop()
        removeLocalMonitor()
        return nil
    }

    private func handleRecordedKeyStroke(_ recordedKeyStroke: RecordedKeyStroke) {
        guard let recordingTarget else {
            recordingEventTap.stop()
            removeLocalMonitor()
            return
        }

        switch recordingTarget {
        case .trigger(let id):
            updateMapping(id: id, triggerKeyCode: recordedKeyStroke.keyCode)
        case .output(let id):
            updateMapping(
                id: id,
                output: Shortcut.output(keyCode: recordedKeyStroke.keyCode, modifiers: recordedKeyStroke.modifiers)
            )
        }

        self.recordingTarget = nil
        recordingEventTap.stop()
        removeLocalMonitor()
    }

    private func updateRuntimeStatus() {
        if !config.isEnabled {
            runtimeStatus = "Disabled"
        } else if !permissions.accessibilityGranted {
            runtimeStatus = "Waiting for Accessibility"
        } else if !permissions.inputMonitoringGranted {
            runtimeStatus = "Waiting for Input Monitoring"
        } else if !remapper.isInstalled {
            runtimeStatus = remapper.lastError ?? "Waiting for Caps Lock remap"
        } else if engine.isRunning {
            runtimeStatus = "Running"
        } else {
            runtimeStatus = engine.lastError ?? "Stopped"
        }
        applyPresentationOptions()
    }

    private func configureMenuBarController() {
        menuBarController.onShow = { [weak self] in
            self?.showMainWindow()
        }
        menuBarController.onToggleEnabled = { [weak self] in
            guard let self else {
                return
            }
            setEnabled(!config.isEnabled)
        }
        menuBarController.onQuit = {
            NSApp.terminate(nil)
        }
    }

    private func applyPresentationOptions() {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            NSApp.setActivationPolicy(config.showsDockIcon ? .regular : .accessory)
            menuBarController.update(
                isVisible: config.showsMenuBarIcon,
                isEnabled: config.isEnabled,
                runtimeStatus: runtimeStatus
            )
        }
    }

    private func observeWorkspaceWakeEvents() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        let wakeEvents: [Notification.Name] = [
            NSWorkspace.didWakeNotification,
            NSWorkspace.screensDidWakeNotification
        ]

        workspaceObservers = wakeEvents.map { name in
            notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                self?.scheduleKeyboardRecovery(reason: notification.name.rawValue)
            }
        }
    }

    private func scheduleKeyboardRecovery(reason: String) {
        logger.info("Scheduling keyboard recovery after \(reason, privacy: .public)")
        recoveryWorkItems.forEach { $0.cancel() }
        recoveryWorkItems.removeAll()

        // Bluetooth and external keyboards may return after the initial wake notification.
        for delay in [1.0, 4.0] {
            let workItem = DispatchWorkItem { [weak self] in
                self?.recoverKeyboardLayerAfterWake()
            }
            recoveryWorkItems.append(workItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }

    private func recoverKeyboardLayerAfterWake() {
        guard config.isEnabled,
              permissions.accessibilityGranted,
              permissions.inputMonitoringGranted else {
            reconcileRuntime(refreshPermissions: true)
            return
        }

        engine.stop()
        remapper.refresh()

        if remapper.isInstalled {
            _ = engine.start()
        }
        logger.info(
            "Keyboard recovery completed: remapper=\(self.remapper.isInstalled), eventTap=\(self.engine.isRunning)"
        )
        updateRuntimeStatus()
    }

    @objc private func appWillTerminate() {
        engine.stop()
        remapper.restore()
    }

    @objc private func appDidBecomeActive() {
        refreshOpenAtLoginStatus()
    }

    @objc private func displayConfigurationDidChange() {
        scheduleKeyboardRecovery(reason: NSApplication.didChangeScreenParametersNotification.rawValue)
    }
}
