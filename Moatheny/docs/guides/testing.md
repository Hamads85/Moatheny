# Testing Guide - Compass System

## نظرة عامة

هذا الدليل يشرح كيفية كتابة وتشغيل الاختبارات لنظام البوصلة.

## أنواع الاختبارات

### 1. Unit Tests

اختبارات للمكونات الفردية.

**الموقع:** `MoathenyTests/`

**مثال:**
```swift
import XCTest
@testable import Moatheny

final class ExtendedKalmanFilterTests: XCTestCase {
    var ekf: ExtendedKalmanFilter!
    
    override func setUp() {
        super.setUp()
        ekf = ExtendedKalmanFilter(
            processNoise: 0.01,
            measurementNoise: 0.1
        )
    }
    
    override func tearDown() {
        ekf = nil
        super.tearDown()
    }
    
    func testInitialization() {
        XCTAssertFalse(ekf.isInitialized)
        XCTAssertNotNil(ekf.state)
    }
    
    func testUpdate() {
        var measurement = SensorMeasurement(
            type: .magnetometer,
            timestamp: Date().timeIntervalSince1970
        )
        measurement.magneticField = CMMagneticField(x: 1, y: 0, z: 0)
        
        let state = ekf.update(measurement: measurement)
        
        XCTAssertTrue(ekf.isInitialized)
        XCTAssertNotNil(state)
    }
    
    func testReset() {
        // Initialize first
        var measurement = SensorMeasurement(...)
        _ = ekf.update(measurement: measurement)
        XCTAssertTrue(ekf.isInitialized)
        
        // Reset
        ekf.reset()
        XCTAssertFalse(ekf.isInitialized)
    }
}
```

### 2. Integration Tests

اختبارات للتكامل بين المكونات.

**الموقع:** `MoathenyTests/IntegrationTests.swift`

**مثال:**
```swift
final class CompassIntegrationTests: XCTestCase {
    var compass: CompassService!
    
    override func setUp() {
        super.setUp()
        compass = CompassService()
    }
    
    func testCompassWithAllComponents() {
        let expectation = expectation(description: "Heading updated")
        
        compass.startUpdating()
        
        // Wait for heading update
        var observation: NSKeyValueObservation?
        observation = compass.observe(\.heading, options: [.new]) { _, _ in
            expectation.fulfill()
            observation?.invalidate()
        }
        
        waitForExpectations(timeout: 5.0)
        
        XCTAssertGreaterThanOrEqual(compass.heading, 0)
        XCTAssertLessThan(compass.heading, 360)
    }
}
```

### 3. Performance Tests

اختبارات للأداء.

**مثال:**
```swift
final class PerformanceTests: XCTestCase {
    func testEKFPerformance() {
        let ekf = ExtendedKalmanFilter()
        var measurement = SensorMeasurement(...)
        
        measure {
            for _ in 0..<1000 {
                _ = ekf.update(measurement: measurement)
            }
        }
    }
    
    func testAnomalyDetectorPerformance() {
        let detector = MagneticAnomalyDetector()
        let field = CMMagneticField(x: 1, y: 0, z: 0)
        
        measure {
            for _ in 0..<1000 {
                _ = detector.analyze(magneticField: field, timestamp: Date().timeIntervalSince1970)
            }
        }
    }
}
```

### 4. Edge Case Tests

اختبارات للحالات الحدية.

**الموقع:** `MoathenyTests/EdgeCaseTests.swift`

**مثال:**
```swift
final class EdgeCaseTests: XCTestCase {
    func testAngleNormalization() {
        let calculator = MagneticDeclinationCalculator()
        
        // Test 359° → 0° transition
        let heading1 = 359.0
        let heading2 = 1.0
        let diff = abs(heading2 - heading1)
        
        // Should handle circular transition
        XCTAssertLessThan(diff, 5.0)  // Small difference
    }
    
    func testExtremeDeclination() {
        // Test at magnetic poles
        let declination = MagneticDeclinationCalculator.calculateDeclination(
            latitude: 80.0,  // Near North Pole
            longitude: 0.0
        )
        
        // Declination should be reasonable
        XCTAssertGreaterThanOrEqual(declination, -30)
        XCTAssertLessThanOrEqual(declination, 30)
    }
}
```

