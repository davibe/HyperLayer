import AppKit

enum MenuBarIcon {
    static func image() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()

            let chevron = NSBezierPath()
            chevron.lineWidth = 2.4
            chevron.lineCapStyle = .round
            chevron.lineJoinStyle = .round
            chevron.move(to: NSPoint(x: 5.1, y: 11.1))
            chevron.line(to: NSPoint(x: 9.0, y: 14.8))
            chevron.line(to: NSPoint(x: 12.9, y: 11.1))
            chevron.stroke()

            let upperLayer = NSBezierPath()
            upperLayer.lineWidth = 1.9
            upperLayer.lineCapStyle = .round
            upperLayer.lineJoinStyle = .round
            upperLayer.move(to: NSPoint(x: 4.0, y: 8.1))
            upperLayer.line(to: NSPoint(x: 9.0, y: 5.4))
            upperLayer.line(to: NSPoint(x: 14.0, y: 8.1))
            upperLayer.stroke()

            let lowerLayer = NSBezierPath()
            lowerLayer.lineWidth = 1.9
            lowerLayer.lineCapStyle = .round
            lowerLayer.lineJoinStyle = .round
            lowerLayer.move(to: NSPoint(x: 3.6, y: 5.3))
            lowerLayer.line(to: NSPoint(x: 9.0, y: 2.3))
            lowerLayer.line(to: NSPoint(x: 14.4, y: 5.3))
            lowerLayer.stroke()

            return true
        }
        image.isTemplate = true
        return image
    }
}
