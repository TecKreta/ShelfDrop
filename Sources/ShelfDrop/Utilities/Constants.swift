import Foundation

/// アプリ全体の定数定義
enum Constants {
    /// シェルフウィンドウ関連
    enum ShelfWindow {
        static let defaultWidth: CGFloat = 320
        static let defaultHeight: CGFloat = 200
        static let itemSize: CGFloat = 64
        static let itemSpacing: CGFloat = 8
        static let padding: CGFloat = 12
        static let cornerRadius: CGFloat = 16
        static let maxItemsPerRow: Int = 4
    }
    
    /// アニメーション
    enum Animation {
        static let shelfAppearDuration: Double = 0.3
        static let shelfDismissDuration: Double = 0.25
        static let itemAddDuration: Double = 0.2
        static let hoverScaleFactor: CGFloat = 1.08
    }
    
    /// カーソルシェイク検出
    enum CursorShake {
        static let minimumShakes: Int = 2
        static let detectionInterval: TimeInterval = 1.0
        static let minimumMovement: CGFloat = 15.0
        static let cooldownInterval: TimeInterval = 2.0
    }
    
    /// メニューバー
    enum MenuBar {
        static let iconName: String = "tray.2.fill" // アップデート確認用にアイコンを変更
        static let popoverWidth: CGFloat = 280
        static let popoverHeight: CGFloat = 400
    }
    
    /// 一時ファイル管理
    enum TempFiles {
        static let directoryName = "TempImages"
        static let containerName = "ShelfDrop"
        static let defaultAutoDeleteDays = 7
    }
    
    /// カラースキーム
    enum Colors {
        static let shelfBackground = "shelfBackground"
        static let shelfBorder = "shelfBorder"
    }
}