## تشغيل الاختبارات

### من Xcode

1. اضغط **⌘U** لتشغيل جميع الاختبارات
2. أو اضغط على زر Play بجانب Test function

### من Terminal

```bash
# جميع الاختبارات
xcodebuild test -scheme Moatheny -destination 'platform=iOS Simulator,name=iPhone 15'

# Test محدد
xcodebuild test -scheme Moatheny -only-testing:MoathenyTests/ExtendedKalmanFilterTests/testUpdate

# Test class محدد
xcodebuild test -scheme Moatheny -only-testing:MoathenyTests/ExtendedKalmanFilterTests
```

## Mocking

### Mock CompassService

```swift
class MockCompassService: CompassService {
    var mockHeading: Double = 0
    var mockAccuracy: Double = -1
    
    override var heading: Double {
        get { mockHeading }
        set { mockHeading = newValue }
    }
    
    override var accuracy: Double {
        get { mockAccuracy }
        set { mockAccuracy = newValue }
    }
}
```

### Mock Location Manager

```swift
class MockLocationManager: CLLocationManager {
    var mockAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    var mockHeadingAvailable: Bool = true
    
    override var authorizationStatus: CLAuthorizationStatus {
        return mockAuthorizationStatus
    }
    
    override class func headingAvailable() -> Bool {
        return mockHeadingAvailable
    }
}
```

## Test Coverage

### فحص Coverage

```bash
# في Xcode:
# Product > Scheme > Edit Scheme
# Test > Options > Code Coverage: ✅
# ثم شغّل Tests
```

### الهدف

- **Unit Tests**: > 80% coverage
- **Integration Tests**: تغطية المسارات الرئيسية
- **Edge Cases**: تغطية الحالات الحدية

## Best Practices

### 1. Arrange-Act-Assert

```swift
func testExample() {
    // Arrange
    let ekf = ExtendedKalmanFilter()
    var measurement = SensorMeasurement(...)
    
    // Act
    let state = ekf.update(measurement: measurement)
    
    // Assert
    XCTAssertTrue(ekf.isInitialized)
    XCTAssertNotNil(state)
}
```

### 2. Test One Thing

```swift
// ✅ جيد
func testInitialization() { ... }
func testUpdate() { ... }
func testReset() { ... }

// ❌ سيء
func testEverything() {
    // Tests multiple things
}
```

### 3. Use Descriptive Names

```swift
// ✅ جيد
func testEKFInitializesCorrectly() { ... }
func testAnomalyDetectorDetectsInterference() { ... }

// ❌ سيء
func test1() { ... }
func testEKF() { ... }
```

### 4. Clean Up

```swift
override func tearDown() {
    // Clean up resources
    ekf = nil
    detector = nil
    super.tearDown()
}
```

## الاختبارات الموجودة

### Unit Tests

- `ExtendedKalmanFilterTests.swift`
- `MagneticAnomalyDetectorTests.swift`
- `MagneticDeclinationCalculatorTests.swift`
- `PerformanceMetricsCollectorTests.swift`
- `AdaptiveUpdateRateManagerTests.swift`

### Integration Tests

- `CompassIntegrationTests.swift`
- `QiblaCalculationTests.swift`

### Performance Tests

- `PerformanceTests.swift`

### Edge Case Tests

- `EdgeCaseTests.swift`
- `FilterTests.swift`

## إضافة Tests جديدة

### 1. إنشاء Test File

```swift
import XCTest
@testable import Moatheny

final class YourComponentTests: XCTestCase {
    // Tests here
}
```

### 2. إضافة Tests

```swift
func testYourFeature() {
    // Arrange
    // Act
    // Assert
}
```

### 3. تشغيل Tests

```bash
xcodebuild test -scheme Moatheny -only-testing:MoathenyTests/YourComponentTests
```

## المراجع

- [Setup Instructions](./setup.md)
- [Contribution Guidelines](./contributing.md)
- [API Documentation](../api/interfaces.md)
