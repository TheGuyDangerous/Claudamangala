import SwiftUI

struct GlassButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .liquidGlassSurface(cornerRadius: 8)
            .opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GlassButtonStyle {
    static var glass: GlassButtonStyle { GlassButtonStyle() }
}
