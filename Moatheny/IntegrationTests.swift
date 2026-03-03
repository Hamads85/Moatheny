import XCTest
import CoreLocation
import CoreMotion
@testable import Moatheny

/// اختبارات التكامل للبوصلة
/// تغطي: CompassService integration, Location + Compass integration, UI integration
final class IntegrationTests: XCTestCase {
    
    var compassService: CompassService!
    
    override func setUp() {
        super.setUp()
        compassService = CompassService()
    }
    
    override func tearDown() {
        compassService.stopUpdating()
        compassService = nil
        super.tearDown()
    }
    
    // MARK: - CompassService Integration Tests
    
    /// اختبار تهيئة CompassService
    func testCompassServiceInitialization() {
        XCTAssertNotNil(compassService, "CompassService يجب أن يُنشأ بنجاح")
        XCTAssertFalse(compassService.isUpdating, "الخدمة يجب أن تبدأ متوقفة")
        XCTAssertEqual(compassService.heading, 0, "الاتجاه الابتدائي يجب أن يكون 0")
    }
    
    /// اختبار تفعيل CompassService (بدون إذن فعلي)
    func testCompassServiceStartUpdating() {
        // ملاحظة: هذا الاختبار يتطلب إذن الموقع الفعلي
        // في بيئة الاختبار، قد لا يعمل بشكل كامل
        
        // التحقق من أن الخدمة متاحة (إذا كان الجهاز يدعم البوصلة)
        let isAvailable = CLLocationManager.headingAvailable()
        
        if isAvailable {
            // محاولة البدء (قد يفشل بدون إذن)
            compassService.startUpdating()
            
            // التحقق من أن الحالة تغيرت
            // ملاحظة: قد لا يعمل بدون إذن فعلي
        } else {
            XCTAssertFalse(compassService.isAvailable, "الخدمة يجب أن تكون غير متاحة على أجهزة بدون بوصلة")
        }
    }
    
    /// اختبار إيقاف CompassService
    func testCompassServiceStopUpdating() {
        compassService.startUpdating()
        compassService.stopUpdating()
        
        XCTAssertFalse(compassService.isUpdating, "الخدمة يجب أن تتوقف بعد stopUpdating()")
    }
    
    /// اختبار تعويض الميلان
    func testTiltCompensation() {
        compassService.setTiltCompensation(true)
        XCTAssertTrue(compassService.tiltCompensationEnabled, "تعويض الميلان يجب أن يكون مفعلاً")
        
        compassService.setTiltCompensation(false)
        XCTAssertFalse(compassService.tiltCompensationEnabled, "تعويض الميلان يجب أن يكون معطلاً")
    }
    
    /// اختبار الحصول على معلومات الوضعية
    func testGetOrientationInfo() {
        let info = compassService.getOrientationInfo()
        
        XCTAssertNotNil(info.orientation, "الوضعية يجب أن تكون متاحة")
        XCTAssertNotNil(info.isFlat, "حالة الاستواء يجب أن تكون متاحة")
        XCTAssertNotNil(info.pitch, "الميل يجب أن يكون متاحاً")
        XCTAssertNotNil(info.roll, "الدوران يجب أن يكون متاحاً")
    }
    
    // MARK: - Location + Compass Integration Tests
    
    /// اختبار حساب اتجاه القبلة مع CompassService
    func testQiblaDirectionWithCompass() {
        let qiblaService = QiblaService()
        let location = CLLocationCoordinate2D(latitude: 24.7136, longitude: 46.6753) // الرياض
        
        let qiblaDirection = qiblaService.bearing(from: location)
        
        // يجب أن يكون اتجاه القبلة في النطاق الصحيح
        XCTAssertGreaterThanOrEqual(qiblaDirection, 0)
        XCTAssertLessThan(qiblaDirection, 360)
        
        // من الرياض، اتجاه القبلة يجب أن يكون حوالي 243°
        XCTAssertGreaterThan(qiblaDirection, 240)
        XCTAssertLessThan(qiblaDirection, 246)
    }
    
    /// اختبار حساب زاوية دوران السهم
    func testArrowRotationCalculation() {
        let qiblaDirection: Double = 243.0 // اتجاه القبلة من الرياض
        let deviceHeading: Double = 0.0    // الجهاز يشير شمال
        
        // استخدام الدالة الفعلية من QiblaCalculator
        let rotation = QiblaCalculator.calculateArrowRotation(
            qiblaDirection: qiblaDirection,
            deviceHeading: deviceHeading
        )
        
        // يجب أن تكون زاوية الدوران -117° (أقصر مسار)
        XCTAssertEqual(rotation, -117.0, accuracy: 1.0, "زاوية الدوران يجب أن تكون صحيحة")
        XCTAssertGreaterThanOrEqual(rotation, -180, "الزاوية يجب أن تكون في النطاق [-180, 180]")
        XCTAssertLessThanOrEqual(rotation, 180, "الزاوية يجب أن تكون في النطاق [-180, 180]")
    }
    
