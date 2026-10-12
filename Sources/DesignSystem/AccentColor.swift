import SwiftUI
import AppKit

// The user-chosen accent. Theme.Color.accent reads through this @Observable store, so every view
// that uses the accent re-renders the moment the choice changes, with no relaunch.
@MainActor
@Observable
final class AccentColorStore {
    static let shared = AccentColorStore()

    struct Preset: Identifiable {
        let name: String
        let hex: UInt32
        var id: UInt32 { hex }
    }

    static let defaultHex: UInt32 = 0x2DD4BF

    static let presets: [Preset] = [
        Preset(name: "Teal", hex: 0x2DD4BF),
        Preset(name: "Sky", hex: 0x38BDF8),
        Preset(name: "Indigo", hex: 0x818CF8),
        Preset(name: "Violet", hex: 0xC084FC),
        Preset(name: "Pink", hex: 0xF472B6),
        Preset(name: "Coral", hex: 0xFB7185),
        Preset(name: "Amber", hex: 0xFBBF24),
        Preset(name: "Lime", hex: 0xA3E635)
    ]

    private static let key = "accentHex"

    var hex: UInt32 {
        didSet { UserDefaults.standard.set(Int(hex), forKey: Self.key) }
    }

    var color: Color { Color(hex: hex) }

    private init() {
        let stored = UserDefaults.standard.object(forKey: Self.key) as? Int
        hex = stored.map { UInt32(truncatingIfNeeded: $0) } ?? Self.defaultHex
    }

    // Bridges SwiftUI's ColorPicker (any color) into the stored hex.
    var pickerBinding: Binding<Color> {
        Binding(
            get: { self.color },
            set: { newValue in
                guard let rgb = NSColor(newValue).usingColorSpace(.sRGB) else { return }
                let red = UInt32((rgb.redComponent * 255).rounded())
                let green = UInt32((rgb.greenComponent * 255).rounded())
                let blue = UInt32((rgb.blueComponent * 255).rounded())
                self.hex = (red << 16) | (green << 8) | blue
            }
        )
    }
}

// Settings row: preset swatches plus a picker for any other color.
struct AccentColorPicker: View {
    @State private var store = AccentColorStore.shared

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AccentColorStore.presets) { preset in
                Button { store.hex = preset.hex } label: {
                    Circle()
                        .fill(Color(hex: preset.hex))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.primary.opacity(store.hex == preset.hex ? 0.9 : 0), lineWidth: 2)
                                .padding(-3)
                        )
                }
                .buttonStyle(.plain)
                .help(preset.name)
            }
            Spacer(minLength: 0)
            ColorPicker("Custom", selection: store.pickerBinding, supportsOpacity: false)
                .labelsHidden()
                .help("Pick any color")
        }
        .padding(.vertical, 2)
    }
}
