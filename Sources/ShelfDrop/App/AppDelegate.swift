import Cocoa
import ShelfDropCore
import SwiftUI

/// アプリケーションデリゲート
/// メニューバー常駐、シェルフウィンドウ管理、グローバルイベント監視を担当
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var shelfPanels: [UUID: ShelfPanel] = [:]
    let viewModel = ShelfViewModel.shared
    private var cursorShakeDetector: CursorShakeDetector?
    private var eventMonitor: Any?
    private var dragRightClickMonitor: Any?
    
    /// AppDelegate のシングルトン参照
    static weak var shared: AppDelegate?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        
        // Dockアイコンを非表示
        NSApp.setActivationPolicy(.accessory)
        
        // メニューバーアイテムの設定
        setupStatusItem()
        
        // ポップオーバーの設定
        setupPopover()
        
        // カーソルシェイク検出の設定
        setupCursorShakeDetector()
        
        // ポップオーバー外クリック監視
        setupEventMonitor()
        
        // 起動時に期限切れ一時ファイルのクリーンアップを実行
        SettingsManager.shared.performAutoCleanupIfNeeded()
    }
    
    // MARK: - セットアップ
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: Constants.MenuBar.iconName, accessibilityDescription: "ShelfDrop")
            button.image?.size = NSSize(width: 18, height: 18)
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
        }
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(
            width: Constants.MenuBar.popoverWidth,
            height: Constants.MenuBar.popoverHeight
        )
        popover.behavior = .transient
        popover.animates = true
        updatePopoverContent()
    }
    
    private func updatePopoverContent() {
        let menuBarView = MenuBarView(
            viewModel: viewModel,
            onCreateShelf: { [weak self] type in
                self?.popover.performClose(nil)
                self?.createAndShowShelf(type: type)
            },
            onShowShelf: { [weak self] shelfId in
                self?.popover.performClose(nil)
                self?.showExistingShelf(shelfId)
            },
            onDeleteShelf: { [weak self] shelfId in
                self?.deleteShelf(shelfId)
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
        popover.contentViewController = NSHostingController(rootView: menuBarView)
    }
    
    private func setupCursorShakeDetector() {
        cursorShakeDetector = CursorShakeDetector { [weak self] in
            self?.shakeTriggered()
        }
        cursorShakeDetector?.startMonitoring()
    }
    
    /// シェイクで呼ばれた時: 既存シェルフがあれば表示/移動、なければ1つ作成
    private func shakeTriggered(forceType: ShelfType? = nil) {
        let mouseLocation = NSEvent.mouseLocation
        
        let targetType = forceType ?? .file
        
        // アクティブなIDを探す際、指定タイプに合うものを優先する
        let matchingShelves = viewModel.shelves.filter { $0.type == targetType }
        var targetIdToShow: UUID? = nil
        
        if let activeId = viewModel.activeShelfId,
           let activeShelf = matchingShelves.first(where: { $0.id == activeId }) {
            targetIdToShow = activeShelf.id
        } else if let lastMatching = matchingShelves.last {
            targetIdToShow = lastMatching.id
        }
        
        if let idToShow = targetIdToShow {
            // 表示中のパネルがあればカーソル位置に移動
            if let panel = shelfPanels[idToShow], panel.isVisible {
                panel.showAtPosition(mouseLocation)
                return
            }
            // 格納中なら再表示
            showExistingShelf(idToShow)
            return
        }
        
        // 目当てのタイプのシェルフがなければ1つだけ作成
        let newShelf = viewModel.createShelf(type: targetType)
        showShelfPanel(for: newShelf)
    }
    
    private var dragShiftMonitor: Any?
    
    // Shiftトリプルタップ検知用 (ファイルシェルフ)
    private var shiftTapDetector = KeyTapDetector(requiredTapCount: 3, minimumInterval: 0.04, maximumInterval: 0.25)
    private var shiftTripleTapGlobalMonitor: Any?
    private var shiftTripleTapLocalMonitor: Any?
    
    // Controlトリプルタップ検知用 (プロンプトシェルフ)
    private var controlTapDetector = KeyTapDetector(requiredTapCount: 3, minimumInterval: 0.04, maximumInterval: 0.25)
    private var controlTripleTapGlobalMonitor: Any?
    private var controlTripleTapLocalMonitor: Any?
    
    // MARK: - イベント監視
    
    private func setupEventMonitor() {
        // ポップオーバー外クリックで閉じる
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
            }
        }
        
        // ドラッグ中の右クリックでシェルフ表示
        dragRightClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.rightMouseDown]) { [weak self] event in
            // ポップオーバーが開いていたら閉じるだけ
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
                return
            }
            
            // 左ボタンが押されている = ドラッグ中
            let leftButtonDown = NSEvent.pressedMouseButtons & 1 != 0
            if leftButtonDown {
                self?.shakeTriggered()
            }
        }
        
        // トラックパッド用：ドラッグ中のShiftキー押下でシェルフ表示
        dragShiftMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            // Shiftキーが押されたかチェック
            let isShiftPressed = event.modifierFlags.contains(.shift)
            guard isShiftPressed else { return }
            
            // ポップオーバーが開いていたら何もしない
            if let popover = self?.popover, popover.isShown {
                return
            }
            
            // 左ボタンが押されている = ドラッグ中
            let leftButtonDown = NSEvent.pressedMouseButtons & 1 != 0
            if leftButtonDown {
                self?.shakeTriggered()
            }
        }
        
        // Shiftキーのトリプルタップ検知（グローバル）
        shiftTripleTapGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handlePossibleShiftTripleTap(event)
        }
        
        // Shiftキーのトリプルタップ検知（ローカル: アプリにフォーカスがある時）
        shiftTripleTapLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handlePossibleShiftTripleTap(event)
            return event
        }
        
        // Controlキーのトリプルタップ検知（グローバル）
        controlTripleTapGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handlePossibleControlTripleTap(event)
        }
        
        // Controlキーのトリプルタップ検知（ローカル）
        controlTripleTapLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handlePossibleControlTripleTap(event)
            return event
        }
    }
    
    private func handlePossibleShiftTripleTap(_ event: NSEvent) {
        let isOnlyShiftPressed = event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .shift
        guard isOnlyShiftPressed else {
            shiftTapDetector.reset()
            return
        }

        let currentTime = Date().timeIntervalSinceReferenceDate
        if shiftTapDetector.registerTap(at: currentTime) {
            DispatchQueue.main.async { [weak self] in
                self?.toggleActiveUI(for: .file)
            }
        }
    }
    
    private func handlePossibleControlTripleTap(_ event: NSEvent) {
        // Controlのみが押されたか判定
        let isOnlyControlPressed = event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .control
        guard isOnlyControlPressed else {
            controlTapDetector.reset()
            return
        }

        let currentTime = Date().timeIntervalSinceReferenceDate
        if controlTapDetector.registerTap(at: currentTime) {
            DispatchQueue.main.async { [weak self] in
                self?.toggleActiveUI(for: .prompt)
            }
        }
    }
    
    // 開いているUIを閉じるか、何も開いていなければ指定タイプのシェルフを呼び出す
    private func toggleActiveUI(for targetType: ShelfType) {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        
        if let activeId = viewModel.activeShelfId,
           let panel = shelfPanels[activeId],
           panel.isVisible && panel.alphaValue > 0.01 {
            let activeShelf = viewModel.shelves.first(where: { $0.id == activeId })
            
            if activeShelf?.type == targetType {
                // 同じタイプなら閉じる（トグルオフ）
                minimizeShelf(activeId)
            } else {
                // 違うタイプなら現在のものを閉じて新しいものを開く
                minimizeShelf(activeId)
                let targetShelf = viewModel.getOrCreateActiveShelf(of: targetType)
                showExistingShelf(targetShelf.id)
            }
            return
        }
        
        // 何も開いていない（または隠れている）場合は対象のシェルフを呼び出す
        shakeTriggered(forceType: targetType)
    }
    

    
    // MARK: - アクション
    
    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            updatePopoverContent()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    /// 新しいシェルフを作成して表示
    @discardableResult
    func createAndShowShelf(type: ShelfType = .file) -> Shelf {
        let shelf = viewModel.createShelf(type: type)
        showShelfPanel(for: shelf)
        return shelf
    }
    
    /// 既存のシェルフを再表示
    func showExistingShelf(_ shelfId: UUID) {
        guard let shelf = viewModel.shelves.first(where: { $0.id == shelfId }) else { return }
        viewModel.activeShelfId = shelfId
        
        if let panel = shelfPanels[shelfId] {
            // 既存パネルを再表示
            let mouseLocation = NSEvent.mouseLocation
            panel.showAtPosition(mouseLocation)
        } else {
            // パネルが閉じられていた場合は新たに作成
            showShelfPanel(for: shelf)
        }
    }
    
    /// インプレースで別のシェルフに切り替える
    func switchShelf(from oldId: UUID, to newId: UUID) {
        guard let newShelf = viewModel.shelves.first(where: { $0.id == newId }), oldId != newId else { return }
        
        var targetFrame: NSRect? = nil
        let wasKey = shelfPanels[oldId]?.isKeyWindow ?? false
        
        if let oldPanel = shelfPanels[oldId] {
            targetFrame = oldPanel.frame
            oldPanel.close()
            shelfPanels.removeValue(forKey: oldId)
        }
        
        viewModel.activeShelfId = newId
        
        let panel = ShelfPanel(shelf: newShelf, viewModel: viewModel)
        shelfPanels[newId] = panel
        
        if let frame = targetFrame {
            panel.setFrame(frame, display: true)
        } else {
            panel.setFrameOrigin(NSEvent.mouseLocation)
        }
        
        panel.alphaValue = 1.0
        panel.orderFront(nil)
        if wasKey {
            panel.makeKey()
        }
        
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.shelfPanels.removeValue(forKey: newId)
        }
    }
    
    /// シェルフをメニューバーに格納（非表示にするが削除はしない）
    func minimizeShelf(_ shelfId: UUID) {
        if let panel = shelfPanels[shelfId] {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = Constants.Animation.shelfDismissDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil)
            })
        }
    }
    
    /// シェルフを完全に削除
    func deleteShelf(_ shelfId: UUID) {
        if let panel = shelfPanels[shelfId] {
            panel.close()
        }
        shelfPanels.removeValue(forKey: shelfId)
        viewModel.removeShelf(withId: shelfId)
    }
    
    /// シェルフパネルを表示
    private func showShelfPanel(for shelf: Shelf) {
        let panel = ShelfPanel(shelf: shelf, viewModel: viewModel)
        shelfPanels[shelf.id] = panel
        
        // カーソル位置にシェルフを表示
        let mouseLocation = NSEvent.mouseLocation
        panel.showAtPosition(mouseLocation)
        
        // パネルが閉じられた時のクリーンアップ（パネルの参照だけ削除）
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.shelfPanels.removeValue(forKey: shelf.id)
        }
    }
    
    // MARK: - ライフサイクル
    
    func applicationWillTerminate(_ notification: Notification) {
        cursorShakeDetector?.stopMonitoring()
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        if let dragRightClickMonitor = dragRightClickMonitor {
            NSEvent.removeMonitor(dragRightClickMonitor)
        }
        if let dragShiftMonitor = dragShiftMonitor {
            NSEvent.removeMonitor(dragShiftMonitor)
        }
        if let globalShift = shiftTripleTapGlobalMonitor {
            NSEvent.removeMonitor(globalShift)
        }
        if let localShift = shiftTripleTapLocalMonitor {
            NSEvent.removeMonitor(localShift)
        }
        if let globalControl = controlTripleTapGlobalMonitor {
            NSEvent.removeMonitor(globalControl)
        }
        if let localControl = controlTripleTapLocalMonitor {
            NSEvent.removeMonitor(localControl)
        }
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
