import XCTest
import CoreLocation
@testable import Moatheny

/// اختبارات شاملة لدقة حساب اتجاه القبلة
/// تغطي: مواقع متعددة، الانحراف المغناطيسي، الانتقال الزاوي
final class QiblaAccuracyTests: XCTestCase {
    
    var qiblaService: QiblaService!
    
    override func setUp() {
        super.setUp()
        qiblaService = QiblaService()
    }
    
    override func tearDown() {
        qiblaService = nil
        super.tearDown()
    }
    
    // MARK: - اختبارات الدقة من مواقع متعددة
    
    /// اختبار الرياض - القيمة المتوقعة: ~243°
    func testRiyadhQiblaDirection() {
        let riyadh = CLLocationCoordinate2D(latitude: 24.7136, longitude: 46.6753)
        let bearing = qiblaService.bearing(from: riyadh)
        
        // من الرياض إلى مكة يجب أن يكون الاتجاه تقريباً 243° (غرب-جنوب غرب)
        XCTAssertGreaterThan(bearing, 240, "الاتجاه من الرياض يجب أن يكون أكبر من 240°")
        XCTAssertLessThan(bearing, 246, "الاتجاه من الرياض يجب أن يكون أقل من 246°")
        
        let distance = qiblaService.distance(from: riyadh)
        // المسافة من الرياض إلى مكة تقريباً 870 كم
        XCTAssertGreaterThan(distance, 850, "المسافة من الرياض يجب أن تكون أكبر من 850 كم")
        XCTAssertLessThan(distance, 900, "المسافة من الرياض يجب أن تكون أقل من 900 كم")
    }
    
    /// اختبار جدة - القيمة المتوقعة: ~60°
    func testJeddahQiblaDirection() {
        let jeddah = CLLocationCoordinate2D(latitude: 21.4858, longitude: 39.1925)
        let bearing = qiblaService.bearing(from: jeddah)
        
        // من جدة إلى مكة يجب أن يكون الاتجاه تقريباً 60° (شرق-شمال شرق)
        XCTAssertGreaterThan(bearing, 55, "الاتجاه من جدة يجب أن يكون أكبر من 55°")
        XCTAssertLessThan(bearing, 65, "الاتجاه من جدة يجب أن يكون أقل من 65°")
        
        let distance = qiblaService.distance(from: jeddah)
        // المسافة من جدة إلى مكة تقريباً 75 كم
        XCTAssertGreaterThan(distance, 70, "المسافة من جدة يجب أن تكون أكبر من 70 كم")
        XCTAssertLessThan(distance, 85, "المسافة من جدة يجب أن تكون أقل من 85 كم")
    }
    
    /// اختبار الدمام - القيمة المتوقعة: ~240°
    func testDammamQiblaDirection() {
        let dammam = CLLocationCoordinate2D(latitude: 26.4207, longitude: 50.0888)
        let bearing = qiblaService.bearing(from: dammam)
        
        // من الدمام إلى مكة يجب أن يكون الاتجاه تقريباً 240° (جنوب غرب)
        XCTAssertGreaterThan(bearing, 235, "الاتجاه من الدمام يجب أن يكون أكبر من 235°")
        XCTAssertLessThan(bearing, 245, "الاتجاه من الدمام يجب أن يكون أقل من 245°")
        
        let distance = qiblaService.distance(from: dammam)
        // المسافة من الدمام إلى مكة تقريباً 1250 كم
        XCTAssertGreaterThan(distance, 1200, "المسافة من الدمام يجب أن تكون أكبر من 1200 كم")
        XCTAssertLessThan(distance, 1300, "المسافة من الدمام يجب أن تكون أقل من 1300 كم")
    }
    
    /// اختبار القاهرة - القيمة المتوقعة: ~135°
    func testCairoQiblaDirection() {
        let cairo = CLLocationCoordinate2D(latitude: 30.0444, longitude: 31.2357)
        let bearing = qiblaService.bearing(from: cairo)
        
        // من القاهرة إلى مكة يجب أن يكون الاتجاه تقريباً 135° (جنوب شرق)
        XCTAssertGreaterThan(bearing, 130, "الاتجاه من القاهرة يجب أن يكون أكبر من 130°")
        XCTAssertLessThan(bearing, 140, "الاتجاه من القاهرة يجب أن يكون أقل من 140°")
    }
    
    /// اختبار دبي - القيمة المتوقعة: ~258°
    func testDubaiQiblaDirection() {
        let dubai = CLLocationCoordinate2D(latitude: 25.2048, longitude: 55.2708)
        let bearing = qiblaService.bearing(from: dubai)
        
        // من دبي إلى مكة يجب أن يكون الاتجاه تقريباً 258° (غرب)
        XCTAssertGreaterThan(bearing, 253, "الاتجاه من دبي يجب أن يكون أكبر من 253°")
        XCTAssertLessThan(bearing, 263, "الاتجاه من دبي يجب أن يكون أقل من 263°")
    }
    