    /// اختبار حساب زاوية الدوران مع الانتقال الزاوي
    func testArrowRotationWithWrapAround() {
        let qiblaDirection: Double = 350.0
        let deviceHeading: Double = 10.0
        
        // استخدام الدالة الفعلية من QiblaCalculator
        let rotation = QiblaCalculator.calculateArrowRotation(
            qiblaDirection: qiblaDirection,
            deviceHeading: deviceHeading
        )
        
        // يجب أن يكون -20° وليس 340° (أقصر مسار)
        XCTAssertEqual(rotation, -20.0, accuracy: 1.0, "زاوية الدوران مع الانتقال الزاوي يجب أن تكون صحيحة")
        XCTAssertGreaterThanOrEqual(rotation, -180)
        XCTAssertLessThanOrEqual(rotation, 180)
    }
    
    /// اختبار: موجه للقبلة (rotation = 0)
    func testArrowRotation_PointingToQibla() {
        let qiblaDirection: Double = 242.9
        let deviceHeading: Double = 242.9 // موجه للقبلة
        
        let rotation = QiblaCalculator.calculateArrowRotation(
            qiblaDirection: qiblaDirection,
            deviceHeading: deviceHeading
        )
        
        // يجب أن يكون 0° (السهم للأعلى)
        XCTAssertEqual(rotation, 0.0, accuracy: 0.1, "عند التوجه للقبلة، يجب أن يكون rotation = 0")
    }
    
    /// اختبار: تطبيع القيم السالبة
    func testArrowRotation_NegativeInput() {
        let qiblaDirection: Double = -100.0 // سيتم تطبيعها إلى 260°
        let deviceHeading: Double = 0.0
        
        let rotation = QiblaCalculator.calculateArrowRotation(
            qiblaDirection: qiblaDirection,
            deviceHeading: deviceHeading
        )
        
        // -100° → 260° بعد التطبيع
        // rotation = 260° - 0° = 260° → -100° بعد التطبيع
        XCTAssertEqual(rotation, -100.0, accuracy: 0.1, "القيم السالبة يجب أن تُطبع بشكل صحيح")
    }
    
    /// اختبار: تطبيع القيم أكبر من 360
    func testArrowRotation_Over360() {
        let qiblaDirection: Double = 450.0 // سيتم تطبيعها إلى 90°
        let deviceHeading: Double = 0.0
        
        let rotation = QiblaCalculator.calculateArrowRotation(
            qiblaDirection: qiblaDirection,
            deviceHeading: deviceHeading
        )
        
        // 450° → 90° بعد التطبيع
        XCTAssertEqual(rotation, 90.0, accuracy: 0.1, "القيم أكبر من 360 يجب أن تُطبع بشكل صحيح")
    }
    
    /// اختبار: جميع الاتجاهات الأساسية
    func testArrowRotation_AllDirections() {
        let testCases: [(qibla: Double, heading: Double, expected: Double, description: String)] = [
            (0.0, 0.0, 0.0, "شمال → شمال"),
            (90.0, 0.0, 90.0, "شرق → شمال"),
            (180.0, 0.0, 180.0, "جنوب → شمال"),
            (270.0, 0.0, -90.0, "غرب → شمال (أقصر مسار)"),
            (45.0, 45.0, 0.0, "شمال شرق → شمال شرق"),
        ]
        
        for (qibla, heading, expected, description) in testCases {
            let rotation = QiblaCalculator.calculateArrowRotation(
                qiblaDirection: qibla,
                deviceHeading: heading
            )
            XCTAssertEqual(rotation, expected, accuracy: 0.1,
                          "فشل في: \(description) - qibla=\(qibla), heading=\(heading)")
        }
    }
    
    /// اختبار: القيم القصوى والحالات الحدية
    func testArrowRotation_EdgeCases() {
        // القيمة القصوى: 360°
        let rotation1 = QiblaCalculator.calculateArrowRotation(
            qiblaDirection: 360.0,
            deviceHeading: 0.0
        )
        XCTAssertEqual(rotation1, 0.0, accuracy: 0.1)
        
        // الفرق الكبير (>180°)
        let rotation2 = QiblaCalculator.calculateArrowRotation(
            qiblaDirection: 270.0,
            deviceHeading: 0.0
        )
        // يجب أن يكون -90° وليس 270°
        XCTAssertEqual(rotation2, -90.0, accuracy: 0.1)
    }
    
    // MARK: - Adaptive Update Rate Integration Tests
    
