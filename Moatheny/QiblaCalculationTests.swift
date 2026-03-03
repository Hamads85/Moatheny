import XCTest
import CoreLocation
@testable import Moatheny

/// اختبارات التحقق من دقة حساب اتجاه القبلة
final class QiblaCalculationTests: XCTestCase {
    
    var qiblaService: QiblaService!
    
    override func setUp() {
        super.setUp()
        qiblaService = QiblaService()
    }
    
    /// اختبار الرياض
    func testRiyadhQiblaDirection() {
        let riyadh = CLLocationCoordinate2D(latitude: 24.7136, longitude: 46.6753)
        let bearing = qiblaService.bearing(from: riyadh)
        
        // من الرياض إلى مكة يجب أن يكون الاتجاه تقريباً 243° (غرب-جنوب غرب)
        XCTAssertGreaterThan(bearing, 240)
        XCTAssertLessThan(bearing, 246)
        
        let distance = qiblaService.distance(from: riyadh)
        // المسافة من الرياض إلى مكة تقريباً 870 كم
        XCTAssertGreaterThan(distance, 850)
        XCTAssertLessThan(distance, 900)
    }
    
    /// اختبار جدة
    func testJeddahQiblaDirection() {
        let jeddah = CLLocationCoordinate2D(latitude: 21.4858, longitude: 39.1925)
        let bearing = qiblaService.bearing(from: jeddah)
        
        // من جدة إلى مكة يجب أن يكون الاتجاه تقريباً 60° (شرق-شمال شرق)
        XCTAssertGreaterThan(bearing, 55)
        XCTAssertLessThan(bearing, 65)
        
        let distance = qiblaService.distance(from: jeddah)
        // المسافة من جدة إلى مكة تقريباً 75 كم
        XCTAssertGreaterThan(distance, 70)
        XCTAssertLessThan(distance, 85)
    }
    
    /// اختبار الدمام
    func testDammamQiblaDirection() {
        let dammam = CLLocationCoordinate2D(latitude: 26.4207, longitude: 50.0888)
        let bearing = qiblaService.bearing(from: dammam)
        
        // من الدمام إلى مكة يجب أن يكون الاتجاه تقريباً 240° (جنوب غرب)
        XCTAssertGreaterThan(bearing, 235)
        XCTAssertLessThan(bearing, 245)
        
        let distance = qiblaService.distance(from: dammam)
        // المسافة من الدمام إلى مكة تقريباً 1250 كم
        XCTAssertGreaterThan(distance, 1200)
        XCTAssertLessThan(distance, 1300)
    }
    
    /// اختبار القاهرة
    func testCairoQiblaDirection() {
        let cairo = CLLocationCoordinate2D(latitude: 30.0444, longitude: 31.2357)
        let bearing = qiblaService.bearing(from: cairo)
        
        // من القاهرة إلى مكة يجب أن يكون الاتجاه تقريباً 135° (جنوب شرق)
        XCTAssertGreaterThan(bearing, 130)
        XCTAssertLessThan(bearing, 140)
    }
    
    /// اختبار دبي
    func testDubaiQiblaDirection() {
        let dubai = CLLocationCoordinate2D(latitude: 25.2048, longitude: 55.2708)
        let bearing = qiblaService.bearing(from: dubai)
        
        // من دبي إلى مكة يجب أن يكون الاتجاه تقريباً 258° (غرب)
        XCTAssertGreaterThan(bearing, 253)
        XCTAssertLessThan(bearing, 263)
    }
    
    /// اختبار مكة نفسها (يجب أن تكون المسافة صفر تقريباً)
    func testMakkahItself() {
        let makkah = CLLocationCoordinate2D(latitude: 21.422487, longitude: 39.826206)
        let distance = qiblaService.distance(from: makkah)
        
        // المسافة يجب أن تكون أقل من 1 كم (في مكة نفسها)
        XCTAssertLessThan(distance, 1)
    }
    
    /// اختبار الاتجاه يجب أن يكون بين 0-360
    func testBearingRange() {
        let randomLocations = [
            CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060), // نيويورك
            CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),  // لندن
            CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093), // سيدني
            CLLocationCoordinate2D(latitude: 1.3521, longitude: 103.8198),  // سنغافورة
        ]
        
        for location in randomLocations {
            let bearing = qiblaService.bearing(from: location)
            XCTAssertGreaterThanOrEqual(bearing, 0)
            XCTAssertLessThan(bearing, 360)
        }
    }
    
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
}

