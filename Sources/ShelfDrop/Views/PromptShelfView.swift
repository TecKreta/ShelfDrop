import SwiftUI
import AppKit

struct PromptShelfView: View {
    @ObservedObject var shelf: Shelf
    @ObservedObject var viewModel: ShelfViewModel
    weak var panel: ShelfPanel?
    var onClose: () -> Void
    
    @State private var hoveredItemId: UUID? = nil
    @State private var pulseAnimation = false
    @State private var rainbowRotation = 0.0
    @State private var isFocused = false
    @State private var isDragTargeted = false

    
    var body: some View {
        ZStack {
            // 背景素材
            Color(NSColor.windowBackgroundColor).opacity(0.85)
            RoundedRectangle(cornerRadius: Constants.ShelfWindow.cornerRadius)
                .fill(.ultraThinMaterial)
            
            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    Image(systemName: "text.bubble.fill")
                        .foregroundColor(shelf.color)
                        .font(.system(size: 14))
                    
                    Text(shelf.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Spacer()
                    

                    
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.3))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.leading, 4)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.2))
                
                Divider().background(Color.white.opacity(0.1))
                
                // プロンプトのリスト
                if shelf.items.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.2))
                        Text("プロンプトをドロップ、または⌘V")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(shelf.items.reversed()) { item in
                                PromptItemRow(
                                    item: item,
                                    isHovered: hoveredItemId == item.id,
                                    onDelete: {
                                        deleteItem(item)
                                    },
                                    onCopy: {
                                        copyOnly(item: item)
                                    },
                                    onAutoPaste: {
                                        copyAndPaste(item: item)
                                    }
                                )
                                .onHover { isHovering in
                                    if isHovering {
                                        hoveredItemId = item.id
                                    } else if hoveredItemId == item.id {
                                        hoveredItemId = nil
                                    }
                                }
                            }
                        }
                        .padding(12)
                    }
                }
            }
        }
        .frame(width: Constants.ShelfWindow.defaultWidth, height: Constants.ShelfWindow.defaultHeight)
        // 枠線の装飾 (ShelfContentViewと同じレインボーボーダー)
        .overlay(
            RoundedRectangle(cornerRadius: Constants.ShelfWindow.cornerRadius)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                .overlay(
                    Group {
                        if isFocused {
                            let rainbowColors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .red]
                            RoundedRectangle(cornerRadius: Constants.ShelfWindow.cornerRadius)
                                .stroke(
                                    AngularGradient(
                                        gradient: Gradient(colors: rainbowColors),
                                        center: .center,
                                        angle: .degrees(rainbowRotation)
                                    ),
                                    lineWidth: 2
                                )
                                .shadow(color: shelf.color.opacity(pulseAnimation ? 0.6 : 0.2), radius: 5)
                        } else {
                            RoundedRectangle(cornerRadius: Constants.ShelfWindow.cornerRadius)
                                .stroke(
                                    isDragTargeted ? shelf.color.opacity(0.9) : Color.clear,
                                    lineWidth: isDragTargeted ? 2 : 1
                                )
                        }
                    }
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: Constants.ShelfWindow.cornerRadius))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 8)

        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            if let window = notification.object as? NSWindow, window === panel {
                withAnimation { isFocused = true }
                withAnimation(Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
                withAnimation(Animation.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                    rainbowRotation = 360.0
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { notification in
            if let window = notification.object as? NSWindow, window === panel {
                withAnimation { isFocused = false }
                withAnimation { pulseAnimation = false }
            }
        }
        // テキストのドロップを受け入れる
        .onDrop(of: [.plainText, .text, .url, .fileURL], isTargeted: $isDragTargeted) { providers in
            if panel?.isDraggingOut == true { return false }
            return handleDrop(providers)
        }
    }
    
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.text") || provider.hasItemConformingToTypeIdentifier("public.string") {
                provider.loadItem(forTypeIdentifier: "public.text", options: nil) { (item, error) in
                    if let string = item as? String {
                        DispatchQueue.main.async {
                            viewModel.addText(string, to: .prompt)
                        }
                    } else if let data = item as? Data, let string = String(data: data, encoding: .utf8) {
                        DispatchQueue.main.async {
                            viewModel.addText(string, to: .prompt)
                        }
                    }
                }
                handled = true
            }
        }
        return handled
    }
    private func deleteItem(_ item: ShelfItem) {
        shelf.removeItem(withId: item.id)
        viewModel.saveData()
        viewModel.objectWillChange.send()
        
        // Remove thumbnail and temp file if applicable
        ThumbnailGenerator.shared.removeCache(for: item.url)
        TempFileManager.shared.deleteFileIfTemporary(at: item.url)
        
        let haptic = NSHapticFeedbackManager.defaultPerformer
        haptic.perform(.generic, performanceTime: .default)
    }
    
    private func copyOnly(item: ShelfItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        if item.fileType == .text, let text = try? String(contentsOf: item.url) {
            pasteboard.setString(text, forType: .string)
        } else {
            pasteboard.writeObjects([item.url as NSURL])
        }
        
        let haptic = NSHapticFeedbackManager.defaultPerformer
        haptic.perform(.generic, performanceTime: .default)
        
        if let activeId = viewModel.activeShelfId, let delegate = AppDelegate.shared {
            delegate.minimizeShelf(activeId)
        }
    }
    
    // コピーして、自動的に手前のウィンドウへペーストコマンド(Cmd+V)を送信する
    private func copyAndPaste(item: ShelfItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        // テキストファイルなら中身をコピー、それ以外はファイルをコピー
        if item.fileType == .text, let text = try? String(contentsOf: item.url) {
            pasteboard.setString(text, forType: .string)
        } else {
            pasteboard.writeObjects([item.url as NSURL])
        }
        
        let haptic = NSHapticFeedbackManager.defaultPerformer
        haptic.perform(.generic, performanceTime: .default)
        
        // 【重要】Macで自動キー入力(Cmd+V)を行うには「アクセシビリティ」権限が必須です。
        // ここで権限をチェックし、無ければmacOS標準の許可を求めるダイアログを表示させます。
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessEnabled {
            // 権限がない場合は警告音を鳴らして、ただの「コピー」として扱います。
            // ユーザーにはシステム設定ダイアログが表示されます。
            NSSound.beep()
            return
        }
        
        // まずすべてのシェルフパネルを隠し、アプリ自体を非表示にして
        // 前のアプリにフォーカスを確実に戻す
        if let activeId = viewModel.activeShelfId {
            if let delegate = AppDelegate.shared {
                delegate.minimizeShelf(activeId)
            }
        }
        
        // NSApp.hide で ShelfDrop 自体を隠す → 前のアプリがアクティブになる
        NSApp.hide(nil)
        
        // CGEventを使って安全にCmd+Vを送信（AppleScriptよりも確実）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Cmd+V のキーダウン ('v' のキーコードは 9)
            let source = CGEventSource(stateID: .hidSystemState)
            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true) {
                keyDown.flags = .maskCommand
                keyDown.post(tap: .cghidEventTap)
            }
            // Cmd+V のキーアップ
            if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) {
                keyUp.flags = .maskCommand
                keyUp.post(tap: .cghidEventTap)
            }
        }
    }
}

