import SwiftUI
import Combine

/// シェルフの状態管理ViewModel
class ShelfViewModel: ObservableObject {
    @Published var shelves: [Shelf] = []
    @Published var activeShelfId: UUID?
    
    static let shared = ShelfViewModel()
    
    private var cancellables = Set<AnyCancellable>()
    
    private var dataURL: URL {
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupportDir.appendingPathComponent(Constants.TempFiles.containerName)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("shelves.json")
    }
    
    private init() {
        loadData()
        
        // 変更があれば自動保存する (短時間の連続変更をまとめるためdebounceを使用)
        self.objectWillChange
            .debounce(for: .seconds(1.0), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveData()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 永続化 (Persistence)
    
    func saveData() {
        do {
            let data = try JSONEncoder().encode(shelves)
            try data.write(to: dataURL, options: [.atomic])
        } catch {
            print("ShelfViewModel: データの保存に失敗しました - \(error)")
        }
    }
    
    func loadData() {
        guard let data = try? Data(contentsOf: dataURL) else { return }
        do {
            let decoded = try JSONDecoder().decode([Shelf].self, from: data)
            self.shelves = decoded
            self.activeShelfId = decoded.last?.id
            
            // 起動直後の空チェック (もし空なら再起動ループにならないように注意)
        } catch {
            print("ShelfViewModel: データの読み込みに失敗しました - \(error)")
        }
    }
    
    // MARK: - メモリ解放のための再起動
    
    /// 全てのシェルフのアイテムが0個になった場合、アプリを再起動して完全にメモリを解放する
    func checkAndRestartIfEmpty() {
        let totalItems = shelves.reduce(0) { $0 + $1.items.count }
        
        if totalItems == 0 {
            print("全てのアイテムが削除されました。メモリ解放のためにアプリを再起動します。")
            
            // 再起動によって強制終了される前に、空になった状態を即座にディスクに保存する
            saveData()
            
            // アプリケーション自体のURLを取得
            let url = Bundle.main.bundleURL
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.createsNewApplicationInstance = true
            
            // 新しいインスタンスとして再起動をリクエストし、自分自身を終了する
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
                DispatchQueue.main.async {
                    NSApp.terminate(nil)
                }
            }
        }
    }
    
    // MARK: - 操作
    
    /// 新しいシェルフを作成
    func createShelf(at position: NSPoint? = nil, type: ShelfType = .file) -> Shelf {
        let typeShelves = shelves.filter { $0.type == type }
        let colorIndex = typeShelves.count % Shelf.availableColors.count
        
        let shelfName = type == .file ? "シェルフ \(typeShelves.count + 1)" : "プロンプト \(typeShelves.count + 1)"
        
        let shelf = Shelf(
            name: shelfName,
            color: Shelf.availableColors[colorIndex],
            type: type
        )
        shelves.append(shelf)
        activeShelfId = shelf.id
        saveData()
        return shelf
    }
    
    /// シェルフを削除
    func removeShelf(withId id: UUID) {
        if let shelf = shelves.first(where: { $0.id == id }) {
            for item in shelf.items {
                ThumbnailGenerator.shared.removeCache(for: item.url)
                TempFileManager.shared.deleteFileIfTemporary(at: item.url)
            }
        }
        shelves.removeAll { $0.id == id }
        if activeShelfId == id {
            activeShelfId = shelves.last?.id
        }
        saveData()
        checkAndRestartIfEmpty()
    }
    
    /// 指定されたタイプのアクティブなシェルフを取得、なければ作成
    func getOrCreateActiveShelf(of type: ShelfType = .file) -> Shelf {
        let matchingShelves = shelves.filter { $0.type == type }
        
        if let activeId = activeShelfId,
           let shelf = matchingShelves.first(where: { $0.id == activeId }) {
            return shelf
        }
        
        if let last = matchingShelves.last {
            // タイプ指定で探して見つかったら、それをアクティブにする
            activeShelfId = last.id
            return last
        }
        
        return createShelf(type: type)
    }
    
    /// URLリストをアクティブなファイルシェルフに追加
    func addURLs(_ urls: [URL]) {
        let shelf = getOrCreateActiveShelf(of: .file)
        let items = urls.map { ShelfItem(url: $0) }
        shelf.addItems(items)
        saveData()
        objectWillChange.send()
    }
    
    /// テキストをアクティブなシェルフに追加（どちらのタイプでも今のフォーカス先へ）
    func addText(_ text: String, to type: ShelfType? = nil) {
        let shelfType = type ?? (shelves.first(where: { $0.id == activeShelfId })?.type ?? .file)
        let shelf = getOrCreateActiveShelf(of: shelfType)
        let item = ShelfItem(text: text)
        shelf.addItem(item)
        saveData()
        objectWillChange.send()
    }
    
    /// すべてのシェルフをクリア
    func clearAll() {
        for shelf in shelves {
            for item in shelf.items {
                TempFileManager.shared.deleteFileIfTemporary(at: item.url)
            }
        }
        shelves.removeAll()
        activeShelfId = nil
        ThumbnailGenerator.shared.clearCache()
        saveData()
        checkAndRestartIfEmpty()
    }
    
    /// 空のシェルフをクリーンアップ
    func cleanupEmptyShelves() {
        let originalCount = shelves.count
        shelves.removeAll { $0.items.isEmpty }
        if let activeId = activeShelfId,
           !shelves.contains(where: { $0.id == activeId }) {
            activeShelfId = shelves.last?.id
        }
        if originalCount != shelves.count {
            saveData()
        }
    }
}
