import AppKit
import SwiftUI
import ShotjoyCore

struct ToolbarView: View {
    @ObservedObject var model: ToolbarModel
    @ObservedObject private var languageManager = LanguageManager.shared

    private let tools: [CaptureTool] = [.none, .rectangle, .ellipse, .arrow, .pen, .mosaic, .text]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(tools, id: \.rawValue) { tool in
                toolButton(tool)
            }

            divider

            colorPalette

            divider

            toolButton(symbol: "person.crop.rectangle", title: L10n.aiMask) {
                model.onAIMask?()
            }

            toolButton(symbol: "text.viewfinder", title: L10n.recognizeText) {
                model.onAnalyze?(.text)
            }

            toolButton(symbol: "qrcode.viewfinder", title: L10n.scanQRCode) {
                model.onAnalyze?(.qrCode)
            }

            toolButton(symbol: "arrow.up.and.down.text.horizontal", title: L10n.scrollingCapture) {
                model.onScroll?()
            }

            toolButton(symbol: "arrow.uturn.backward", title: L10n.undo, enabled: model.canUndo) {
                model.onUndo?()
            }

            divider

            toolButton(symbol: "pin", title: L10n.pin) { model.onPin?() }
            toolButton(symbol: "square.and.arrow.down", title: L10n.save) { model.onSave?() }

            divider

            toolButton(symbol: "xmark", title: L10n.cancel, tint: .red) { model.onCancel?() }

            Button {
                model.onFinish?()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                    Text(L10n.done)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 11)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.accentColor)
                )
            }
            .buttonStyle(.plain)
            .help(L10n.done)
        }
        .padding(.horizontal, 9)
        .frame(height: 54)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.28), radius: 12, y: 4)
        )
        .padding(4)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.15))
            .frame(width: 1, height: 20)
            .padding(.horizontal, 3)
    }

    private var colorPalette: some View {
        HStack(spacing: 2) {
            ForEach(RGBAColor.palette, id: \.self) { color in
                Button {
                    model.pick(color)
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(nsColor: color.nsColor))
                        Circle()
                            .strokeBorder(Color.black.opacity(0.22), lineWidth: 0.5)
                        if model.color == color {
                            Circle()
                                .strokeBorder(Color.white, lineWidth: 2)
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(color == .white ? Color.black : Color.white)
                        }
                    }
                    .frame(width: 18, height: 18)
                    .padding(3)
                    .background(
                        Circle()
                            .fill(model.color == color ? Color.white.opacity(0.12) : Color.clear)
                    )
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(colorName(color))
            }
        }
        .padding(.horizontal, 4)
    }

    private func toolButton(_ tool: CaptureTool) -> some View {
        toolButton(
            symbol: tool.symbolName,
            title: tool.title,
            selected: model.activeTool == tool
        ) {
            model.select(model.activeTool == tool ? .none : tool)
        }
    }

    private func toolButton(
        symbol: String,
        title: String,
        selected: Bool = false,
        enabled: Bool = true,
        tint: Color = .primary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(enabled ? tint : tint.opacity(0.3))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(selected ? Color.accentColor.opacity(0.18) : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(title)
    }

    private func colorName(_ color: RGBAColor) -> String {
        if color == .red { return L10n.t("红色", "Red") }
        if color == .orange { return L10n.t("橙色", "Orange") }
        if color == .yellow { return L10n.t("黄色", "Yellow") }
        if color == .green { return L10n.t("绿色", "Green") }
        if color == .blue { return L10n.t("蓝色", "Blue") }
        if color == .white { return L10n.t("白色", "White") }
        return L10n.color
    }
}
