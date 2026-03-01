import SwiftUI

/// メニューバーポップオーバーのビュー
struct MenuBarView: View {
    @ObservedObject var viewModel: ShelfViewModel
    @ObservedObject var settings = SettingsManager.shared
    var onCreateShelf: (ShelfType) -> Void
    var onShowShelf: (UUID) -> Void
    var onDeleteShelf: (UUID) -> Void
    var onQuit: () -> Void
    
    @State private var showDeleteConfirmation = false
    @State private var tempStorageDisplay: String = TempFileManager.shared.totalStorageUsed
    @State private var tempFileCountDisplay: Int = TempFileManager.shared.tempFileCount
    
    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.linearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                
                Text("ShelfDrop")
                    .font(.system(size: 14, weight: .bold))
                
                Spacer()
                
                Menu {
                    Button(action: { onCreateShelf(.file) }) {
                        Label("ファイル棚を作成", systemImage: "folder.fill")
                    }
                    Button(action: { onCreateShelf(.prompt) }) {
                        Label("プロンプト棚を作成", systemImage: "text.bubble.fill")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.blue)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("新しいシェルフを作成")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // シェルフ一覧
            if viewModel.shelves.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    
                    Text("アクティブなシェルフはありません")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    
                    Text("カーソルを振る、または＋ボタンで\n新しいシェルフを作成できます")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(viewModel.shelves) { shelf in
                            shelfRow(shelf)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 300)
            }
            
            Divider()
            
            // 一時ファイル管理セクション
            tempFileSection
            
            Divider()
            
            // フッター
            HStack {
                if !viewModel.shelves.isEmpty {
                    Button("すべてクリア") {
                        let ids = viewModel.shelves.map { $0.id }
                        for id in ids {
                            onDeleteShelf(id)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button("終了") {
                    onQuit()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(width: Constants.MenuBar.popoverWidth)
    }
    
    // MARK: - 一時ファイル管理セクション
    private var tempFileSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // セクションタイトル
            HStack {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("一時ファイル")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            
            // ストレージ情報
            HStack(spacing: 4) {
                Text("\(tempFileCountDisplay) ファイル")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(tempStorageDisplay)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            
            // 自動削除設定
            HStack(spacing: 6) {
                Toggle("自動削除", isOn: $settings.autoDeleteEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .font(.system(size: 11))
                
                if settings.autoDeleteEnabled {
                    Stepper(value: $settings.autoDeleteDays, in: 1...365) {
                        Text("\(settings.autoDeleteDays)日")
                            .font(.system(size: 11))
                            .monospacedDigit()
                    }
                    .controlSize(.mini)
                }
            }
            
            // アクションボタン
            HStack(spacing: 8) {
                // Finderで開くボタン
                Button {
                    TempFileManager.shared.revealInFinder()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.system(size: 10))
                        Text("Finderで開く")
                            .font(.system(size: 10))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .help("一時ファイルの保存場所をFinderで開く")
                
                Spacer()
                
                // 削除ボタン
                Button {
                    showDeleteConfirmation = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                        Text("すべて削除")
                            .font(.system(size: 10))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(tempFileCountDisplay > 0 ? .red : .secondary)
                .disabled(tempFileCountDisplay == 0)
                .help("一時ファイルをすべて削除")
                .alert("一時ファイルの削除", isPresented: $showDeleteConfirmation) {
                    Button("削除", role: .destructive) {
                        TempFileManager.shared.clearAllTempFiles()
                        refreshTempFileInfo()
                    }
                    Button("キャンセル", role: .cancel) {}
                } message: {
                    Text("\(tempStorageDisplay)の一時ファイルをすべて削除しますか？\nこの操作は取り消せません。")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .onAppear {
            refreshTempFileInfo()
        }
    }
    
    // MARK: - ヘルパー
    private func refreshTempFileInfo() {
        tempStorageDisplay = TempFileManager.shared.totalStorageUsed
        tempFileCountDisplay = TempFileManager.shared.tempFileCount
    }
    
    // MARK: - シェルフ行
    private func shelfRow(_ shelf: Shelf) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(shelf.color)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(shelf.name)
                    .font(.system(size: 12, weight: .medium))
                
                HStack(spacing: 4) {
                    Text("\(shelf.items.count) アイテム")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    
                    if !shelf.items.isEmpty {
                        Text("· \(shelf.totalSize)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // 表示ボタン
            Button {
                onShowShelf(shelf.id)
            } label: {
                Image(systemName: "arrow.up.forward.square")
                    .font(.system(size: 12))
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            .help("シェルフを表示")
            
            // 削除ボタン
            Button {
                onDeleteShelf(shelf.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("シェルフを削除")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(viewModel.activeShelfId == shelf.id ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .onTapGesture {
            onShowShelf(shelf.id)
        }
    }
}