struct PromptItemRow: View {
    let item: ShelfItem
    let isHovered: Bool
    var onDelete: () -> Void
    var onCopy: () -> Void
    var onAutoPaste: () -> Void
    
    @State private var showPopover = false
    @State private var hoverDate: Date? = nil
    @State private var dismissTimer: DispatchWorkItem? = nil
    @State private var isPopoverHovered = false
    
    // 中身をプレビュー用に読み込むプロパティ
    private var previewText: String {
        if item.fileType == .text, let text = try? String(contentsOf: item.url) {
            return text
        }
        return item.name
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // アイコン
            Image(systemName: "quote.opening")
                .foregroundColor(.white.opacity(0.6))
                .font(.system(size: 14))
                .padding(.top, 2)
            
            // テキストプレビュー
            Text(previewText)
                .lineLimit(3)
                .truncationMode(.tail)
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // アクションボタン
            if isHovered {
                HStack(spacing: 8) {
                    // 削除
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("削除")
                    
                    // コピーのみ
                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("コピー")
                    
                    // コピー＆ペースト
                    Button(action: onAutoPaste) {
                        Image(systemName: "arrow.right.doc.on.clipboard")
                            .foregroundColor(Color(NSColor.controlAccentColor))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("自動ペースト")
                }
                .transition(.opacity)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.black.opacity(0.8) : Color.black.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? Color.white.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.1), value: isHovered)
        // ホバーで長文ポップアップ（カーソルを右にスライドしても消えないよう遅延dismiss）
        .onHover { hovering in
            if hovering {
                // カーソルが入ったら消去タイマーを止める
                dismissTimer?.cancel()
                dismissTimer = nil
                // 0.6秒後に表示開始
                hoverDate = Date()
                let workItem = DispatchWorkItem {
                    if let date = hoverDate, Date().timeIntervalSince(date) >= 0.5 {
                        showPopover = true
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: workItem)
            } else {
                hoverDate = nil
                // 少し遅延させてから消す（ポップオーバーにカーソルが移動する時間を与える）
                let workItem = DispatchWorkItem {
                    if !isPopoverHovered {
                        showPopover = false
                    }
                }
                dismissTimer = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: workItem)
            }
        }
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            ScrollView(.vertical, showsIndicators: true) {
                Text(previewText)
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .lineSpacing(4)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
            }
            .frame(width: 450, height: 400)
            .onHover { hovering in
                isPopoverHovered = hovering
                if !hovering {
                    // ポップオーバーからカーソルが外れたら遅延消去
                    let workItem = DispatchWorkItem {
                        showPopover = false
                    }
                    dismissTimer = workItem
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
                } else {
                    // ポップオーバーにいる間はキャンセル
                    dismissTimer?.cancel()
                    dismissTimer = nil
                }
            }
        }
    }
}
