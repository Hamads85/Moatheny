import Foundation

/// Adaptive Update Rate Manager
/// يتحكم في معدل تحديث البوصلة بناءً على حالة الحركة
/// - معدل عالي (30 Hz) عند الحركة السريعة
/// - معدل منخفض (5-10 Hz) عند الثبات لتوفير البطارية
final class AdaptiveUpdateRateManager {
    
    // MARK: - Types
    
    enum MotionState {
        case stationary      // ثابت - معدل منخفض
        case slowMovement    // حركة بطيئة - معدل متوسط
        case fastMovement    // حركة سريعة - معدل عالي
        
        var updateInterval: TimeInterval {
            switch self {
            case .stationary:
                return 1.0 / 5.0  // 5 Hz
            case .slowMovement:
                return 1.0 / 15.0 // 15 Hz
            case .fastMovement:
                return 1.0 / 30.0 // 30 Hz
            }
        }
        
        var description: String {
            switch self {
            case .stationary: return "ثابت"
            case .slowMovement: return "حركة بطيئة"
            case .fastMovement: return "حركة سريعة"
            }
        }
    }
    
    // MARK: - Properties
    
    private var headingHistory: [Double] = []
    private var headingTimestamps: [Date] = []
    private var currentState: MotionState = .stationary
    
    // معاملات الكشف عن الحركة
    private let stationaryThreshold: Double = 0.5      // درجة/ثانية
    private let slowMovementThreshold: Double = 5.0     // درجة/ثانية
    private let historyWindow: TimeInterval = 0.5       // نافذة زمنية للتحليل (ثانية)
    private let maxHistorySize = 30                     // أقصى عدد قراءات محفوظة
    
    // Throttling
    private var lastUpdateTime: Date?
    private var pendingUpdate: (heading: Double, timestamp: Date)?
    
    // Callbacks
    var onStateChanged: ((MotionState) -> Void)?
    var onUpdateRateChanged: ((TimeInterval) -> Void)?
    
    // MARK: - Public Methods
    
    /// تحديث حالة الحركة بناءً على قراءة جديدة
    func update(heading: Double, timestamp: Date = Date()) -> MotionState {
        // إضافة القراءة الجديدة للتاريخ
        headingHistory.append(heading)
        headingTimestamps.append(timestamp)
        
        // تنظيف التاريخ القديم
        cleanupOldHistory(before: timestamp.addingTimeInterval(-historyWindow))
        
        // حساب سرعة التغيير (درجة/ثانية)
        let angularVelocity = calculateAngularVelocity()
        
        // تحديد حالة الحركة
        let newState: MotionState
        if angularVelocity < stationaryThreshold {
            newState = .stationary
        } else if angularVelocity < slowMovementThreshold {
            newState = .slowMovement
        } else {
            newState = .fastMovement
        }
        
        // تحديث الحالة إذا تغيرت
        if newState != currentState {
            currentState = newState
            onStateChanged?(newState)
            onUpdateRateChanged?(newState.updateInterval)
        }
        
        return newState
    }
    
    /// التحقق من إمكانية التحديث بناءً على Throttling
    func shouldUpdate(timestamp: Date = Date()) -> Bool {
        guard let lastUpdate = lastUpdateTime else {
            lastUpdateTime = timestamp
            return true
        }
        
        let timeSinceLastUpdate = timestamp.timeIntervalSince(lastUpdate)
        let requiredInterval = currentState.updateInterval
        
        if timeSinceLastUpdate >= requiredInterval {
            lastUpdateTime = timestamp
            return true
        }
        
        return false
    }
    
    /// الحصول على معدل التحديث الحالي
    var currentUpdateInterval: TimeInterval {
        return currentState.updateInterval
    }
    
    /// الحصول على حالة الحركة الحالية
    var motionState: MotionState {
        return currentState
    }
    
    /// إعادة تعيين الحالة
    func reset() {
        headingHistory.removeAll()
        headingTimestamps.removeAll()
        currentState = .stationary
        lastUpdateTime = nil
        pendingUpdate = nil
    }
    
    // MARK: - Private Methods
    
    private func cleanupOldHistory(before date: Date) {
        // إزالة القراءات الأقدم من التاريخ المحدد
        while let firstTimestamp = headingTimestamps.first,
              firstTimestamp < date,
              !headingTimestamps.isEmpty {
            headingHistory.removeFirst()
            headingTimestamps.removeFirst()
        }
        
        // أيضاً، حد أقصى للعدد
        while headingHistory.count > maxHistorySize {
            headingHistory.removeFirst()
            headingTimestamps.removeFirst()
        }
    }
    
    private func calculateAngularVelocity() -> Double {
        guard headingHistory.count >= 2,
              headingTimestamps.count >= 2 else {
            return 0
        }
        
        // حساب التغيير الكلي في الزاوية
        var totalChange: Double = 0
        var totalTime: TimeInterval = 0
        
        for i in 1..<headingHistory.count {
            let prevHeading = headingHistory[i - 1]
            let currHeading = headingHistory[i]
            
            // حساب الفرق الزاوي مع مراعاة الانتقال 359→0
            var diff = currHeading - prevHeading
            if diff > 180 {
                diff -= 360
            } else if diff < -180 {
                diff += 360
            }
            
            totalChange += abs(diff)
            
            let timeDiff = headingTimestamps[i].timeIntervalSince(headingTimestamps[i - 1])
            totalTime += timeDiff
        }
        
        guard totalTime > 0 else { return 0 }
        
        // السرعة الزاوية = التغيير الكلي / الوقت الكلي (درجة/ثانية)
        return totalChange / totalTime
    }
}

// MARK: - Performance-Aware Throttling

extension AdaptiveUpdateRateManager {
    
    /// Throttling ذكي يأخذ في الاعتبار الأداء
    func shouldUpdateWithPerformanceCheck(
        timestamp: Date = Date(),
        currentLatency: TimeInterval,
        targetFrameTime: TimeInterval = 0.016 // 60 fps = 16ms
    ) -> Bool {
        // إذا كانت latency عالية، نخفض معدل التحديث
        if currentLatency > targetFrameTime * 2 {
            // latency عالية جداً - نخفض معدل التحديث
            let adjustedInterval = currentState.updateInterval * 2
            if let lastUpdate = lastUpdateTime {
                let timeSinceLastUpdate = timestamp.timeIntervalSince(lastUpdate)
                return timeSinceLastUpdate >= adjustedInterval
            }
            return true
        }
        
        // استخدام Throttling العادي
        return shouldUpdate(timestamp: timestamp)
    }
}
