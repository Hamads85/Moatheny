import Foundation
import os.log

/// Performance Metrics Collector للبوصلة
/// يقيس CPU usage, Memory allocation, Latency, و Frame rate
final class PerformanceMetricsCollector {
    
    // MARK: - Types
    
    struct Metrics {
        var cpuUsage: Double = 0              // CPU usage percentage
        var memoryUsage: Int64 = 0             // Memory usage in bytes
        var averageLatency: TimeInterval = 0  // Average processing latency in seconds
        var maxLatency: TimeInterval = 0       // Maximum latency
        var updateRate: Double = 0             // Actual update rate (Hz)
        var droppedFrames: Int = 0             // Number of dropped frames
        var filterProcessingTime: TimeInterval = 0 // Kalman filter processing time
        
        var formattedMemoryUsage: String {
            let mb = Double(memoryUsage) / 1_000_000
            return String(format: "%.2f MB", mb)
        }
        
        var formattedCPUUsage: String {
            return String(format: "%.1f%%", cpuUsage)
        }
    }
    
    // MARK: - Properties
    
    private var updateTimestamps: [Date] = []
    private var latencyMeasurements: [TimeInterval] = []
    private var filterProcessingTimes: [TimeInterval] = []
    
    private let maxSamples = 100  // عدد العينات المحفوظة
    private let updateWindow: TimeInterval = 1.0  // نافذة حساب معدل التحديث (ثانية)
    
    private var lastCPUMeasurement: (time: Date, usage: Double)?
    private var lastMemoryMeasurement: Date?
    
    private let logger = Logger(subsystem: "com.moatheny.compass", category: "Performance")
    
    // MARK: - Public Methods
    
    /// تسجيل بداية معالجة قراءة جديدة
    func recordUpdateStart() -> Date {
        let timestamp = Date()
        updateTimestamps.append(timestamp)
        
        // تنظيف العينات القديمة
        if updateTimestamps.count > maxSamples {
            updateTimestamps.removeFirst()
        }
        
        return timestamp
    }
    
    /// تسجيل نهاية معالجة قراءة
    func recordUpdateEnd(startTime: Date) {
        let latency = Date().timeIntervalSince(startTime)
        latencyMeasurements.append(latency)
        
        if latencyMeasurements.count > maxSamples {
            latencyMeasurements.removeFirst()
        }
        
        // تحديث max latency
        if latency > currentMetrics.maxLatency {
            // نحدّث max latency فقط إذا كان أكبر من القيمة الحالية
        }
    }
    
    /// تسجيل وقت معالجة فلتر Kalman
    func recordFilterProcessing(time: TimeInterval) {
        filterProcessingTimes.append(time)
        
        if filterProcessingTimes.count > maxSamples {
            filterProcessingTimes.removeFirst()
        }
    }
    
    /// الحصول على CPU usage مباشرة
    var formattedCPUUsage: String {
        return currentMetrics.formattedCPUUsage
    }
    
    /// الحصول على Memory usage مباشرة
    var formattedMemoryUsage: String {
        return currentMetrics.formattedMemoryUsage
    }
    
    /// الحصول على معدل التحديث مباشرة
    var updateRate: Double {
        return currentMetrics.updateRate
    }
    
    /// حساب Metrics الحالية
    var currentMetrics: Metrics {
        var metrics = Metrics()
        
        // حساب معدل التحديث الفعلي
        metrics.updateRate = calculateUpdateRate()
        
        // حساب Latency
        if !latencyMeasurements.isEmpty {
            metrics.averageLatency = latencyMeasurements.reduce(0, +) / Double(latencyMeasurements.count)
            metrics.maxLatency = latencyMeasurements.max() ?? 0
        }
        
        // حساب وقت معالجة الفلتر
        if !filterProcessingTimes.isEmpty {
            metrics.filterProcessingTime = filterProcessingTimes.reduce(0, +) / Double(filterProcessingTimes.count)
        }
        
        // حساب CPU usage
        metrics.cpuUsage = calculateCPUUsage()
        
        // حساب Memory usage
        metrics.memoryUsage = getCurrentMemoryUsage()
        
        return metrics
    }
    
