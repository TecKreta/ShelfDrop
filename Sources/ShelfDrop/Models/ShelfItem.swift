import Cocoa

/// シェルフ内の個々のアイテムを表すモデル
struct ShelfItem: Identifiable, Hashable, Codable {
    let id: UUID
    let url: URL
    let name: String
    let fileType: FileType
    let addedDate: Date
    var thumbnailData: Data?
    
    enum CodingKeys: String, CodingKey {
        case id, url, name, fileType, addedDate
    }
    
    enum FileType: String, Hashable, Codable {
        case file
        case folder
        case image
        case text
        case url
        case other
        
        var systemIconName: String {
            switch self {
            case .file: return "doc.fill"
            case .folder: return "folder.fill"
            case .image: return "photo.fill"
            case .text: return "doc.text.fill"
            case .url: return "link"
            case .other: return "questionmark.square.fill"
            }
        }
    }
    
    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent
        self.addedDate = Date()
        self.thumbnailData = nil
        
        // ファイルタイプ判定
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
            if isDir.boolValue {
                self.fileType = .folder
            } else {
                let ext = url.pathExtension.lowercased()
                let imageExts = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp", "svg"]
                let textExts = ["txt", "md", "rtf", "csv", "json", "xml", "html", "css", "js", "swift", "py"]
                if imageExts.contains(ext) {
                    self.fileType = .image
                } else if textExts.contains(ext) {
                    self.fileType = .text
                } else {
                    self.fileType = .file
                }
            }
        } else if url.scheme == "http" || url.scheme == "https" {
            self.fileType = .url
        } else {
            self.fileType = .other
        }
    }
    
    /// テキストスニペットから作成
    init(text: String) {
        self.id = UUID()
        let tempDir = TempFileManager.shared.tempDirectory
        let tempFile = tempDir.appendingPathComponent("snippet_\(UUID().uuidString).txt")
        try? text.write(to: tempFile, atomically: true, encoding: .utf8)
        self.url = tempFile
        self.name = String(text.prefix(30)) + (text.count > 30 ? "..." : "")
        self.fileType = .text
        self.addedDate = Date()
        self.thumbnailData = nil
    }
    
    /// 画像データから作成（ウェブドラッグ/ペースト用）
    init?(image: NSImage, suggestedName: String? = nil) {
        guard let url = TempFileManager.shared.saveImage(image, suggestedName: suggestedName) else {
            return nil
        }
        self.id = UUID()
        self.url = url
        self.name = suggestedName ?? url.lastPathComponent
        self.fileType = .image
        self.addedDate = Date()
        self.thumbnailData = nil
    }
    
    var fileSize: String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? UInt64 else {
            return ""
        }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ShelfItem, rhs: ShelfItem) -> Bool {
        lhs.id == rhs.id
    }
}
