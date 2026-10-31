import Foundation
import ShotDeskCore

enum CaptureTool: String, CaseIterable {
    case none
    case rectangle
    case ellipse
    case arrow
    case pen
    case mosaic
    case text

    var symbolName: String {
        switch self {
        case .none: return "cursorarrow"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .arrow: return "arrow.up.right"
        case .pen: return "pencil.tip"
        case .mosaic: return "checkerboard.rectangle"
        case .text: return "textformat"
        }
    }

    var title: String {
        switch self {
        case .none: return L10n.moveSelect
        case .rectangle: return L10n.rectangle
        case .ellipse: return L10n.ellipse
        case .arrow: return L10n.arrow
        case .pen: return L10n.brush
        case .mosaic: return L10n.mosaic
        case .text: return L10n.text
        }
    }
}

enum AnalyzeAction {
    case text
    case qrCode
}

enum FinishAction {
    case copy
    case save
    case pin
}
