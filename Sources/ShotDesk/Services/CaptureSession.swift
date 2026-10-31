import AppKit
import CoreGraphics
import ShotDeskCore

final class CaptureSession: NSObject, NSTextFieldDelegate {
    let screens: [CapturedScreen]
    let canvasBounds: CGRect

    private(set) var selection: CGRect?
    private(set) var annotations = AnnotationStack()
    private(set) var activeTool: CaptureTool = .none
    private(set) var strokeColor: RGBAColor = .red
    private(set) var hoverWindowRect: CGRect?
    private(set) var cursorPoint: CGPoint = .zero

    var onFinish: ((CGImage, FinishAction) -> Void)?
    var onAnalyze: ((CGImage, AnalyzeAction) -> Void)?
    var onScroll: ((CGRect, CGDirectDisplayID) -> Void)?
    var onCancel: (() -> Void)?

    let toolbarModel = ToolbarModel()

    var showsMagnifier: Bool {
        guard textField == nil else { return false }
        switch dragState {
        case .selecting, .resizing, .drawing:
            return true
        case .moving:
            return false
        case .none:
            return selection == nil
        }
    }

    private var windows: [OverlayWindow] = []
    private var views: [OverlayView] = []
    private var toolbarController: ToolbarPanelController?
    private var dragState: DragState?
    private var draft: Annotation?
    private var keyMonitor: Any?
    private var textField: NSTextField?
    private var textAnchor: CGPoint = .zero
    private var textScreen: CapturedScreen?
    private var isFinishing = false

    private enum DragState {
        case selecting(start: CGPoint)
        case moving(last: CGPoint, original: CGRect)
        case resizing(handle: SelectionHandle, original: CGRect)
        case drawing
    }

    init(screens: [CapturedScreen]) {
        self.screens = screens
        self.canvasBounds = screens.map(\.bounds).reduce(CGRect.null) { $0.union($1) }
        super.init()
    }

    // MARK: - Lifecycle

    func start() {
        guard !screens.isEmpty else { return }
        let mainHeight = NSScreen.main?.frame.height ?? screens[0].bounds.height

        for screen in screens {
            let cocoaFrame = NSScreen.screens
                .first(where: { ScreenCaptureService.displayID(for: $0) == screen.displayID })?
                .frame
                ?? GlobalCoordinates.quartzToCocoa(screen.bounds, mainScreenHeight: mainHeight)

            let window = OverlayWindow(
                contentRect: cocoaFrame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.setFrame(cocoaFrame, display: true)
            window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .ignoresCycle]
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.isMovable = false
            window.isMovableByWindowBackground = false
            window.acceptsMouseMovedEvents = true
            window.ignoresMouseEvents = false
            window.isReleasedWhenClosed = false

            let view = OverlayView(screen: screen, session: self)
            window.contentView = view
            window.orderFrontRegardless()
            windows.append(window)
            views.append(view)
        }

        NSApp.activate()
        _ = NSRunningApplication.current.activate(options: [.activateAllWindows])

        let mouse = CGEvent(source: nil)?.location ?? CGPoint(x: canvasBounds.midX, y: canvasBounds.midY)
        cursorPoint = mouse
        if let index = screens.firstIndex(where: { $0.bounds.contains(mouse) }) {
            windows[index].makeKeyAndOrderFront(nil)
            windows[index].makeFirstResponder(views[index])
        } else if let first = windows.first {
            first.makeKeyAndOrderFront(nil)
        }
        NSCursor.crosshair.set()


        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if self.textField != nil { return event }
            return self.handleKey(event) ? nil : event
        }

