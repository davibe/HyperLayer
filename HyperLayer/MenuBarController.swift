import AppKit

final class MenuBarController: NSObject {
    var onShow: (() -> Void)?
    var onToggleEnabled: (() -> Void)?
    var onQuit: (() -> Void)?

    private var statusItem: NSStatusItem?
    private var isEnabled = false
    private var runtimeStatus = ""

    func update(isVisible: Bool, isEnabled: Bool, runtimeStatus: String) {
        self.isEnabled = isEnabled
        self.runtimeStatus = runtimeStatus

        guard isVisible else {
            removeStatusItem()
            return
        }

        ensureStatusItem()
        rebuildMenu()
    }

    private func ensureStatusItem() {
        guard statusItem == nil else {
            return
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = MenuBarIcon.image()
            button.toolTip = "HyperLayer"
        }
        statusItem = item
    }

    private func removeStatusItem() {
        guard let statusItem else {
            return
        }

        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let statusMenuItem = NSMenuItem(title: runtimeStatus, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Show HyperLayer", action: #selector(showHyperLayer), keyEquivalent: ""))
        menu.addItem(NSMenuItem(
            title: isEnabled ? "Disable HyperLayer" : "Enable HyperLayer",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        ))

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit HyperLayer", action: #selector(quitHyperLayer), keyEquivalent: "q"))

        for item in menu.items where item.action != nil {
            item.target = self
        }

        statusItem?.menu = menu
    }

    @objc private func showHyperLayer() {
        onShow?()
    }

    @objc private func toggleEnabled() {
        onToggleEnabled?()
    }

    @objc private func quitHyperLayer() {
        onQuit?()
    }
}
