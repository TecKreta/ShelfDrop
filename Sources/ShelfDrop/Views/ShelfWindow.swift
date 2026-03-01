import Cocoa
import SwiftUI

/// フローティングシェルフ用のNSPanelサブクラス
/// 他のアプリのフォーカスを奪わずに表示できるパネルウィンドウ
class ShelfPanel: NSPanel {
    
    /// このシェルフが現在ドラッグアウト中かどうか（自分自身への再ドロップ防止用）
    var isDraggingOut: Bool = false
    
    /// ペースト処理用にシェルフとViewModelを保持
    private let shelf: Shelf
    private let viewModel: ShelfViewModel
    
    init(shelf: Shelf, viewModel: ShelfViewModel) {
        self.shelf = shelf
        self.viewModel = viewModel
        
        let contentRect = NSRect(
            x: 0, y: 0,
            width: Constants.ShelfWindow.defaultWidth,
            height: Constants.ShelfWindow.defaultHeight
        )
        
        super.init(
            contentRect: contentRect,
            // タイトルバーなし、ボーダレスパネル
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        
        // パネルの設定
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        // タイトルバー完全非表示
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false
        self.hasShadow = true
        self.becomesKeyOnlyIfNeeded = true
        self.animationBehavior = .utilityWindow
        
        // 標準ボタン（赤/黄/緑）を非表示
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        
        // SwiftUI コンテンツを設定 (シェルフのタイプに応じて切り替え)
        let hostingView: NSHostingView<AnyView>
        if shelf.type == .prompt {
            let promptView = PromptShelfView(shelf: shelf, viewModel: viewModel, panel: self) {
                self.closeShelf()
            }
            hostingView = NSHostingView(rootView: AnyView(promptView))
        } else {
            let contentView = ShelfContentView(shelf: shelf, viewModel: viewModel, panel: self) {
                self.closeShelf()
            }
            hostingView = NSHostingView(rootView: AnyView(contentView))
        }
        self.contentView = hostingView
        
        // ドラッグ受け入れ設定
        self.contentView?.registerForDraggedTypes([
            .fileURL,
            .string,
            .URL,
            .tiff,
            .png
        ])
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    
    // MARK: - キーボードイベント
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // ⌘V を検出
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "v" {
            handlePasteFromClipboard()
            return true
        }
        
        return super.performKeyEquivalent(with: event)
    }
    
    /// NSPasteboardから直接画像/ファイルを読み取ってシェルフに追加
    private func handlePasteFromClipboard() {
        let pasteboard = NSPasteboard.general
        
        // 1. 画像データを確認
        if let image = NSImage(pasteboard: pasteboard) {
            if let item = ShelfItem(image: image) {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.shelf.addItem(item)
                    self.viewModel.objectWillChange.send()
                }
            }
            return
        }
        
        // 2. ファイルURLを確認
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], !urls.isEmpty {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                for url in urls {
                    if !self.shelf.items.contains(where: { $0.url == url }) {
                        let item = ShelfItem(url: url)
                        self.shelf.addItem(item)
                    }
                }
                self.viewModel.objectWillChange.send()
            }
            return
        }
        
        // 3. テキストまたはWeb URLを確認
        if let text = pasteboard.string(forType: .string) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // URLとして解析可能かチェック (http/https)
                if let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
                   let scheme = url.scheme, (scheme == "http" || scheme == "https") {
                    if !self.shelf.items.contains(where: { $0.url == url }) {
                        let item = ShelfItem(url: url)
                        self.shelf.addItem(item)
                    }
                } else {
                    // 通常のテキスト
                    let item = ShelfItem(text: text)
                    self.shelf.addItem(item)
                }
                self.viewModel.objectWillChange.send()
            }
            return
        }
    }
    
    // MARK: - ウィンドウドラッグの手動制御
    
    override func mouseDown(with event: NSEvent) {
        // クリックされたらキーウィンドウにしてキーボードイベントを受け取れるようにする
        self.makeKey()
        
        let location = event.locationInWindow
        
        // contentView内のhitTestで判定
        if let contentView = contentView,
           let hitView = contentView.hitTest(location),
           isInteractiveView(hitView) {
            // インタラクティブなビュー → クリックを通す
            super.mouseDown(with: event)
            return
        }
        
        // それ以外 → ウィンドウドラッグを開始
        performDrag(with: event)
    }
    
    /// クリック対象がインタラクティブなビューかどうか判定
    private func isInteractiveView(_ view: NSView) -> Bool {
        var current: NSView? = view
        while let v = current {
            if v is NSButton { return true }
            if v is NSTextField { return true }
            if let accessRole = v.accessibilityRole(),
               accessRole == .button || accessRole == .popUpButton || accessRole == .menuButton {
                return true
            }
            current = v.superview
        }
        return false
    }
    
    func showAtPosition(_ position: NSPoint) {
        let frame = NSRect(
            x: position.x - Constants.ShelfWindow.defaultWidth / 2,
            y: position.y - Constants.ShelfWindow.defaultHeight / 2,
            width: Constants.ShelfWindow.defaultWidth,
            height: Constants.ShelfWindow.defaultHeight
        )
        self.setFrame(frame, display: true)
        self.makeKeyAndOrderFront(nil)
        
        // フェードインアニメーション
        self.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Constants.Animation.shelfAppearDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1.0
        }
    }
    
    func closeShelf() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Constants.Animation.shelfDismissDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.close()
        })
    }
}