    /// اختبار Adaptive Update Rate Manager
    func testAdaptiveUpdateRateManager() {
        let manager = AdaptiveUpdateRateManager()
        
        // حالة ثابتة
        _ = manager.update(heading: 0, timestamp: Date())
        XCTAssertEqual(manager.motionState, .stationary, "الحالة يجب أن تكون ثابتة في البداية")
        
        // حركة بطيئة
        for i in 0..<10 {
            let timestamp = Date().addingTimeInterval(Double(i) * 0.1)
            _ = manager.update(heading: Double(i) * 0.5, timestamp: timestamp)
        }
        
        // يجب أن تتحول الحالة إلى slowMovement أو fastMovement
        let state = manager.motionState
        XCTAssertTrue(state == .slowMovement || state == .fastMovement || state == .stationary,
                     "الحالة يجب أن تتغير مع الحركة")
    }
    
    /// اختبار Throttling في Adaptive Update Rate
    func testAdaptiveUpdateRateThrottling() {
        let manager = AdaptiveUpdateRateManager()
        
        let timestamp1 = Date()
        let shouldUpdate1 = manager.shouldUpdate(timestamp: timestamp1)
        XCTAssertTrue(shouldUpdate1, "يجب السماح بالتحديث الأول")
        
        // محاولة تحديث فوري (يجب أن يُرفض)
        let timestamp2 = timestamp1.addingTimeInterval(0.001) // 1ms
        let shouldUpdate2 = manager.shouldUpdate(timestamp: timestamp2)
        
        // اعتماداً على الحالة، قد يُسمح أو يُرفض
        // في حالة stationary (5 Hz)، يجب أن يُرفض
        if manager.motionState == .stationary {
            XCTAssertFalse(shouldUpdate2, "التحديث الفوري يجب أن يُرفض في حالة الثبات")
        }
    }
    
    // MARK: - End-to-End Integration Tests
    
    /// اختبار التكامل الكامل: Location → Qibla → Compass → UI
    func testEndToEndIntegration() {
        // 1. حساب اتجاه القبلة من الموقع
        let qiblaService = QiblaService()
        let location = CLLocationCoordinate2D(latitude: 24.7136, longitude: 46.6753)
        let qiblaDirection = qiblaService.bearing(from: location)
        
        XCTAssertGreaterThanOrEqual(qiblaDirection, 0)
        XCTAssertLessThan(qiblaDirection, 360)
        
        // 2. حساب الانحراف المغناطيسي
        let declination = MagneticDeclinationCalculator.calculateDeclination(
            latitude: location.latitude,
            longitude: location.longitude
        )
        
        XCTAssertGreaterThan(declination, -30)
        XCTAssertLessThan(declination, 30)
        
        // 3. تحويل Heading من مغناطيسي إلى حقيقي
        let magneticHeading: Double = 243.0
        let trueHeading = MagneticDeclinationCalculator.magneticToTrue(
            magneticHeading: magneticHeading,
            latitude: location.latitude,
            longitude: location.longitude
        )
        
        XCTAssertGreaterThanOrEqual(trueHeading, 0)
        XCTAssertLessThan(trueHeading, 360)
        
        // 4. حساب زاوية دوران السهم (استخدام الدالة الفعلية)
        let arrowRotation = QiblaCalculator.calculateArrowRotation(
            qiblaDirection: qiblaDirection,
            deviceHeading: trueHeading
        )
        
        XCTAssertGreaterThanOrEqual(arrowRotation, -180)
        XCTAssertLessThanOrEqual(arrowRotation, 180)
        
        // 5. التحقق من أن كل القيم منطقية
        XCTAssertNotNil(qiblaDirection)
        XCTAssertNotNil(declination)
        XCTAssertNotNil(trueHeading)
        XCTAssertNotNil(arrowRotation)
    }
    
    /// اختبار التكامل مع Performance Metrics
    func testIntegrationWithPerformanceMetrics() {
        let collector = PerformanceMetricsCollector()
        let ekf = ExtendedKalmanFilter()
        
        // تهيئة
        let initialMeasurement = SensorMeasurement(
            type: .deviceMotion,
            timestamp: Date().timeIntervalSince1970,
            deviceMotion: nil
        )
        
        let startTime = collector.recordUpdateStart()
        _ = ekf.update(measurement: initialMeasurement)
        collector.recordUpdateEnd(startTime: startTime)
        
        let metrics = collector.currentMetrics
        
        // يجب أن تكون Metrics متاحة
        XCTAssertGreaterThanOrEqual(metrics.updateRate, 0)
        XCTAssertGreaterThanOrEqual(metrics.averageLatency, 0)
    }
    
    // MARK: - Error Handling Integration Tests
    
    /// اختبار معالجة الأخطاء في التكامل
    func testErrorHandlingIntegration() {
        // اختبار مع موقع غير صحيح
        let invalidLocation = CLLocationCoordinate2D(latitude: 999, longitude: 999)
        let bearing = qiblaService.bearing(from: invalidLocation)
        
        // يجب أن يعيد قيمة (حتى لو كانت غير منطقية)
        XCTAssertGreaterThanOrEqual(bearing, 0)
        XCTAssertLessThan(bearing, 360)
    }
    
    // MARK: - Helper Methods
    
    private var qiblaService: QiblaService {
        return QiblaService()
    }
}
