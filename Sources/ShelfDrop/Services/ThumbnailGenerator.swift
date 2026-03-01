import Cocoa
import QuickLookThumbnailing

/// ファイルのサムネイル画像を生成するサービス
class ThumbnailGenerator {
    static let shared = ThumbnailGenerator()
    private var cache: [URL: NSImage] = [:]
    
    private init() {}
    
    /// サムネイルを非同期で生成 (メモリ最適化版)
    func generateThumbnail(for url: URL, size: CGSize = CGSize(width: 128, height: 128)) async -> NSImage? {
        // キャッシュチェック
        if let cached = cache[url] {
            return cached
        }
        
        // --- 1. QuickLook での生成を試みる ---
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: 2.0,
            representationTypes: .thumbnail
        )
        
        if let thumbnail = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
            let image = thumbnail.nsImage
            cache[url] = image
            return image
        }
        
        // --- 2. QuickLook 失敗時: ImageIO を使ったメモリ効率の良いダウンサンプリング (フルサイズ読み込み回避) ---
        // JPEGやPNGなどの画像ファイルに対して、全ピクセルをメモリに展開せずに縮小画像だけを直接生成する
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height) * 2.0 // Retina対応で2倍
        ]
        
        if let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
           let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) {
            
            let image = NSImage(cgImage: cgImage, size: size)
            cache[url] = image
            return image
        }
        
        // --- 3. 最終フォールバック: システムの汎用ファイルアイコン ---
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = size
        cache[url] = icon
        return icon
    }
    
    /// 特定のURLのキャッシュをクリア
    func removeCache(for url: URL) {
        cache.removeValue(forKey: url)
    }
    
    /// キャッシュをすべてクリア
    func clearCache() {
        cache.removeAll()
    }
}
