import Foundation

/// UserDefaultsベースの設定管理
/// 自動削除の日数やON/OFF設定を永続化する
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Keys
    private enum Keys {
        static let autoDeleteEnabled = "shelfdrop.autoDelete.enabled"
        static let autoDeleteDays = "shelfdrop.autoDelete.days"
    }
    
    // MARK: - Properties
    
    /// 自動削除が有効かどうか（デフォルト: true）
    @Published var autoDeleteEnabled: Bool {
        didSet {
            defaults.set(autoDeleteEnabled, forKey: Keys.autoDeleteEnabled)
        }
    }
    
    /// 自動削除までの日数（デフォルト: 7日）
    @Published var autoDeleteDays: Int {
        didSet {
            let clamped = max(1, min(autoDeleteDays, 365))
            if clamped != autoDeleteDays {
                autoDeleteDays = clamped
            }
            defaults.set(clamped, forKey: Keys.autoDeleteDays)
        }
    }
    
    // MARK: - Init
    
    private init() {
        // デフォルト値の登録
        defaults.register(defaults: [
            Keys.autoDeleteEnabled: false,
            Keys.autoDeleteDays: Constants.TempFiles.defaultAutoDeleteDays
        ])
        
        self.autoDeleteEnabled = defaults.bool(forKey: Keys.autoDeleteEnabled)
        self.autoDeleteDays = defaults.integer(forKey: Keys.autoDeleteDays)
    }
    
    // MARK: - Actions
    
    /// 設定に基づいて期限切れファイルのクリーンアップを実行
    func performAutoCleanupIfNeeded() {
        guard autoDeleteEnabled else { return }
        TempFileManager.shared.cleanupExpiredFiles(olderThanDays: autoDeleteDays)
    }
}
