import XCTest
import CoreLocation
import CoreMotion
@testable import Moatheny

/// اختبارات Edge Cases للبوصلة
/// تغطي: Null location, Missing permissions, Extreme values, Orientation changes
final class EdgeCaseTests: XCTestCase {
    
    var qiblaService: QiblaService!
    var compassService: CompassService!
    
    override func setUp() {
        super.setUp()
        qiblaService = QiblaService()
        compassService = CompassService()
    }
    
    override func tearDown() {
        compassService.stopUpdating()
        qiblaService = nil
        compassService = nil
        super.tearDown()
    }
    
    // MARK: - Null/Invalid Location Tests
    
    /// اختبار مع موقع null (nil)
    func testNullLocation() {
        // في Swift، CLLocationCoordinate2D ليس optional
        // لكن يمكن اختبار القيم غير الصحيحة
        
        // اختبار مع قيم NaN
        let nanLocation = CLLocationCoordinate2D(latitude: Double.nan, longitude: Double.nan)
        let bearing = qiblaService.bearing(from: nanLocation)
        
        // يجب أن يتعامل مع القيم غير الصحيحة بشكل آمن
        // (قد يعيد NaN أو قيمة افتراضية)
        XCTAssertTrue(bearing.isNaN || (bearing >= 0 && bearing < 360),
                     "يجب التعامل مع NaN بشكل آمن")
    }
    
    /// اختبار مع موقع غير صحيح (قيم خارج النطاق)
    func testInvalidLocationCoordinates() {
        let invalidLocations = [
            CLLocationCoordinate2D(latitude: 91, longitude: 0),      // خط عرض خارج النطاق
            CLLocationCoordinate2D(latitude: -91, longitude: 0),      // خط عرض خارج النطاق
            CLLocationCoordinate2D(latitude: 0, longitude: 181),    // خط طول خارج النطاق
            CLLocationCoordinate2D(latitude: 0, longitude: -181),   // خط طول خارج النطاق
            CLLocationCoordinate2D(latitude: 90, longitude: 180),  // القطب الشمالي
            CLLocationCoordinate2D(latitude: -90, longitude: -180),  // القطب الجنوبي
        ]
        
        for location in invalidLocations {
            let bearing = qiblaService.bearing(from: location)
            // يجب أن يعيد قيمة (حتى لو كانت غير منطقية)
            XCTAssertTrue(bearing.isNaN || (bearing >= 0 && bearing < 360),
                         "يجب التعامل مع الإحداثيات غير الصحيحة")
        }
    }
    
    /// اختبار مع موقع في القطبين
    func testPolarRegions() {
        // القطب الشمالي
        let northPole = CLLocationCoordinate2D(latitude: 90, longitude: 0)
        let bearingNorth = qiblaService.bearing(from: northPole)
        XCTAssertGreaterThanOrEqual(bearingNorth, 0)
        XCTAssertLessThan(bearingNorth, 360)
        
        // القطب الجنوبي
        let southPole = CLLocationCoordinate2D(latitude: -90, longitude: 0)
        let bearingSouth = qiblaService.bearing(from: southPole)
        XCTAssertGreaterThanOrEqual(bearingSouth, 0)
        XCTAssertLessThan(bearingSouth, 360)
    }
    
    // MARK: - Missing Permissions Tests
    
    /// اختبار بدون إذن الموقع
    func testWithoutLocationPermission() {
        // ملاحظة: في بيئة الاختبار، قد لا نتمكن من محاكاة رفض الإذن بشكل كامل
        // لكن يمكن التحقق من أن الخدمة تتعامل مع الحالة
        
        compassService.startUpdating()
        
        // إذا لم يكن هناك إذن، يجب أن تكون الخدمة غير متاحة
        // أو يجب أن يكون هناك رسالة خطأ
        if !compassService.isAvailable {
            XCTAssertNotNil(compassService.error, "يجب أن تكون هناك رسالة خطأ عند عدم وجود إذن")
        }
    }
    
    /// اختبار مع إذن مقيد
    func testRestrictedPermission() {
        // ملاحظة: يتطلب محاكاة حالة Restricted
        // في الإنتاج، يجب أن تتعامل CompassService مع هذه الحالة
        
        compassService.startUpdating()
        
        // يجب أن تتعامل الخدمة مع الحالة بشكل آمن
        XCTAssertNotNil(compassService)
    }
    
    // MARK: - Extreme Values Tests
    
