import SwiftUI

@ViewBuilder
func liquidGlassCluster<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    if #available(macOS 26.0, *) {
        GlassEffectContainer {
            content()
        }
    } else {
        content()
    }
}

extension View {
    @ViewBuilder
    func liquidGlassSurface(cornerRadius: CGFloat = 8) -> some View {
        if #available(macOS 26.0, *) {
            glassEffect(in: .rect(cornerRadius: cornerRadius, style: .continuous))
        } else {
            background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(.primary.opacity(0.12), lineWidth: 0.5)
                    }
            }
        }
    }
}
