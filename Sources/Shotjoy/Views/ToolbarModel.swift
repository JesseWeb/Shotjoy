import Foundation
import ShotjoyCore

final class ToolbarModel: ObservableObject {
    @Published var activeTool: CaptureTool = .none
    @Published var color: RGBAColor = .red
    @Published var canUndo = false
    @Published var hasSelection = false

    var onTool: ((CaptureTool) -> Void)?
    var onUndo: (() -> Void)?
    var onColor: ((RGBAColor) -> Void)?
    var onFinish: (() -> Void)?
    var onSave: (() -> Void)?
    var onPin: (() -> Void)?
    var onCancel: (() -> Void)?
    var onAnalyze: ((AnalyzeAction) -> Void)?
    var onAIMask: (() -> Void)?
    var onScroll: (() -> Void)?

    func select(_ tool: CaptureTool) {
        activeTool = tool
        onTool?(tool)
    }

    func pick(_ color: RGBAColor) {
        self.color = color
        onColor?(color)
    }

    func sync(tool: CaptureTool, color: RGBAColor, canUndo: Bool, hasSelection: Bool) {
        if activeTool != tool { activeTool = tool }
        if self.color != color { self.color = color }
        if self.canUndo != canUndo { self.canUndo = canUndo }
        if self.hasSelection != hasSelection { self.hasSelection = hasSelection }
    }
}