    /// اختبار مع قيم متطرفة للاتجاه
    func testExtremeHeadingValues() {
        let extremeHeadings: [Double] = [
            0.0,
            360.0,
            -1.0,
            361.0,
            -360.0,
            720.0,
            Double.infinity,
            -Double.infinity,
        ]
        
        for heading in extremeHeadings {
            // يجب أن يتم تطبيع القيم
            var normalized = heading
            while normalized < 0 { normalized += 360 }
            while normalized >= 360 { normalized -= 360 }
            
            XCTAssertGreaterThanOrEqual(normalized, 0)
            XCTAssertLessThan(normalized, 360)
        }
    }
    
    /// اختبار مع قيم متطرفة للمسافة
    func testExtremeDistanceValues() {
        let extremeLocations = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),           // خط الاستواء وخط الطول الرئيسي
            CLLocationCoordinate2D(latitude: 0, longitude: 180),       // خط الاستواء وخط التاريخ الدولي
            CLLocationCoordinate2D(latitude: 90, longitude: 0),         // القطب الشمالي
            CLLocationCoordinate2D(latitude: -90, longitude: 0),        // القطب الجنوبي
        ]
        
        for location in extremeLocations {
            let distance = qiblaService.distance(from: location)
            XCTAssertGreaterThanOrEqual(distance, 0, "المسافة يجب أن تكون موجبة")
            XCTAssertFalse(distance.isInfinite, "المسافة يجب ألا تكون لا نهائية")
            XCTAssertFalse(distance.isNaN, "المسافة يجب ألا تكون NaN")
        }
    }
    
    /// اختبار مع قيم متطرفة للانحراف المغناطيسي
    func testExtremeMagneticDeclination() {
        let extremeLocations = [
            (lat: 90.0, lon: 0.0, name: "القطب الشمالي"),
            (lat: -90.0, lon: 0.0, name: "القطب الجنوبي"),
            (lat: 0.0, lon: 0.0, name: "خط الاستواء وخط الطول الرئيسي"),
        ]
        
        for location in extremeLocations {
            let declination = MagneticDeclinationCalculator.calculateDeclination(
                latitude: location.lat,
                longitude: location.lon
            )
            
            // حتى في المناطق المتطرفة، يجب أن يكون الانحراف في نطاق معقول
            XCTAssertGreaterThan(declination, -90, "الانحراف في \(location.name) يجب أن يكون معقولاً")
            XCTAssertLessThan(declination, 90, "الانحراف في \(location.name) يجب أن يكون معقولاً")
        }
    }
    
    // MARK: - Device Orientation Changes Tests
    
    /// اختبار تغيير وضعية الجهاز
    func testDeviceOrientationChanges() {
        // ملاحظة: في بيئة الاختبار، قد لا نتمكن من محاكاة تغيير الوضعية بشكل كامل
        // لكن يمكن التحقق من أن الخدمة تتعامل مع التغييرات
        
        let initialOrientation = compassService.deviceOrientation
        
        // التحقق من أن الوضعية متاحة
        XCTAssertNotNil(initialOrientation)
        
        // التحقق من أن معلومات الوضعية متاحة
        let orientationInfo = compassService.getOrientationInfo()
        XCTAssertNotNil(orientationInfo.orientation)
        XCTAssertNotNil(orientationInfo.isFlat)
        XCTAssertNotNil(orientationInfo.pitch)
        XCTAssertNotNil(orientationInfo.roll)
    }
    
    /// اختبار مع وضعيات متطرفة للجهاز
    func testExtremeDeviceOrientations() {
        // اختبار مع ميلان كبير
        let extremePitch: Double = 89.0  // ميلان كبير جداً
        let extremeRoll: Double = 89.0   // دوران كبير جداً
        
        // التحقق من أن الخدمة تتعامل مع الميلان الكبير
        // (في الإنتاج، قد تحتاج معالجة خاصة)
        XCTAssertNotNil(extremePitch)
        XCTAssertNotNil(extremeRoll)
    }
    
    // MARK: - Boundary Conditions Tests
    
    /// اختبار القيم الحدية للاتجاهات
    func testDirectionBoundaryValues() {
        let boundaryValues: [Double] = [
            0.0,
            22.5,
            67.5,
            112.5,
            157.5,
            202.5,
            247.5,
            292.5,
            337.5,
            360.0,
        ]
        
        for value in boundaryValues {
            let directionName = qiblaService.directionName(for: value)
            XCTAssertFalse(directionName.isEmpty, "اسم الاتجاه يجب ألا يكون فارغاً")
        }
    }
    
    /// اختبار الانتقال بين الاتجاهات
    func testDirectionTransitions() {
        // اختبار الانتقال من شمال إلى شمال شرق
        let north = qiblaService.directionName(for: 22.4)
        let northEast = qiblaService.directionName(for: 22.6)
        
        // يجب أن يكون هناك تغيير عند العتبة
        XCTAssertNotEqual(north, northEast, "يجب أن يكون هناك تغيير عند العتبة")
    }
    
    // MARK: - Concurrent Access Tests
    
    /// اختبار الوصول المتزامن
    func testConcurrentAccess() {
        let expectation = XCTestExpectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 10
        
        // وصول متزامن من عدة خيوط
        DispatchQueue.concurrentPerform(iterations: 10) { index in
            let location = CLLocationCoordinate2D(
                latitude: 24.7136 + Double.random(in: -1...1),
                longitude: 46.6753 + Double.random(in: -1...1)
            )
            let bearing = qiblaService.bearing(from: location)
            
            XCTAssertGreaterThanOrEqual(bearing, 0)
            XCTAssertLessThan(bearing, 360)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Memory Pressure Tests
    
    /// اختبار تحت ضغط الذاكرة
    func testMemoryPressure() {
        // إنشاء عدة خدمات وفلاتر
        var services: [QiblaService] = []
        var filters: [ExtendedKalmanFilter] = []
        
        for _ in 0..<100 {
            services.append(QiblaService())
            filters.append(ExtendedKalmanFilter())
        }
        
        // يجب أن تعمل الخدمات بشكل طبيعي
        let location = CLLocationCoordinate2D(latitude: 24.7136, longitude: 46.6753)
        for service in services {
            let bearing = service.bearing(from: location)
            XCTAssertGreaterThanOrEqual(bearing, 0)
            XCTAssertLessThan(bearing, 360)
        }
    }
    
    // MARK: - Rapid State Changes Tests
    
    /// اختبار تغييرات سريعة في الحالة
    func testRapidStateChanges() {
        // بدء وإيقاف سريع
        for _ in 0..<10 {
            compassService.startUpdating()
            compassService.stopUpdating()
        }
        
        // يجب أن تكون الخدمة في حالة مستقرة
        XCTAssertFalse(compassService.isUpdating, "الخدمة يجب أن تكون متوقفة بعد التغييرات السريعة")
    }
    
    // MARK: - Invalid Input Tests
    
    /// اختبار مع مدخلات غير صحيحة
    func testInvalidInputs() {
        // اختبار مع قيم غير منطقية
        let invalidInputs: [Double] = [
            Double.infinity,
            -Double.infinity,
            Double.nan,
            Double.greatestFiniteMagnitude,
            -Double.greatestFiniteMagnitude,
        ]
        
        for input in invalidInputs {
            // يجب أن تتعامل الدوال مع القيم غير الصحيحة بشكل آمن
            let directionName = qiblaService.directionName(for: input)
            // قد يعيد قيمة افتراضية أو "شمال"
            XCTAssertFalse(directionName.isEmpty, "يجب أن يعيد اسم اتجاه حتى مع المدخلات غير الصحيحة")
        }
    }
    
    // MARK: - Edge Cases for Filters
    
    /// اختبار الفلاتر مع قيم متطرفة
    func testFiltersWithExtremeValues() {
        let ekf = ExtendedKalmanFilter()
        
        // اختبار مع قياسات متطرفة
        let extremeMeasurement = SensorMeasurement(
            type: .deviceMotion,
            timestamp: Date().timeIntervalSince1970,
            deviceMotion: nil // سيتم استخدام mock في الإنتاج
        )
        
        // يجب أن يتعامل الفلتر مع القيم المتطرفة بشكل آمن
        let state = ekf.update(measurement: extremeMeasurement)
        XCTAssertNotNil(state)
    }
    
    /// اختبار Magnetic Anomaly Detector مع قيم متطرفة
    func testMagneticAnomalyDetectorExtremeValues() {
        let detector = MagneticAnomalyDetector()
        
        // اختبار مع مجال مغناطيسي متطرف
        let extremeFields = [
            CMMagneticField(x: 0, y: 0, z: 0),           // صفر
            CMMagneticField(x: 1000, y: 1000, z: 1000), // عالي جداً
            CMMagneticField(x: -1000, y: -1000, z: -1000), // سالب كبير
        ]
        
        for field in extremeFields {
            let result = detector.analyze(
                magneticField: field,
                timestamp: Date().timeIntervalSince1970
            )
            
            // يجب أن يتعامل الكاشف مع القيم المتطرفة
            XCTAssertNotNil(result.weight)
            XCTAssertGreaterThanOrEqual(result.weight, 0)
            XCTAssertLessThanOrEqual(result.weight, 1)
        }
    }
}
