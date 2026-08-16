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
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(macOS 26.0, *) {
            glassEffect(in: shape)
                .overlay {
                    shape.strokeBorder(.primary.opacity(0.12), lineWidth: 0.5)
                }
        } else {
            background {
                shape
                    .fill(.ultraThinMaterial)
                    .overlay {
                        shape.strokeBorder(.primary.opacity(0.12), lineWidth: 0.5)
                    }
            }
        }
    }
}
