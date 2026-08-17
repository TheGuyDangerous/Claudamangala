import SwiftUI

@ViewBuilder
func liquidGlassCluster<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    content()
}

extension View {
    func liquidGlassSurface(cornerRadius: CGFloat = 8) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return background {
            shape
                .fill(.ultraThinMaterial)
                .overlay {
                    shape.strokeBorder(.primary.opacity(0.12), lineWidth: 0.5)
                }
        }
    }
}

struct MinimalDivider: View {
    var width: CGFloat = 80

    var body: some View {
        Capsule()
            .fill(Color.primary.opacity(0.14))
            .frame(width: width, height: 0.5)
            .frame(maxWidth: .infinity)
    }
}
