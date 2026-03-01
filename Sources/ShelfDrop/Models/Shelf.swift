import Foundation
import SwiftUI
import AppKit

extension Color {
    func toHex() -> String? {
        let nsColor = NSColor(self).usingColorSpace(.deviceRGB)
        if let r = nsColor?.redComponent,
           let g = nsColor?.greenComponent,
           let b = nsColor?.blueComponent {
            let rgb = (Int(r * 255) << 16) | (Int(g * 255) << 8) | Int(b * 255)
            return String(format: "#%06x", rgb)
        }
        return nil
    }
    
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

/// シェルフの種類
enum ShelfType: String, Codable {
    case file
    case prompt
}

/// シェルフモデル - 複数のShelfItemを保持するコンテナ
class Shelf: Identifiable, ObservableObject, Codable {
    let id: UUID
    @Published var name: String
    @Published var color: Color
    @Published var items: [ShelfItem]
    let createdDate: Date
    let type: ShelfType
    
    static let availableColors: [Color] = [
        .blue, .purple, .pink, .red, .orange, .yellow, .green, .teal, .cyan, .indigo
    ]
    
    enum CodingKeys: String, CodingKey {
        case id, name, colorHex, items, createdDate, type
    }
    
    init(name: String = "シェルフ", color: Color = .blue, type: ShelfType = .file) {
        self.id = UUID()
        self.name = name
        self.color = color
        self.items = []
        self.createdDate = Date()
        self.type = type
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        let hex = try container.decode(String.self, forKey: .colorHex)
        self.color = Color(hex: hex)
        self.items = try container.decode([ShelfItem].self, forKey: .items)
        self.createdDate = try container.decode(Date.self, forKey: .createdDate)
        // 後方互換性：typeがない場合は.fileとする
        if let decodedType = try? container.decode(ShelfType.self, forKey: .type) {
            self.type = decodedType
        } else {
            self.type = .file
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(color.toHex() ?? "#007AFF", forKey: .colorHex)
        try container.encode(items, forKey: .items)
        try container.encode(createdDate, forKey: .createdDate)
        try container.encode(type, forKey: .type)
    }
    
    func addItem(_ item: ShelfItem) {
        items.append(item)
    }
    
    func addItems(_ newItems: [ShelfItem]) {
        items.append(contentsOf: newItems)
    }
    
    func removeItem(at index: Int) {
        guard index >= 0 && index < items.count else { return }
        let item = items[index]
        ThumbnailGenerator.shared.removeCache(for: item.url)
        TempFileManager.shared.deleteFileIfTemporary(at: item.url)
        items.remove(at: index)
    }
    
    func removeItem(withId id: UUID) {
        if let item = items.first(where: { $0.id == id }) {
            ThumbnailGenerator.shared.removeCache(for: item.url)
            TempFileManager.shared.deleteFileIfTemporary(at: item.url)
        }
        items.removeAll { $0.id == id }
    }
    
    func moveItem(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
    }
    
    var itemCount: Int {
        items.count
    }
    
    var totalSize: String {
        var total: UInt64 = 0
        for item in items {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: item.url.path),
               let size = attrs[.size] as? UInt64 {
                total += size
            }
        }
        return ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)
    }
}
