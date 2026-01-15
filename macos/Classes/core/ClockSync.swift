import Foundation

/// Clock synchronization for AV sync
class ClockSync {
    private var basePts: Int64 = 0
    private var baseTime: CFAbsoluteTime = 0
    private var speed: Double = 1.0
    private var isPaused: Bool = false
    private var pausedTime: CFAbsoluteTime = 0
    
    private let lock = NSLock()
    
    func setMasterPts(_ pts: Int64) {
        lock.lock()
        defer { lock.unlock() }
        
        basePts = pts
        baseTime = CFAbsoluteTimeGetCurrent()
    }
    
    func getCurrentPts() -> Int64 {
        lock.lock()
        defer { lock.unlock() }
        
        if isPaused {
            return basePts
        }
        
        let now = CFAbsoluteTimeGetCurrent()
        let elapsed = (now - baseTime) * 1000 * speed  // Convert to milliseconds
        return basePts + Int64(elapsed)
    }
    
    func setSpeed(_ speed: Double) {
        lock.lock()
        defer { lock.unlock() }
        
        // Update base before changing speed
        if !isPaused {
            let now = CFAbsoluteTimeGetCurrent()
            let elapsed = (now - baseTime) * 1000 * self.speed
            basePts = basePts + Int64(elapsed)
            baseTime = now
        }
        
        self.speed = speed
    }
    
    func pause() {
        lock.lock()
        defer { lock.unlock() }
        
        if !isPaused {
            let now = CFAbsoluteTimeGetCurrent()
            let elapsed = (now - baseTime) * 1000 * speed
            basePts = basePts + Int64(elapsed)
            pausedTime = now
            isPaused = true
        }
    }
    
    func resume() {
        lock.lock()
        defer { lock.unlock() }
        
        if isPaused {
            baseTime = CFAbsoluteTimeGetCurrent()
            isPaused = false
        }
    }
    
    func seek(_ position: Int64) {
        lock.lock()
        defer { lock.unlock() }
        
        basePts = position
        baseTime = CFAbsoluteTimeGetCurrent()
    }
    
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        
        basePts = 0
        baseTime = CFAbsoluteTimeGetCurrent()
        speed = 1.0
        isPaused = false
    }
    
    func getFrameDelay(framePts: Int64) -> Int64 {
        let currentPts = getCurrentPts()
        return framePts - currentPts
    }
}
