import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            permissionsPanel
            layerPanel
            mappingsPanel
            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: 40, leading: 24, bottom: 24, trailing: 24))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("HyperLayer")
                    .font(.largeTitle.weight(.semibold))
                Text(appState.runtimeStatus)
                    .foregroundStyle(statusColor)
            }
            Spacer()
            Toggle("Enabled", isOn: Binding(
                get: { appState.config.isEnabled },
                set: { appState.setEnabled($0) }
            ))
            .toggleStyle(.switch)
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
                        Button("Request Input Monitoring") {
                            appState.permissions.requestInputMonitoring()
                            appState.reconcileRuntime()
                        }
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

    private var layerPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Layer Behavior")
                .font(.headline)

            Toggle("Pass through unmapped Caps Lock combinations", isOn: Binding(
                get: { appState.config.passThroughUnmappedKeys },
                set: { appState.setPassThroughUnmappedKeys($0) }
            ))

            HStack {
                RuntimePill(title: "Caps Lock remap", isOn: appState.remapper.isInstalled)
                RuntimePill(title: "Event tap", isOn: appState.engine.isRunning)
                Spacer()
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

private struct RuntimePill: View {
    let title: String
    let isOn: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isOn ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.callout)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quaternary, in: Capsule())
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
