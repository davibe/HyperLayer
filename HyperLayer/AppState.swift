import AppKit
import Combine
import Foundation
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
    private let recordingEventTap = RecordingEventTap()
    private var localMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    init() {
        config = store.load()
        engine.update(config: config)

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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )

        refreshOpenAtLoginStatus()
        permissions.startPolling(every: 10.0) { [weak self] in
            self?.reconcileRuntime(refreshPermissions: false)
        }
        reconcileRuntime()
    }

    deinit {
        recordingEventTap.stop()
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        NotificationCenter.default.removeObserver(self)
    }

    func setEnabled(_ isEnabled: Bool) {
        config.isEnabled = isEnabled
    }

    func setPassThroughUnmappedKeys(_ isEnabled: Bool) {
        config.passThroughUnmappedKeys = isEnabled
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
            updateMapping(id: id, output: Shortcut.from(event: event))
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
                output: Shortcut(keyCode: recordedKeyStroke.keyCode, modifiers: recordedKeyStroke.modifiers)
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
    }

    @objc private func appWillTerminate() {
        engine.stop()
        remapper.restore()
    }

    @objc private func appDidBecomeActive() {
        refreshOpenAtLoginStatus()
    }
}
