import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            permissionsPanel
            optionsPanel
            mappingsPanel
            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: 40, leading: 24, bottom: 24, trailing: 24))
        .background(WindowAccessor { window in
            appState.registerMainWindow(window)
        })
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("HyperLayer")
                        .font(.largeTitle.weight(.semibold))
                    if let appVersionText {
                        Text(appVersionText)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(appState.runtimeStatus)
                    .foregroundStyle(statusColor)
            }
            Spacer()
            Toggle("Enabled", isOn: Binding(
                get: { appState.config.isEnabled },
                set: { appState.setEnabled($0) }
            ))
            .toggleStyle(.switch)
            .focusable(false)
            .help("Enable or disable HyperLayer")
        }
    }

    private var permissionsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Permissions")
                .font(.headline)

            HStack(spacing: 16) {
                PermissionRow(title: "Accessibility", isGranted: appState.permissions.accessibilityGranted)
                PermissionRow(title: "Input Monitoring", isGranted: appState.permissions.inputMonitoringGranted)
                Spacer()
            }

            if !appState.permissions.accessibilityGranted || !appState.permissions.inputMonitoringGranted {
                HStack {
                    if !appState.permissions.accessibilityGranted {
                        Button("Request Accessibility") {
                            appState.permissions.requestAccessibility()
                            appState.reconcileRuntime()
                        }
                        Button("Accessibility Settings") {
                            appState.permissions.openAccessibilitySettings()
                        }
                    }
                    if !appState.permissions.inputMonitoringGranted {
                        Button("Input Monitoring Settings") {
                            appState.permissions.openInputMonitoringSettings()
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var optionsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Options")
                .font(.headline)

            Toggle("Show menu bar icon", isOn: Binding(
                get: { appState.config.showsMenuBarIcon },
                set: { appState.setShowsMenuBarIcon($0) }
            ))

            Toggle("Show Dock icon", isOn: Binding(
                get: { appState.config.showsDockIcon },
                set: { appState.setShowsDockIcon($0) }
            ))

            Toggle("Open HyperLayer at Login", isOn: Binding(
                get: { appState.opensAtLogin },
                set: { appState.setOpenAtLogin($0) }
            ))

            if let openAtLoginError = appState.openAtLoginError {
                Text(openAtLoginError)
                    .font(.callout)
                    .foregroundStyle(.red)
            } else if appState.openAtLoginStatus != "Enabled" && appState.openAtLoginStatus != "Disabled" {
                Text(appState.openAtLoginStatus)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var mappingsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Mappings")
                    .font(.headline)
                Spacer()
                Button("Add Mapping") {
                    appState.addMapping()
                }
            }

            if appState.config.mappings.isEmpty {
                ContentUnavailableView(
                    "No Mappings",
                    systemImage: "keyboard",
                    description: Text("Add a mapping, record the key pressed with Caps Lock, then record the output shortcut.")
                )
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                List {
                    ForEach(appState.config.mappings) { mapping in
                        MappingRow(mapping: mapping)
                            .environmentObject(appState)
                    }
                    .onDelete { offsets in
                        appState.removeMappings(at: offsets)
                    }
                }
                .listStyle(.inset)
                .frame(minHeight: 180)
            }

            if let recordingText {
                Text(recordingText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var recordingText: String? {
        switch appState.recordingTarget {
        case .trigger:
            return "Press the key to use after Caps Lock. Escape cancels."
        case .output:
            return "Press the output shortcut. Escape cancels."
        case nil:
            return nil
        }
    }

    private var statusColor: Color {
        appState.runtimeStatus == "Running" ? .green : .secondary
    }

    private var appVersionText: String? {
        guard
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            !version.isEmpty
        else {
            return nil
        }

        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let build, !build.isEmpty {
            return "v\(version) (\(build))"
        }

        return "v\(version)"
    }
}

private struct PermissionRow: View {
    let title: String
    let isGranted: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isGranted ? Color.green : Color.orange)
                .frame(width: 9, height: 9)
            Text(title)
            Text(isGranted ? "Granted" : "Needed")
                .foregroundStyle(.secondary)
        }
    }
}

private struct MappingRow: View {
    @EnvironmentObject private var appState: AppState
    let mapping: LayerMapping

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { mapping.isEnabled },
                set: { appState.updateMapping(id: mapping.id, isEnabled: $0) }
            ))
            .labelsHidden()

            Text("Caps Lock +")
                .foregroundStyle(.secondary)

            Button(triggerTitle) {
                appState.beginRecording(.trigger(mapping.id))
            }
            .frame(minWidth: 130, alignment: .leading)

            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)

            Button(outputTitle) {
                appState.beginRecording(.output(mapping.id))
            }
            .frame(minWidth: 130, alignment: .leading)

            Spacer()

            Button {
                appState.removeMapping(id: mapping.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 5)
    }

    private var triggerTitle: String {
        if let triggerKeyCode = mapping.triggerKeyCode {
            return KeyCodeCatalog.name(for: triggerKeyCode)
        }
        return "Record Trigger"
    }

    private var outputTitle: String {
        mapping.output?.displayName ?? "Record Output"
    }
}