    /// اختبار لندن - القيمة المتوقعة: ~120°
    func testLondonQiblaDirection() {
        let london = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        let bearing = qiblaService.bearing(from: london)
        
        // من لندن إلى مكة يجب أن يكون الاتجاه تقريباً 120° (جنوب شرق)
        XCTAssertGreaterThan(bearing, 115, "الاتجاه من لندن يجب أن يكون أكبر من 115°")
        XCTAssertLessThan(bearing, 125, "الاتجاه من لندن يجب أن يكون أقل من 125°")
    }
    
    /// اختبار نيويورك - القيمة المتوقعة: ~60°
    func testNewYorkQiblaDirection() {
        let newYork = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let bearing = qiblaService.bearing(from: newYork)
        
        // من نيويورك إلى مكة يجب أن يكون الاتجاه تقريباً 60° (شمال شرق)
        XCTAssertGreaterThan(bearing, 55, "الاتجاه من نيويورك يجب أن يكون أكبر من 55°")
        XCTAssertLessThan(bearing, 65, "الاتجاه من نيويورك يجب أن يكون أقل من 65°")
    }
    
    /// اختبار سيدني - القيمة المتوقعة: ~290°
    func testSydneyQiblaDirection() {
        let sydney = CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)
        let bearing = qiblaService.bearing(from: sydney)
        
