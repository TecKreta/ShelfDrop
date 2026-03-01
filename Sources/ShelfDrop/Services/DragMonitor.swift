import Cocoa

/// システム全体のドラッグイベントを監視するサービス
class DragMonitor {
    typealias DragHandler = (NSPoint) -> Void
    
    private var dragStartHandler: DragHandler?
    private var dragEndHandler: DragHandler?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private(set) var isDragging: Bool = false
    
    init(onDragStart: @escaping DragHandler, onDragEnd: @escaping DragHandler) {
        self.dragStartHandler = onDragStart
        self.dragEndHandler = onDragEnd
    }
    
    func startMonitoring() {
        // グローバルでのドラッグ監視
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            self?.handleEvent(event)
        }
        
        // ローカルでのドラッグ監視
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            self?.handleEvent(event)
            return event
        }
    }
    
    func stopMonitoring() {
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        isDragging = false
    }
    
    private func handleEvent(_ event: NSEvent) {
        let location = NSEvent.mouseLocation
        
        switch event.type {
        case .leftMouseDragged:
            if !isDragging {
                isDragging = true
                DispatchQueue.main.async { [weak self] in
                    self?.dragStartHandler?(location)
                }
            }
        case .leftMouseUp:
            if isDragging {
                isDragging = false
                DispatchQueue.main.async { [weak self] in
                    self?.dragEndHandler?(location)
                }
            }
        default:
            break
        }
    }
    
    deinit {
        stopMonitoring()
    }
}
