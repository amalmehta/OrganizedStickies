import AppKit
import SwiftUI
import StickiesCore

/// The "muted paper" palette. Warm hues (butter, sand, clay) and cool hues
/// (sage, mist, lilac) form two families; dark mode keeps the same hue,
/// much deeper and quieter.
enum Theme {
    static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }

    static let window = dynamic(0xF4F0E8, 0x1B1A18)
    static let sidebar = dynamic(0xEDE8DE, 0x201F1C)
    static let ink = dynamic(0x2B2824, 0xECE7DE)
    static let quiet = dynamic(0x7A7268, 0x9C958A)
    static let hairline = dynamic(0x000000, 0xFFFFFF).opacity(0.08)
    /// The one muted blue accent.
    static let accent = dynamic(0x44679A, 0x8FA9D1)
    /// Warm terracotta, used sparingly: stale notes only.
    static let terracotta = dynamic(0xA9583A, 0xD48A6C)

    static func paper(_ c: FolderColor) -> Color {
        switch c {
        case .paper: dynamic(0xFCFAF5, 0x2A2825)
        case .butter: dynamic(0xF7EDC6, 0x3A3423)
        case .sand: dynamic(0xF1E5D1, 0x38312A)
        case .clay: dynamic(0xF1D9CB, 0x3D2D26)
        case .sage: dynamic(0xDFE8D6, 0x2A3428)
        case .mist: dynamic(0xDAE5F0, 0x26303B)
        case .lilac: dynamic(0xE6DFF0, 0x322C3B)
        case .stone: dynamic(0xE8E5E0, 0x2E2D2B)
        }
    }

    /// A stronger shade of the same hue, for sidebar dots and card edges.
    static func dot(_ c: FolderColor) -> Color {
        switch c {
        case .paper: dynamic(0xB9AF9F, 0x8F8677)
        case .butter: dynamic(0xD9B850, 0xC9A84A)
        case .sand: dynamic(0xC4A57A, 0xB3976F)
        case .clay: dynamic(0xC98463, 0xC08066)
        case .sage: dynamic(0x8BA67A, 0x86A078)
        case .mist: dynamic(0x7C9CC0, 0x7F9DC0)
        case .lilac: dynamic(0x9F8DC0, 0x9C8CBC)
        case .stone: dynamic(0x9E9890, 0x8A857E)
        }
    }

    static func titleFont(_ scale: Double) -> Font { .system(size: 15 * scale, weight: .semibold, design: .serif) }
    static func bodyFont(_ scale: Double) -> Font { .system(size: 13 * scale) }
    static func smallFont(_ scale: Double) -> Font { .system(size: 11 * scale) }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

/// Text size from Settings, for people who want larger text.
enum TextSize: String, CaseIterable, Identifiable {
    case small, standard, large, extraLarge
    var id: String { rawValue }
    var scale: Double {
        switch self {
        case .small: 0.9
        case .standard: 1
        case .large: 1.15
        case .extraLarge: 1.3
        }
    }
    var label: String {
        switch self {
        case .small: "Small"
        case .standard: "Default"
        case .large: "Large"
        case .extraLarge: "Extra large"
        }
    }
}

extension FolderKind {
    var symbol: String {
        switch self {
        case .inbox: "tray"
        case .archive: "archivebox"
        case .user: "folder"
        }
    }
}

/// The window's backdrop: Liquid Glass that lets the desktop show through
/// the whole window (board, toolbar and around the sidebar), with a thin wash
/// of paper so it stays warm and the cards read. The older frosted materials
/// draw as flat grey on macOS 26, so they can't do this.
/// Solid paper when Reduce Transparency is on.
struct Backdrop: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var tint = Theme.window
    var wash = 0.3

    var body: some View {
        if reduceTransparency {
            tint
        } else {
            ZStack {
                WindowGlass()
                tint.opacity(wash)
            }
        }
    }
}

private struct WindowGlass: NSViewRepresentable {
    func makeNSView(context: Context) -> NSGlassEffectView {
        let v = NSGlassEffectView()
        v.style = .regular
        v.cornerRadius = 0
        return v
    }

    func updateNSView(_ nsView: NSGlassEffectView, context: Context) {}
}
