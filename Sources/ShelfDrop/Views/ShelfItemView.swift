import SwiftUI

/// シェルフ内の各アイテムを表示するビュー
struct ShelfItemView: View {
    let item: ShelfItem
    weak var panel: ShelfPanel?
    var onRemove: () -> Void
    
    @State private var isHovering = false
    @State private var thumbnail: NSImage?
    
    var body: some View {
        VStack(spacing: 4) {
            // サムネイル/アイコン
            ZStack(alignment: .topTrailing) {
                thumbnailView
                    .frame(
                        width: Constants.ShelfWindow.itemSize,
                        height: Constants.ShelfWindow.itemSize
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .scaleEffect(isHovering ? Constants.Animation.hoverScaleFactor : 1.0)
                    .shadow(color: .black.opacity(isHovering ? 0.3 : 0.1), radius: isHovering ? 8 : 2)
                    .animation(.easeOut(duration: 0.15), value: isHovering)
                
                // 削除ボタン（ホバー時）
                if isHovering {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .background(Circle().fill(.black.opacity(0.5)).padding(-1))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 4, y: -4)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            
            // ファイル名
            Text(item.name)
                .font(.system(size: 10))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .truncationMode(.middle)
                .frame(width: Constants.ShelfWindow.itemSize)
                .multilineTextAlignment(.center)
            
            // ファイルサイズ（ホバー時）
            if isHovering && !item.fileSize.isEmpty {
                Text(item.fileSize)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .zIndex(isHovering ? 1.0 : 0.0)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onTapGesture(count: 2) {
            NSWorkspace.shared.open(item.url)
        }
        .contextMenu {
            Button("Finderで表示") {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }
            Button("コピー") {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.writeObjects([item.url as NSURL])
            }
            Divider()
            Button("削除", role: .destructive) {
                onRemove()
            }
        }
        .onDrag {
            // ドラッグアウト開始時にフラグを立てる
            panel?.isDraggingOut = true
            
            // ドラッグ終了後にフラグを戻す（少し遅延させる）
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                panel?.isDraggingOut = false
            }
            
            let provider = NSItemProvider()
            
            // テキストアイテムの場合は、文字列としてアイテムを提供する
            if item.fileType == .text, let text = try? String(contentsOf: item.url, encoding: .utf8) {
                provider.registerObject(text as NSString, visibility: .all)
            }
            
            // 全てのケースでファイルURLもフォールバックとして提供する
            provider.registerObject(item.url as NSURL, visibility: .all)
            
            return provider
        }
        .task {
            await loadThumbnail()
        }
    }
    
    // MARK: - サムネイルビュー
    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnail = thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(nsColor: .controlBackgroundColor),
                        Color(nsColor: .controlBackgroundColor).opacity(0.8)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                Image(systemName: item.fileType.systemIconName)
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - サムネイル読み込み
    private func loadThumbnail() async {
        // ThumbnailGenerator は内部で ImageIO を使ったメモリに優しいダウンサンプリングを行うため、
        // NSImage(contentsOf:) による巨大画像のフルサイズ・メモリ読み込み（2GBリークの原因）を回避する
        
        // その他のファイルや読み込みに失敗した場合はThumbnailGeneratorを使用
        let image = await ThumbnailGenerator.shared.generateThumbnail(
            for: item.url,
            size: CGSize(
                width: Constants.ShelfWindow.itemSize * 2,
                height: Constants.ShelfWindow.itemSize * 2
            )
        )
        await MainActor.run {
            self.thumbnail = image
        }
    }
}
