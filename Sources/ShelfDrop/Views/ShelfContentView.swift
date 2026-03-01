import SwiftUI
import UniformTypeIdentifiers

/// シェルフ内のコンテンツを表示するSwiftUIビュー
struct ShelfContentView: View {
    @ObservedObject var shelf: Shelf
    @ObservedObject var viewModel: ShelfViewModel
    weak var panel: ShelfPanel?
    var onClose: () -> Void
    
    @State private var isHoveringClose = false
    @State private var isDragTargeted = false
    @State private var isEditingName = false
    @State private var isFocused = false
    @State private var pulseAnimation = false
    @State private var rainbowRotation: Double = 0.0
    
    // ゲーミング風のレインボーグラデーション
    private let rainbowColors: [Color] = [
        .red, .orange, .yellow, .green, .blue, .purple, .red
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            headerView
            
            Divider()
                .opacity(0.3)
            
            // コンテンツ
            if shelf.items.isEmpty {
                emptyStateView
            } else {
                itemsGridView
            }
            
            // フッター
            if !shelf.items.isEmpty {
                footerView
            }
        }
        .frame(minWidth: 200, maxWidth: 500, minHeight: 120, maxHeight: 400)
        .background(
            RoundedRectangle(cornerRadius: Constants.ShelfWindow.cornerRadius)
                .fill(.ultraThinMaterial)
                .overlay(
                    Group {
                        if isFocused {
                            // フォーカス時：回転するレインボーボーダー
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
                            // 非フォーカス時 / ドラッグターゲット時
                            RoundedRectangle(cornerRadius: Constants.ShelfWindow.cornerRadius)
                                .stroke(
                                    isDragTargeted ? shelf.color.opacity(0.9) : Color.white.opacity(0.15),
                                    lineWidth: isDragTargeted ? 2 : 1
                                )
                        }
                    }
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: Constants.ShelfWindow.cornerRadius))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 5)
        .onDrop(of: [.fileURL, .url, .text, .image, .png, .tiff], isTargeted: $isDragTargeted) { providers in
            // 自分自身からのドラッグアウト中は受け入れない
            if panel?.isDraggingOut == true {
                return false
            }
            return handleDrop(providers)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            if let window = notification.object as? NSWindow, window === panel {
                withAnimation { isFocused = true }
                
                // パルスアニメーション (影用)
                withAnimation(Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
                
                // レインボー回転アニメーション
                withAnimation(Animation.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                    rainbowRotation = 360.0
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { notification in
            if let window = notification.object as? NSWindow, window === panel {
                withAnimation { isFocused = false }
                withAnimation { 
                    pulseAnimation = false
                    rainbowRotation = 0.0
                }
            }
        }
    }
    
    // MARK: - ヘッダー
    @State private var isHoveringMinimize = false
    
    private var headerView: some View {
        HStack(spacing: 8) {
            // バツボタン（シェルフを削除）
            Button(action: {
                AppDelegate.shared?.deleteShelf(shelf.id)
            }) {
                Circle()
                    .fill(isHoveringClose ? Color.red : Color.red.opacity(0.7))
                    .frame(width: 12, height: 12)
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(isHoveringClose ? .white : .clear)
                    )
            }
            .buttonStyle(.plain)
            .onHover { isHoveringClose = $0 }
            .help("シェルフを削除")
            
            // カラーインジケーター
            Circle()
                .fill(shelf.color)
                .frame(width: 10, height: 10)
            
            // シェルフ名
            if isEditingName {
                TextField("名前", text: $shelf.name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .onSubmit { isEditingName = false }
            } else {
                Text(shelf.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .onTapGesture(count: 2) { isEditingName = true }
            }
            
            // アイテム数バッジ
            if !shelf.items.isEmpty {
                Text("\(shelf.items.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(shelf.color))
            }
            
            Spacer()
            

            
            // シェルフ切り替えメニュー
            Menu {
                ForEach(viewModel.shelves) { s in
                    Button {
                        AppDelegate.shared?.switchShelf(from: shelf.id, to: s.id)
                    } label: {
                        HStack {
                            Text(s.name)
                            if s.id == shelf.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("シェルフを切り替え")
            
            // メニューバーに格納ボタン
            Button(action: {
                AppDelegate.shared?.minimizeShelf(shelf.id)
            }) {
                Image(systemName: "chevron.down.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(isHoveringMinimize ? .primary : .secondary)
            }
            .buttonStyle(.plain)
            .onHover { isHoveringMinimize = $0 }
            .help("メニューバーに格納")
        }
        .padding(.horizontal, Constants.ShelfWindow.padding)
        .padding(.vertical, 8)
    }
    
    // MARK: - 空の状態
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("ここにファイルをドロップ")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Constants.ShelfWindow.padding)
    }
    
    // MARK: - アイテムグリッド
    private var itemsGridView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Constants.ShelfWindow.itemSpacing) {
                ForEach(shelf.items) { item in
                    ShelfItemView(item: item, panel: panel) {
                        withAnimation(.easeOut(duration: Constants.Animation.itemAddDuration)) {
                            shelf.removeItem(withId: item.id)
                            viewModel.objectWillChange.send()
                            viewModel.checkAndRestartIfEmpty()
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(Constants.ShelfWindow.padding)
        }
        .frame(maxHeight: Constants.ShelfWindow.itemSize + 40)
    }
    
    // MARK: - フッター
    private var footerView: some View {
        HStack(spacing: 12) {
            Text(shelf.totalSize)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            // Finder で表示
            Button(action: revealInFinder) {
                Image(systemName: "folder")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Finderで表示")
            
            // 共有
            Button(action: shareItems) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("共有")
            
            // すべて削除
            Button(action: {
                withAnimation {
                    for item in shelf.items {
                        ThumbnailGenerator.shared.removeCache(for: item.url)
                        TempFileManager.shared.deleteFileIfTemporary(at: item.url)
                    }
                    shelf.items.removeAll()
                    viewModel.objectWillChange.send()
                    viewModel.checkAndRestartIfEmpty()
                }
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("すべて削除")
        }
        .padding(.horizontal, Constants.ShelfWindow.padding)
        .padding(.vertical, 6)
    }
    
    // MARK: - ドロップ処理
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        
        for provider in providers {
            // 画像データ（ウェブブラウザからの直接ドラッグ — 最優先）
            // ブラウザはfile-urlとimageの両方を持つ場合があるので、imageを先にチェック
            if provider.hasItemConformingToTypeIdentifier("public.image") &&
               !provider.hasItemConformingToTypeIdentifier("public.file-url") {
                loadImageFromProvider(provider)
                handled = true
            }
            // ファイルURL（ローカルファイル、またはブラウザからのファイルURL付き画像）
            else if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, error in
                    var resolvedURL: URL?
                    
                    // Dataとして受け取る場合
                    if let data = data as? Data {
                        resolvedURL = URL(dataRepresentation: data, relativeTo: nil)
                    }
                    // URLとして直接受け取る場合
                    else if let url = data as? URL {
                        resolvedURL = url
                    }
                    
                    guard let url = resolvedURL else { return }
                    
                    DispatchQueue.main.async { [self] in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if !shelf.items.contains(where: { $0.url == url }) {
                                let item = ShelfItem(url: url)
                                shelf.addItem(item)
                                viewModel.objectWillChange.send()
                            }
                        }
                    }
                }
                handled = true
            }
            // URL（ウェブ上の画像URLなど）
            else if provider.hasItemConformingToTypeIdentifier("public.url") {
                provider.loadItem(forTypeIdentifier: "public.url", options: nil) { data, error in
                    var resolvedURL: URL?
                    if let data = data as? Data {
                        resolvedURL = URL(dataRepresentation: data, relativeTo: nil)
                    } else if let url = data as? URL {
                        resolvedURL = url
                    }
                    
                    guard let url = resolvedURL,
                          let scheme = url.scheme,
                          (scheme == "http" || scheme == "https") else { return }
                    
                    // 画像URLならダウンロードして保存
                    self.downloadAndAddImage(from: url, provider: provider)
                }
                handled = true
            }
            // テキスト
            else if provider.hasItemConformingToTypeIdentifier("public.text") {
                provider.loadItem(forTypeIdentifier: "public.text", options: nil) { data, error in
                    guard let data = data as? Data,
                          let text = String(data: data, encoding: .utf8) else { return }
                    DispatchQueue.main.async { [self] in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            let item = ShelfItem(text: text)
                            shelf.addItem(item)
                            viewModel.objectWillChange.send()
                        }
                    }
                }
                handled = true
            }
        }
        
        return handled
    }
    
    // MARK: - 画像読み込みヘルパー
    
    /// NSItemProviderから画像データを複数の方法で読み込む
    private func loadImageFromProvider(_ provider: NSItemProvider) {
        // まずTIFF（macOSネイティブ形式）を試す
        let types = ["public.tiff", "public.png", "public.image"]
        
        for type in types {
            if provider.hasItemConformingToTypeIdentifier(type) {
                provider.loadItem(forTypeIdentifier: type, options: nil) { [self] data, error in
                    var image: NSImage?
                    
                    // Data として受け取る
                    if let data = data as? Data {
                        image = NSImage(data: data)
                    }
                    // URL（一時ファイル）として受け取る
                    else if let url = data as? URL {
                        image = NSImage(contentsOf: url)
                    }
                    // NSImage として直接受け取る
                    else if let nsImage = data as? NSImage {
                        image = nsImage
                    }
                    
                    guard let image = image else { return }
                    
                    let name = provider.suggestedName
                    DispatchQueue.main.async {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if let item = ShelfItem(image: image, suggestedName: name) {
                                self.shelf.addItem(item)
                                self.viewModel.objectWillChange.send()
                            }
                        }
                    }
                }
                return // 最初に成功した形式で終了
            }
        }
    }
    
    /// URLから画像をダウンロードしてシェルフに追加
    private func downloadAndAddImage(from url: URL, provider: NSItemProvider) {
        let imageExts = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp", "svg"]
        let ext = url.pathExtension.lowercased()
        
        // 画像らしいURLの場合のみダウンロード
        guard imageExts.contains(ext) || url.absoluteString.contains("image") else {
            // 画像URLでなければ通常のURLとして追加
            DispatchQueue.main.async { [self] in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    let item = ShelfItem(url: url)
                    shelf.addItem(item)
                    viewModel.objectWillChange.send()
                }
            }
            return
        }
        
        // 画像をダウンロード
        URLSession.shared.dataTask(with: url) { [self] data, response, error in
            guard let data = data, let image = NSImage(data: data) else { return }
            
            let name = provider.suggestedName ?? url.deletingPathExtension().lastPathComponent
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if let item = ShelfItem(image: image, suggestedName: name) {
                        self.shelf.addItem(item)
                        self.viewModel.objectWillChange.send()
                    }
                }
            }
        }.resume()
    }
    
    // MARK: - アクション
    private func revealInFinder() {
        let urls = shelf.items.map { $0.url }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }
    
    private func shareItems() {
        let urls = shelf.items.map { $0.url }
        guard let contentView = NSApp.keyWindow?.contentView else { return }
        let picker = NSSharingServicePicker(items: urls)
        picker.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .minY)
    }
}

