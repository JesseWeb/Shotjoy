import SwiftUI

final class ScrollingHUDModel: ObservableObject {
    @Published var frameCount = 0
    var onDone: (() -> Void)?
    var onCancel: (() -> Void)?
}

struct ScrollingHUDView: View {
    @ObservedObject var model: ScrollingHUDModel
    @ObservedObject private var languageManager = LanguageManager.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.up.and.down.text.horizontal")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.scrollingCapture)
                    .font(.system(size: 12, weight: .semibold))
                Text(L10n.scrollInstructions)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                Text(L10n.framesCaptured(model.frameCount))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 6)
            Button(L10n.done) { model.onDone?() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            Button(L10n.cancel) { model.onCancel?() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 356)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        )
        .padding(6)
    }
}