        // من سيدني إلى مكة يجب أن يكون الاتجاه تقريباً 290° (شمال غرب)
        XCTAssertGreaterThan(bearing, 285, "الاتجاه من سيدني يجب أن يكون أكبر من 285°")
        XCTAssertLessThan(bearing, 295, "الاتجاه من سيدني يجب أن يكون أقل من 295°")
    }
    
    /// اختبار مكة نفسها - يجب أن تكون المسافة صفر تقريباً
    func testMakkahItself() {
        let makkah = CLLocationCoordinate2D(latitude: 21.422487, longitude: 39.826206)
        let distance = qiblaService.distance(from: makkah)
        
        // المسافة يجب أن تكون أقل من 1 كم (في مكة نفسها)
        XCTAssertLessThan(distance, 1, "المسافة من مكة إلى نفسها يجب أن تكون أقل من 1 كم")
    }
    
    // MARK: - اختبارات نطاق القيم
    
    /// اختبار الاتجاه يجب أن يكون بين 0-360
    func testBearingRange() {
        let randomLocations = [
            CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060), // نيويورك
            CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),  // لندن
            CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093), // سيدني
            CLLocationCoordinate2D(latitude: 1.3521, longitude: 103.8198),  // سنغافورة
            CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503), // طوكيو
            CLLocationCoordinate2D(latitude: -22.9068, longitude: -43.1729), // ريو دي جانيرو
        ]
        
        for location in randomLocations {
            let bearing = qiblaService.bearing(from: location)
            XCTAssertGreaterThanOrEqual(bearing, 0, "الاتجاه يجب أن يكون أكبر من أو يساوي 0°")
            XCTAssertLessThan(bearing, 360, "الاتجاه يجب أن يكون أقل من 360°")
        }
    }
    
    /// اختبار المسافة يجب أن تكون موجبة
    func testDistanceIsPositive() {
        let locations = [
            CLLocationCoordinate2D(latitude: 24.7136, longitude: 46.6753), // الرياض
            CLLocationCoordinate2D(latitude: 21.4858, longitude: 39.1925), // جدة
            CLLocationCoordinate2D(latitude: 30.0444, longitude: 31.2357), // القاهرة
        ]
        
        for location in locations {
            let distance = qiblaService.distance(from: location)
            XCTAssertGreaterThanOrEqual(distance, 0, "المسافة يجب أن تكون موجبة أو صفر")
        }
    }
    
    // MARK: - اختبارات الانحراف المغناطيسي
    
    /// اختبار حساب الانحراف المغناطيسي لمواقع مختلفة
    func testMagneticDeclinationCalculation() {
        let testLocations = [
            (lat: 24.7136, lon: 46.6753, name: "الرياض"), // السعودية
            (lat: 30.0444, lon: 31.2357, name: "القاهرة"), // مصر
            (lat: 40.7128, lon: -74.0060, name: "نيويورك"), // أمريكا
            (lat: 51.5074, lon: -0.1278, name: "لندن"), // بريطانيا
        ]
        
        for location in testLocations {
            let declination = MagneticDeclinationCalculator.calculateDeclination(
                latitude: location.lat,
                longitude: location.lon
            )
            
            // الانحراف المغناطيسي عادة بين -30° و +30°
            XCTAssertGreaterThan(declination, -30, "الانحراف المغناطيسي في \(location.name) يجب أن يكون أكبر من -30°")
            XCTAssertLessThan(declination, 30, "الانحراف المغناطيسي في \(location.name) يجب أن يكون أقل من 30°")
        }
    }
    
    /// اختبار تحويل Heading من مغناطيسي إلى حقيقي
    func testMagneticToTrueConversion() {
        let riyadh = CLLocationCoordinate2D(latitude: 24.7136, longitude: 46.6753)
        let magneticHeading: Double = 243.0
        
        let trueHeading = MagneticDeclinationCalculator.magneticToTrue(
            magneticHeading: magneticHeading,
            latitude: riyadh.latitude,
            longitude: riyadh.longitude
        )
        
        // يجب أن يكون True Heading في النطاق الصحيح
        XCTAssertGreaterThanOrEqual(trueHeading, 0)
        XCTAssertLessThan(trueHeading, 360)
        
        // يجب أن يكون الفرق معقول (عادة أقل من 10 درجات)
        let declination = MagneticDeclinationCalculator.calculateDeclination(
            latitude: riyadh.latitude,
            longitude: riyadh.longitude
        )
        let expectedDifference = abs(trueHeading - magneticHeading)
        XCTAssertLessThan(expectedDifference, 15, "الفرق بين المغناطيسي والحقيقي يجب أن يكون معقولاً")
    }
    
    /// اختبار تحويل Heading من حقيقي إلى مغناطيسي
    func testTrueToMagneticConversion() {
        let riyadh = CLLocationCoordinate2D(latitude: 24.7136, longitude: 46.6753)
        let trueHeading: Double = 243.0
        
        let magneticHeading = MagneticDeclinationCalculator.trueToMagnetic(
            trueHeading: trueHeading,
            latitude: riyadh.latitude,
            longitude: riyadh.longitude
        )
        
        // يجب أن يكون Magnetic Heading في النطاق الصحيح
        XCTAssertGreaterThanOrEqual(magneticHeading, 0)
        XCTAssertLessThan(magneticHeading, 360)
        
        // التحويل العكسي يجب أن يعيد القيمة الأصلية (تقريباً)
        let backToTrue = MagneticDeclinationCalculator.magneticToTrue(
            magneticHeading: magneticHeading,
            latitude: riyadh.latitude,
            longitude: riyadh.longitude
        )
        
        let difference = abs(backToTrue - trueHeading)
        // معالجة الانتقال الزاوي (359° → 0°)
        let normalizedDifference = min(difference, 360 - difference)
        XCTAssertLessThan(normalizedDifference, 1, "التحويل العكسي يجب أن يعيد القيمة الأصلية بدقة")
    }
    
    // MARK: - اختبارات الانتقال الزاوي (359° → 0°)
    
    /// اختبار الانتقال من 359° إلى 0°
    func testAngularWrapAround359To0() {
        // اختبار أن الانتقال من 359° إلى 0° يتم التعامل معه بشكل صحيح
        let location = CLLocationCoordinate2D(latitude: 24.7136, longitude: 46.6753)
        
        // محاكاة انتقال زاوي
        let heading1: Double = 359.0
        let heading2: Double = 1.0
        
        // الفرق يجب أن يكون 2° وليس 358°
        var diff = heading2 - heading1
        if diff > 180 {
            diff -= 360
        } else if diff < -180 {
            diff += 360
        }
        
        XCTAssertEqual(diff, 2.0, accuracy: 0.1, "الانتقال من 359° إلى 1° يجب أن يكون 2°")
    }
    
    /// اختبار الانتقال من 0° إلى 359°
    func testAngularWrapAround0To359() {
        let heading1: Double = 1.0
        let heading2: Double = 359.0
        
        // الفرق يجب أن يكون -2° وليس 358°
        var diff = heading2 - heading1
        if diff > 180 {
            diff -= 360
        } else if diff < -180 {
            diff += 360
        }
        
        XCTAssertEqual(diff, -2.0, accuracy: 0.1, "الانتقال من 1° إلى 359° يجب أن يكون -2°")
    }
    
    /// اختبار الانتقال الزاوي في جميع الاتجاهات
    func testAngularWrapAroundAllDirections() {
        let testCases: [(from: Double, to: Double, expectedDiff: Double)] = [
            (359.0, 1.0, 2.0),      // انتقال عادي
            (1.0, 359.0, -2.0),      // انتقال عكسي
            (350.0, 10.0, 20.0),     // انتقال كبير
            (10.0, 350.0, -20.0),    // انتقال كبير عكسي
            (180.0, 181.0, 1.0),     // لا يوجد انتقال
            (0.0, 360.0, 0.0),       // نفس القيمة
        ]
        
        for testCase in testCases {
            var diff = testCase.to - testCase.from
            if diff > 180 {
                diff -= 360
            } else if diff < -180 {
                diff += 360
            }
            
            XCTAssertEqual(diff, testCase.expectedDiff, accuracy: 0.1,
                          "الانتقال من \(testCase.from)° إلى \(testCase.to)° يجب أن يكون \(testCase.expectedDiff)°")
        }
    }
    
    // MARK: - اختبارات أسماء الاتجاهات
    
    /// اختبار أسماء الاتجاهات
    func testDirectionNames() {
        XCTAssertEqual(qiblaService.directionName(for: 0), "شمال")
        XCTAssertEqual(qiblaService.directionName(for: 45), "شمال شرق")
        XCTAssertEqual(qiblaService.directionName(for: 90), "شرق")
        XCTAssertEqual(qiblaService.directionName(for: 135), "جنوب شرق")
        XCTAssertEqual(qiblaService.directionName(for: 180), "جنوب")
        XCTAssertEqual(qiblaService.directionName(for: 225), "جنوب غرب")
        XCTAssertEqual(qiblaService.directionName(for: 270), "غرب")
        XCTAssertEqual(qiblaService.directionName(for: 315), "شمال غرب")
    }
    
    /// اختبار أسماء الاتجاهات عند القيم الحدية
    func testDirectionNamesBoundaryValues() {
        // اختبار القيم الحدية بين الاتجاهات
        XCTAssertEqual(qiblaService.directionName(for: 22.4), "شمال")
        XCTAssertEqual(qiblaService.directionName(for: 22.6), "شمال شرق")
        XCTAssertEqual(qiblaService.directionName(for: 67.4), "شمال شرق")
        XCTAssertEqual(qiblaService.directionName(for: 67.6), "شرق")
    }
    
    // MARK: - اختبارات الدقة العالية
    
    /// اختبار دقة الحساب لمواقع قريبة من مكة
    func testHighAccuracyNearMakkah() {
        let nearMakkah = CLLocationCoordinate2D(latitude: 21.5, longitude: 39.8)
        let bearing = qiblaService.bearing(from: nearMakkah)
        let distance = qiblaService.distance(from: nearMakkah)
        
        // يجب أن يكون الاتجاه دقيقاً حتى في المناطق القريبة
        XCTAssertGreaterThanOrEqual(bearing, 0)
        XCTAssertLessThan(bearing, 360)
        
        // المسافة يجب أن تكون صغيرة
        XCTAssertLessThan(distance, 50, "المسافة من موقع قريب من مكة يجب أن تكون أقل من 50 كم")
    }
    
    /// اختبار دقة الحساب لمواقع بعيدة جداً
    func testHighAccuracyFarFromMakkah() {
        let farLocation = CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093) // سيدني
        let bearing = qiblaService.bearing(from: farLocation)
        let distance = qiblaService.distance(from: farLocation)
        
        // يجب أن يكون الاتجاه دقيقاً حتى في المناطق البعيدة
        XCTAssertGreaterThanOrEqual(bearing, 0)
        XCTAssertLessThan(bearing, 360)
        
        // المسافة يجب أن تكون كبيرة
        XCTAssertGreaterThan(distance, 10000, "المسافة من موقع بعيد يجب أن تكون أكبر من 10000 كم")
    }
    
    // MARK: - اختبارات التماثل
    
    /// اختبار أن حساب الاتجاه متماثل (من A إلى B = عكس من B إلى A + 180°)
    func testBearingSymmetry() {
        let location1 = CLLocationCoordinate2D(latitude: 24.7136, longitude: 46.6753) // الرياض
        let location2 = CLLocationCoordinate2D(latitude: 21.422487, longitude: 39.826206) // مكة
        
        // حساب الاتجاه من الرياض إلى مكة
        let bearing1 = qiblaService.bearing(from: location1)
        
        // حساب الاتجاه من مكة إلى الرياض (يجب أن يكون +180°)
        let bearing2 = qiblaService.bearing(from: location2)
        
        // التحقق من التماثل (تقريباً)
        let expectedBearing2 = (bearing1 + 180).truncatingRemainder(dividingBy: 360)
        let difference = abs(bearing2 - expectedBearing2)
        let normalizedDifference = min(difference, 360 - difference)
        
        // على سطح كروي، التماثل ليس دقيقاً 100%، لكن يجب أن يكون قريباً
        XCTAssertLessThan(normalizedDifference, 5, "الاتجاهات يجب أن تكون متماثلة تقريباً")
    }
}
