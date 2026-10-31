import AppKit
import SwiftUI

final class PreviewModel: ObservableObject {
    @Published var title: String = ""
    @Published var image: NSImage?
    @Published var text: String?
    var onCopy: (() -> Void)?
    var onSave: (() -> Void)?
    var onPin: (() -> Void)?
    var onClose: (() -> Void)?
}

struct PreviewView: View {
    @ObservedObject var model: PreviewModel

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let image = model.image {
                    ScrollView([.vertical, .horizontal]) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 720)
                            .padding(16)
                    }
                } else {
                    ScrollView {
                        Text(model.text ?? "")
                            .font(.system(size: 12.5))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.55))

            Divider()

            HStack(spacing: 10) {
                Text(model.title)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(L10n.copy) { model.onCopy?() }
                    .keyboardShortcut("c", modifiers: .command)
                if model.image != nil {
                    Button(L10n.save) { model.onSave?() }
                        .keyboardShortcut("s", modifiers: .command)
                    Button(L10n.pin) { model.onPin?() }
                }
                Button(L10n.close) { model.onClose?() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(minWidth: 560, minHeight: 420)
    }
}
