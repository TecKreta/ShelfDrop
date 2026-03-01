import Cocoa

/// カーソルシェイク（振り）を検出するサービス
/// ドラッグ中 または Commandキー押下中 のみ反応する
class CursorShakeDetector {
    typealias ShakeHandler = () -> Void
    
    private var onShakeDetected: ShakeHandler?
    private var mouseMonitor: Any?
    private var flagsMonitor: Any?
    private var positions: [(point: NSPoint, time: TimeInterval)] = []
    private var directionChanges: Int = 0
    private var lastDirection: CGFloat = 0
    private var lastShakeTime: TimeInterval = 0
    
    var isEnabled: Bool = true
    var minimumShakes: Int = Constants.CursorShake.minimumShakes
    var detectionInterval: TimeInterval = Constants.CursorShake.detectionInterval
    var minimumMovement: CGFloat = Constants.CursorShake.minimumMovement
    var cooldownInterval: TimeInterval = Constants.CursorShake.cooldownInterval
    
    init(onShakeDetected: @escaping ShakeHandler) {
        self.onShakeDetected = onShakeDetected
    }
    
    func startMonitoring() {
        // マウス移動・ドラッグを監視
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            self?.handleMouseEvent(event)
        }
    }
    
    func stopMonitoring() {
        if let mouseMonitor = mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
            self.mouseMonitor = nil
        }
    }
    
    private func handleMouseEvent(_ event: NSEvent) {
        guard isEnabled else { return }
        
        let currentTime = ProcessInfo.processInfo.systemUptime
        
        // クールダウン中は無視
        guard currentTime - lastShakeTime > cooldownInterval else { return }
        
        // Shiftキー押下中 のみ検出（単なるドラッグ中でのシェイクは誤爆防止のため廃止）
        let isShiftPressed = event.modifierFlags.contains(.shift)
        guard isShiftPressed else {
            if !positions.isEmpty { reset() }
            return
        }
        
        let currentPoint = NSEvent.mouseLocation
        
        // 古い位置データを削除
        positions.removeAll { currentTime - $0.time > detectionInterval }
        
        // 新しい位置を追加
        positions.append((point: currentPoint, time: currentTime))
        
        guard positions.count >= 2 else { return }
        
        let prev = positions[positions.count - 2]
        let dx = currentPoint.x - prev.point.x
        
        // 小さすぎる動きは除外
        guard abs(dx) > 4 else { return }
        
        let currentDirection: CGFloat = dx > 0 ? 1 : -1
        
        // 方向転換の検出
        if lastDirection != 0 && currentDirection != lastDirection {
            let movement = abs(dx)
            if movement >= minimumMovement {
                directionChanges += 1
            }
        }
        
        lastDirection = currentDirection
        
        // シェイク判定
        if directionChanges >= minimumShakes {
            lastShakeTime = currentTime
            reset()
            DispatchQueue.main.async { [weak self] in
                self?.onShakeDetected?()
            }
        }
        
        // 一定時間経過でリセット
        if let first = positions.first, currentTime - first.time > detectionInterval {
            reset()
        }
    }
    
    private func reset() {
        positions.removeAll()
        directionChanges = 0
        lastDirection = 0
    }
    
    deinit {
        stopMonitoring()
    }
}