        toolbarModel.onTool = { [weak self] tool in
            self?.activeTool = tool
            self?.redraw()
        }
        toolbarModel.onUndo = { [weak self] in self?.undo() }
        toolbarModel.onColor = { [weak self] color in
            self?.strokeColor = color
            self?.redraw()
        }
        toolbarModel.onFinish = { [weak self] in self?.finish(.copy) }
        toolbarModel.onSave = { [weak self] in self?.finish(.save) }
        toolbarModel.onPin = { [weak self] in self?.finish(.pin) }
        toolbarModel.onCancel = { [weak self] in self?.cancel() }
        toolbarModel.onAnalyze = { [weak self] action in self?.analyze(action) }
        toolbarModel.onAIMask = { [weak self] in self?.applyAIMask() }
        toolbarModel.onScroll = { [weak self] in self?.beginScrollingCapture() }
        toolbarModel.sync(tool: activeTool, color: strokeColor, canUndo: annotations.canUndo, hasSelection: false)
    }

    func cancel() {
        guard !isFinishing else { return }
        dismiss()
        onCancel?()
    }

    private func dismiss() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        removeTextField()
        toolbarController?.close()
        toolbarController = nil
        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
        views.removeAll()
        NSCursor.arrow.set()
    }

    // MARK: - Mouse

    func mouseMoved(to point: CGPoint) {
        cursorPoint = point
        if selection == nil {
            let next = WindowLocator.windowRect(at: point)
            if next != hoverWindowRect {
                hoverWindowRect = next
            }
        }
        // The crosshair and magnifier follow the pointer, so every move needs
        // a redraw even when the hovered window did not change.
        redraw()
        updateCursor(at: point)
    }

    func mouseDown(at point: CGPoint, in view: OverlayView, clickCount: Int = 1) {
        cursorPoint = point
        windowForPoint(point)?.makeFirstResponder(view)

        if clickCount >= 2, let selection, selection.contains(point) {
            finish(.copy)
            return
        }

        if selection == nil, hoverWindowRect == nil {
            hoverWindowRect = WindowLocator.windowRect(at: point)
        }

        if let selection {
            if let handle = SelectionGeometry.handle(at: point, in: selection) {
                dragState = .resizing(handle: handle, original: selection)
                return
            }
            if selection.contains(point) {
                switch activeTool {
                case .none:
                    dragState = .moving(last: point, original: selection)
                case .text:
                    beginText(at: point)
                default:
                    beginDraft(at: point)
                }
                return
            }
        }

        // A click outside an existing selection starts a new one.
        annotations.clear()
        toolbarController?.close()
        toolbarController = nil
        toolbarModel.sync(tool: activeTool, color: strokeColor, canUndo: false, hasSelection: false)
        selection = CGRect(origin: point, size: .zero)
        hoverWindowRect = nil
        dragState = .selecting(start: point)
        updateCursor(at: point)
        redraw()
    }

    func mouseDragged(to point: CGPoint) {
        cursorPoint = point
        guard let dragState else { return }
        switch dragState {
        case .selecting(let start):
            selection = SelectionGeometry.clamped(
                SelectionGeometry.normalized(from: start, to: point),
                to: canvasBounds
            )
        case .moving(let last, let original):
            let delta = CGPoint(x: point.x - last.x, y: point.y - last.y)
            selection = SelectionGeometry.moved(original, by: delta, within: canvasBounds)
            self.dragState = .moving(last: point, original: original)
            updateToolbarPosition()
        case .resizing(let handle, let original):
            selection = SelectionGeometry.resized(
                original,
                handle: handle,
                to: point,
                minSize: 4,
                within: canvasBounds
            )
            updateToolbarPosition()
        case .drawing:
            updateDraft(to: point)
        }
        redraw()
    }

    func mouseUp(at point: CGPoint) {
        guard let dragState else { return }
        self.dragState = nil

        switch dragState {
        case .selecting:
            if let selection, selection.width >= 4, selection.height >= 4 {
                completeSelection()
            } else if let hover = hoverWindowRect, hover.width >= 20, hover.height >= 20 {
                selection = hover
                hoverWindowRect = nil
                completeSelection()
            } else {
                selection = nil
                redraw()
            }
        case .moving, .resizing:
            completeSelection()
        case .drawing:
            commitDraft()
        }
        updateCursor(at: point)
    }

    private func completeSelection() {
        guard var selection else { return }
        selection = SelectionGeometry.clamped(selection, to: canvasBounds)
        guard selection.width >= 4, selection.height >= 4 else {
            self.selection = nil
            redraw()
            return
        }
        self.selection = selection
        hoverWindowRect = nil
        showToolbar()
        redraw()
    }

    private func updateCursor(at point: CGPoint) {
        if let selection {
            if let handle = SelectionGeometry.handle(at: point, in: selection) {
                switch handle {
                case .top, .bottom: NSCursor.resizeUpDown.set()
                case .left, .right: NSCursor.resizeLeftRight.set()
                default: NSCursor.crosshair.set()
                }
                return
            }
            if selection.contains(point), activeTool == .none {
                NSCursor.openHand.set()
                return
            }
        }
        NSCursor.crosshair.set()
    }

    // MARK: - Drawing

    private func beginDraft(at point: CGPoint) {
        let kind: Annotation.Kind
        var width: CGFloat = 3
        switch activeTool {
        case .rectangle: kind = .rectangle
        case .ellipse: kind = .ellipse
        case .arrow: kind = .arrow
        case .pen: kind = .pen
        case .mosaic: kind = .mosaic; width = 18
        default: return
        }
        draft = Annotation(
            kind: kind,
            start: point,
            end: point,
            points: kind == .pen || kind == .mosaic ? [point] : [],
            color: strokeColor,
            lineWidth: width
        )
        dragState = .drawing
        redraw()
    }

    private func updateDraft(to point: CGPoint) {
        guard var draft else { return }
        draft.end = point
        if draft.kind == .pen || draft.kind == .mosaic {
            if let last = draft.points.last {
                let dx = point.x - last.x
                let dy = point.y - last.y
                if dx * dx + dy * dy >= 2 {
                    draft.points.append(point)
                }
            } else {
                draft.points.append(point)
            }
        }
        self.draft = draft
    }

    private func commitDraft() {
        guard let draft else { return }
        defer {
            self.draft = nil
            redraw()
        }
        switch draft.kind {
        case .pen, .mosaic:
            guard draft.points.count >= 2 else { return }
        case .rectangle, .ellipse, .arrow:
            guard abs(draft.end.x - draft.start.x) >= 2 || abs(draft.end.y - draft.start.y) >= 2 else { return }
        case .text:
            return
        }
        annotations.add(draft)
        toolbarModel.sync(
            tool: activeTool,
            color: strokeColor,
            canUndo: annotations.canUndo,
            hasSelection: selection != nil
        )
    }

    var visibleAnnotations: [Annotation] {
        if let draft { return annotations.annotations + [draft] }
        return annotations.annotations
    }

    private func undo() {
        annotations.undo()
        toolbarModel.sync(
            tool: activeTool,
            color: strokeColor,
            canUndo: annotations.canUndo,
            hasSelection: selection != nil
        )
        redraw()
    }

    private func redraw() {
        for view in views { view.needsDisplay = true }
    }

    // MARK: - Text

    private func beginText(at point: CGPoint) {
        commitTextIfNeeded()
        guard let screen = screens.first(where: { $0.bounds.contains(point) }),
              let window = windowForPoint(point),
              let view = window.contentView as? OverlayView else {
            return
        }
        textAnchor = point
        textScreen = screen
        let local = CGPoint(x: point.x - screen.bounds.minX, y: point.y - screen.bounds.minY)
        var frame = CGRect(x: local.x, y: local.y, width: 240, height: 28)
        if frame.maxX > view.bounds.width - 8 { frame.origin.x = max(8, view.bounds.width - frame.width - 8) }
        if frame.maxY > view.bounds.height - 8 { frame.origin.y = max(8, view.bounds.height - frame.height - 8) }

        let field = NSTextField(frame: frame)
        field.font = .systemFont(ofSize: 16, weight: .semibold)
        field.textColor = strokeColor.nsColor
        field.backgroundColor = NSColor.white.withAlphaComponent(0.94)
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.drawsBackground = true
        field.focusRingType = .exterior
        field.target = self
        field.action = #selector(textFieldAction)
        field.delegate = self
        view.addSubview(field)
        window.makeFirstResponder(field)
        field.selectText(nil)
        textField = field
        redraw()
    }

    @objc private func textFieldAction() {
        commitTextIfNeeded()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            commitTextIfNeeded()
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            removeTextField()
            redraw()
            return true
        }
        return false
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        commitTextIfNeeded()
    }

    private func commitTextIfNeeded() {
        guard let field = textField else { return }
        let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty {
            annotations.add(
                Annotation(
                    kind: .text,
                    start: textAnchor,
                    text: value,
                    color: strokeColor,
                    lineWidth: 3
                )
            )
        }
        removeTextField()
        toolbarModel.sync(
            tool: activeTool,
            color: strokeColor,
            canUndo: annotations.canUndo,
            hasSelection: selection != nil
        )
        redraw()
    }

    private func removeTextField() {
        let field = textField
        textField = nil
        textScreen = nil
        field?.removeFromSuperview()
    }

    // MARK: - Keyboard

    /// Returns true when the event was consumed.
    func handleKey(_ event: NSEvent) -> Bool {
        if textField != nil {
            if event.keyCode == 53 {
                removeTextField()
                redraw()
                return true
            }
            if event.keyCode == 36 || event.keyCode == 76 {
                commitTextIfNeeded()
                return true
            }
            return false
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        switch event.keyCode {
        case 53: // Esc
            cancel()
            return true
        case 36, 76: // Return / keypad Enter
            finish(.copy)
            return true
        case 51, 117: // Delete
            undo()
            return true
        default:
            break
        }
        if flags.contains(.command) || flags.contains(.control) {
            switch event.keyCode {
            case 8: // C
                if selection == nil || dragState != nil {
                    if copyColorUnderCursor() { return true }
                }
                finish(.copy)
                return true
            case 1: // S
                finish(.save)
                return true
            case 6: // Z
                undo()
                return true
            default:
                break
            }
        }
        return false
    }

    // MARK: - Toolbar

    private func showToolbar() {
        guard let selection else { return }
        if toolbarController == nil {
            toolbarController = ToolbarPanelController(model: toolbarModel)
        }
        toolbarModel.sync(
            tool: activeTool,
            color: strokeColor,
            canUndo: annotations.canUndo,
            hasSelection: true
        )
        updateToolbarPosition()
        toolbarController?.show()
        _ = selection
    }

    private func updateToolbarPosition() {
        guard let toolbarController, let selection else { return }
        let mainHeight = NSScreen.main?.frame.height ?? 0
        let cocoa = GlobalCoordinates.quartzToCocoa(selection, mainScreenHeight: mainHeight)
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(cocoa) })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
        let visible = screen.visibleFrame
        let size = toolbarController.panel.frame.size
        var x = cocoa.midX - size.width / 2
        var y = cocoa.minY - size.height - 10
        if y < visible.minY + 6 {
            y = cocoa.maxY + 10
        }
        if y + size.height > visible.maxY - 6 {
            y = max(visible.minY + 6, cocoa.midY - size.height / 2)
        }
        x = max(visible.minX + 8, min(x, visible.maxX - size.width - 8))
        y = max(visible.minY + 6, min(y, visible.maxY - size.height - 6))
        toolbarController.panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Actions

    private func finish(_ action: FinishAction) {
        guard !isFinishing, let selection, selection.width >= 4, selection.height >= 4 else { return }
        isFinishing = true
        guard let image = renderFinalImage(includeAnnotations: true) else {
            isFinishing = false
            return
        }
        dismiss()
        onFinish?(image, action)
    }

    @discardableResult
    private func copyColorUnderCursor() -> Bool {
        guard let screen = screens.first(where: { $0.bounds.contains(cursorPoint) }) else {
            return false
        }
        let pixel = CGPoint(
            x: (cursorPoint.x - screen.bounds.minX) * screen.scale,
            y: (cursorPoint.y - screen.bounds.minY) * screen.scale
        )
        guard let color = ImageSampling.color(in: screen.image, atPixel: pixel) else {
            return false
        }
        let hex = ImageSampling.hexString(color)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(hex, forType: .string)
        return true
    }

    private func analyze(_ action: AnalyzeAction) {
        guard !isFinishing else { return }
        isFinishing = true
        guard let image = renderFinalImage(includeAnnotations: true) else {
            isFinishing = false
            return
        }
        dismiss()
        onAnalyze?(image, action)
    }

    private func beginScrollingCapture() {
        guard let selection, let screen = screens.first(where: { $0.bounds.contains(CGPoint(x: selection.midX, y: selection.midY)) }) else {
            return
        }
        isFinishing = true
        dismiss()
        onScroll?(selection, screen.displayID)
    }

    private func applyAIMask() {
        guard let selection, !isFinishing else { return }
        guard let image = renderFinalImage(includeAnnotations: false) else { return }
        VisionAnalyzer.detectFaces(in: image) { [weak self] faces in
            guard let self, !faces.isEmpty else { return }
            for face in faces {
                let topY = 1 - face.maxY
                let global = CGRect(
                    x: selection.minX + face.minX * selection.width,
                    y: selection.minY + topY * selection.height,
                    width: face.width * selection.width,
                    height: face.height * selection.height
                ).insetBy(dx: -selection.width * 0.01, dy: -selection.height * 0.01)
                self.annotations.add(
                    Annotation(
                        kind: .mosaic,
                        start: CGPoint(x: global.minX, y: global.minY),
                        end: CGPoint(x: global.maxX, y: global.maxY),
                        color: .white,
                        lineWidth: 10
                    )
                )
            }
            self.toolbarModel.sync(
                tool: self.activeTool,
                color: self.strokeColor,
                canUndo: self.annotations.canUndo,
                hasSelection: self.selection != nil
            )
            self.redraw()
        }
    }

    // MARK: - Rendering

    func renderFinalImage(includeAnnotations: Bool) -> CGImage? {
        guard let selection else { return nil }
        let selected = selection.intersection(canvasBounds)
        guard selected.width >= 1, selected.height >= 1 else { return nil }

        let involved = screens.filter { $0.bounds.intersects(selected) }
        let outputScale = min(3, max(1, involved.map(\.scale).max() ?? 2))
        let width = max(1, Int((selected.width * outputScale).rounded(.up)))
        let height = max(1, Int((selected.height * outputScale).rounded(.up)))

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        context.setFillColor(NSColor.clear.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        let graphics = NSGraphicsContext(cgContext: context, flipped: true)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics

        for screen in involved {
            let intersection = selected.intersection(screen.bounds)
            guard intersection.width > 0, intersection.height > 0 else { continue }
            let pixelRect = CGRect(
                x: (intersection.minX - screen.bounds.minX) * screen.scale,
                y: (intersection.minY - screen.bounds.minY) * screen.scale,
                width: intersection.width * screen.scale,
                height: intersection.height * screen.scale
            )
            guard let crop = screen.image.cropping(to: pixelRect) else { continue }
            let destination = CGRect(
                x: (intersection.minX - selected.minX) * outputScale,
                y: (intersection.minY - selected.minY) * outputScale,
                width: intersection.width * outputScale,
                height: intersection.height * outputScale
            )
            CGDrawing.drawImage(crop, in: destination, context: context, flipped: true)
        }

        if includeAnnotations {
            AnnotationRenderer.draw(
                annotations: annotations.annotations,
                in: context,
                transform: {
                    CGPoint(
                        x: ($0.x - selected.minX) * outputScale,
                        y: ($0.y - selected.minY) * outputScale
                    )
                },
                lineScale: outputScale,
                sampler: { point in
                    guard let screen = self.screens.first(where: { $0.bounds.contains(point) }) else {
                        return nil
                    }
                    let pixel = CGPoint(
                        x: (point.x - screen.bounds.minX) * screen.scale,
                        y: (point.y - screen.bounds.minY) * screen.scale
                    )
                    return ImageSampling.averageColor(in: screen.image, aroundPixel: pixel, radius: 2)
                }
            )
        }

        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()
    }

    // MARK: - Helpers

    private func windowForPoint(_ point: CGPoint) -> NSWindow? {
        if let index = screens.firstIndex(where: { $0.bounds.contains(point) }) {
            return windows[index]
        }
        return windows.first
    }

    // MARK: - Testing support

    func setSelectionForTesting(_ rect: CGRect) {
        selection = rect
    }

    func addAnnotationForTesting(_ annotation: Annotation) {
        annotations.add(annotation)
    }

    func showToolbarForTesting() {
        showToolbar()
    }
}