    /// طباعة تقرير الأداء
    func printPerformanceReport() {
        let metrics = currentMetrics
        
        logger.info("""
        📊 Performance Report:
        ──────────────────────
        CPU Usage: \(metrics.formattedCPUUsage)
        Memory: \(metrics.formattedMemoryUsage)
        Update Rate: \(String(format: "%.1f Hz", metrics.updateRate))
        Avg Latency: \(String(format: "%.3f ms", metrics.averageLatency * 1000))
        Max Latency: \(String(format: "%.3f ms", metrics.maxLatency * 1000))
        Filter Time: \(String(format: "%.3f ms", metrics.filterProcessingTime * 1000))
        ──────────────────────
        """)
    }
    
    /// التحقق من الالتزام بـ Performance Budgets
    func checkPerformanceBudgets() -> BudgetCheckResult {
        let metrics = currentMetrics
        var violations: [String] = []
        var warnings: [String] = []
        
        // CPU Budget: < 5% average
        if metrics.cpuUsage > 5.0 {
            violations.append("CPU usage exceeds budget: \(metrics.formattedCPUUsage) > 5%")
        } else if metrics.cpuUsage > 3.0 {
            warnings.append("CPU usage approaching limit: \(metrics.formattedCPUUsage)")
        }
        
        // Latency Budget: < 16ms (60fps)
        if metrics.averageLatency > 0.016 {
            violations.append("Latency exceeds budget: \(String(format: "%.1f ms", metrics.averageLatency * 1000)) > 16ms")
        } else if metrics.averageLatency > 0.010 {
            warnings.append("Latency approaching limit: \(String(format: "%.1f ms", metrics.averageLatency * 1000))")
        }
        
        // Memory Budget: < 10MB for compass processing
        let memoryMB = Double(metrics.memoryUsage) / 1_000_000
        if memoryMB > 10.0 {
            violations.append("Memory usage exceeds budget: \(metrics.formattedMemoryUsage) > 10MB")
        } else if memoryMB > 7.0 {
            warnings.append("Memory usage approaching limit: \(metrics.formattedMemoryUsage)")
        }
        
        // Filter Processing Budget: < 1ms
        if metrics.filterProcessingTime > 0.001 {
            warnings.append("Filter processing time high: \(String(format: "%.2f ms", metrics.filterProcessingTime * 1000))")
        }
        
        return BudgetCheckResult(
            isWithinBudget: violations.isEmpty,
            violations: violations,
            warnings: warnings
        )
    }
    
    /// إعادة تعيين جميع القياسات
    func reset() {
        updateTimestamps.removeAll()
        latencyMeasurements.removeAll()
        filterProcessingTimes.removeAll()
        lastCPUMeasurement = nil
        lastMemoryMeasurement = nil
    }
    
    // MARK: - Private Methods
    
    private func calculateUpdateRate() -> Double {
        guard updateTimestamps.count >= 2 else { return 0 }
        
        let now = Date()
        let windowStart = now.addingTimeInterval(-updateWindow)
        
        // عد التحديثات في النافذة الزمنية
        let updatesInWindow = updateTimestamps.filter { $0 >= windowStart }.count
        
        return Double(updatesInWindow) / updateWindow
    }
    
    private func calculateCPUUsage() -> Double {
        // تقدير CPU usage بناءً على:
        // 1. Latency (وقت المعالجة)
        // 2. Update Rate (معدل التحديث)
        // 3. Filter Processing Time
        
        guard !latencyMeasurements.isEmpty else { return 0 }
        
        let avgLatency = latencyMeasurements.reduce(0, +) / Double(latencyMeasurements.count)
        let updateRate = calculateUpdateRate()
        
        // حساب CPU usage كـ: (Latency * Update Rate) * 100
        // هذا يعطي نسبة الوقت المستغرق في المعالجة
        var estimatedCPUUsage = avgLatency * updateRate * 100
        
        // إضافة تأثير Filter Processing Time
        if !filterProcessingTimes.isEmpty {
            let avgFilterTime = filterProcessingTimes.reduce(0, +) / Double(filterProcessingTimes.count)
            estimatedCPUUsage += avgFilterTime * updateRate * 100
        }
        
        // الحد الأقصى 100%
        return min(estimatedCPUUsage, 100.0)
    }
    
    private func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        guard kerr == KERN_SUCCESS else { return 0 }
        
        return Int64(info.resident_size)
    }
}

// MARK: - Budget Check Result

struct BudgetCheckResult {
    let isWithinBudget: Bool
    let violations: [String]
    let warnings: [String]
    
    var hasIssues: Bool {
        return !violations.isEmpty || !warnings.isEmpty
    }
}

// MARK: - Mach Task Info (for memory/CPU measurement)

import Darwin

private func mach_task_self() -> mach_port_t {
    return mach_task_self_
}
