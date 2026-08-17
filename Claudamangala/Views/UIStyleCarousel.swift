import SwiftUI

struct UIStyleCarousel<Content: View>: View {
    @Binding var previewIndex: Int
    let onChoose: () -> Void
    @ViewBuilder let content: (AccountUIStyle) -> Content

    private var currentStyle: AccountUIStyle {
        AccountUIStyle.allCases[previewIndex]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        previewIndex = max(0, previewIndex - 1)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(previewIndex == 0)
                .opacity(previewIndex == 0 ? 0.35 : 1)

                Spacer()

                VStack(spacing: 2) {
                    Text(currentStyle.title)
                        .font(.subheadline.weight(.semibold))
                    Text("\(previewIndex + 1) of \(AccountUIStyle.allCases.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        previewIndex = min(AccountUIStyle.allCases.count - 1, previewIndex + 1)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(previewIndex >= AccountUIStyle.allCases.count - 1)
                .opacity(previewIndex >= AccountUIStyle.allCases.count - 1 ? 0.35 : 1)
            }

            Text(currentStyle.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            content(currentStyle)
                .id(currentStyle)
                .animation(.easeInOut(duration: 0.2), value: currentStyle)

            Button("Use \(currentStyle.title) style") {
                onChoose()
            }
            .buttonStyle(.glass)
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 4)
    }
}
