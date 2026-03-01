import Cocoa

/// 一時画像ファイルの保存・管理・削除を担当するシングルトンサービス
/// 保存先: ~/Library/Application Support/ShelfDrop/TempImages/
class TempFileManager {
    static let shared = TempFileManager()
    
    /// 保存ディレクトリ
    private(set) lazy var tempDirectory: URL = {
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupportDir
            .appendingPathComponent(Constants.TempFiles.containerName)
            .appendingPathComponent(Constants.TempFiles.directoryName)
        
        // ディレクトリがなければ作成
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }()
    
    private init() {}
    
    // MARK: - 画像保存
    
    /// NSImageをPNGファイルとして保存し、保存先URLを返す
    func saveImage(_ image: NSImage, suggestedName: String? = nil) -> URL? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        let fileName = generateFileName(suggestedName: suggestedName)
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        
        do {
            try pngData.write(to: fileURL)
            return fileURL
        } catch {
            print("TempFileManager: 画像保存エラー - \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 画像データ（Data）をファイルとして保存し、保存先URLを返す
    func saveImageData(_ data: Data, suggestedName: String? = nil) -> URL? {
        // データからNSImageを生成して形式を正規化
        guard let image = NSImage(data: data) else { return nil }
        return saveImage(image, suggestedName: suggestedName)
    }
    
    // MARK: - ファイル削除
    
    /// 指定されたURLが一時フォルダ内のファイルであれば、物理的に削除する
    /// - Parameter url: 削除対象のファイルURL
    func deleteFileIfTemporary(at url: URL) {
        // パスがApplication Support/ShelfDrop/TempImages に含まれているか安全確認
        guard url.path.hasPrefix(tempDirectory.path) else {
            return // ローカルからドラッグされたユーザーの本番ファイル等は削除しない
        }
        
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
                // print("一時ファイルを削除しました: \(url.lastPathComponent)")
            }
        } catch {
            print("TempFileManager: 一時ファイルの削除に失敗しました - \(error)")
        }
    }
    
    /// 全一時ファイルを削除
    func clearAllTempFiles() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: tempDirectory,
            includingPropertiesForKeys: nil
        ) else { return }
        
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }
    
    /// 指定日数より古いファイルを削除
    func cleanupExpiredFiles(olderThanDays days: Int) {
        guard days > 0 else { return }
        
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date())!
        
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: tempDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        ) else { return }
        
        for file in files {
            guard let attrs = try? file.resourceValues(forKeys: [.creationDateKey]),
                  let creationDate = attrs.creationDate else { continue }
            
            if creationDate < cutoffDate {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
    
    /// 指定のURLが一時ファイルかどうかを判定
    func isTempFile(_ url: URL) -> Bool {
        return url.path.hasPrefix(tempDirectory.path)
    }
    
    // MARK: - ストレージ情報
    
    /// 一時ファイルの合計サイズを文字列で返す
    var totalStorageUsed: String {
        let bytes = totalStorageBytes
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
    
    /// 一時ファイルの合計バイト数を返す
    var totalStorageBytes: UInt64 {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: tempDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        
        var total: UInt64 = 0
        for file in files {
            if let attrs = try? file.resourceValues(forKeys: [.fileSizeKey]),
               let size = attrs.fileSize {
                total += UInt64(size)
            }
        }
        return total
    }
    
    /// 一時ファイルの数を返す
    var tempFileCount: Int {
        (try? FileManager.default.contentsOfDirectory(
            at: tempDirectory,
            includingPropertiesForKeys: nil
        ))?.count ?? 0
    }
    
    // MARK: - Finder表示
    
    /// 一時ファイルの保存先をFinderで開く
    func revealInFinder() {
        NSWorkspace.shared.open(tempDirectory)
    }
    
    // MARK: - ヘルパー
    
    /// ファイル名生成（image_YYYYMMdd_HHmmss_UUID短縮.png）
    private func generateFileName(suggestedName: String? = nil) -> String {
        if let name = suggestedName, !name.isEmpty {
            // 拡張子がなければ .png を付与
            let url = URL(fileURLWithPath: name)
            let imageExts = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp"]
            if imageExts.contains(url.pathExtension.lowercased()) {
                // 拡張子をpngに統一
                return url.deletingPathExtension().lastPathComponent + ".png"
            }
            return name + ".png"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateStr = formatter.string(from: Date())
        let shortUUID = UUID().uuidString.prefix(6)
        return "image_\(dateStr)_\(shortUUID).png"
    }
}
