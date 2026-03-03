# Coding Standards - Compass System

## Swift Style Guide

### Naming Conventions

#### Classes and Structs
```swift
// ✅ PascalCase
final class CompassService: NSObject, ObservableObject { }
struct EKFState { }

// ❌ snake_case أو camelCase
class compass_service { }
struct ekf_state { }
```

#### Functions and Variables
```swift
// ✅ camelCase
func startUpdating() { }
var heading: Double = 0

// ❌ PascalCase أو snake_case
func StartUpdating() { }
var Heading: Double = 0
```

#### Constants
```swift
// ✅ camelCase
private let optimalHeadingFilter: CLLocationDirection = 1.0

// ❌ SCREAMING_SNAKE_CASE
private let OPTIMAL_HEADING_FILTER: CLLocationDirection = 1.0
```

#### Enums
```swift
// ✅ PascalCase
enum MotionState {
    case stationary
    case slowMovement
    case fastMovement
}

// ❌ camelCase
enum motionState { }
```

### Code Organization

#### File Structure
```swift
// 1. Imports
import Foundation
import CoreLocation
import CoreMotion

// 2. Type Definition
final class CompassService: NSObject, ObservableObject {
    
    // 3. MARK: - Published Properties
    @Published var heading: Double = 0
    
    // 4. MARK: - Private Properties
    private let locationManager = CLLocationManager()
    
    // 5. MARK: - Initialization
    override init() {
        // ...
    }
    
    // 6. MARK: - Public Methods
    func startUpdating() {
        // ...
    }
    
    // 7. MARK: - Private Methods
    private func processHeading(_ heading: Double) {
        // ...
    }
}

// 8. MARK: - Extensions
extension CompassService: CLLocationManagerDelegate {
    // ...
}
```

#### MARK Comments
```swift
// MARK: - Properties
// MARK: - Initialization
// MARK: - Public Methods
// MARK: - Private Methods
// MARK: - Helpers
```

### Documentation

#### Function Documentation
```swift
/// وصف مختصر للدالة
///
/// وصف تفصيلي إذا لزم.
///
/// - Parameters:
///   - heading: الاتجاه بالدرجات (0-360)
///   - timestamp: timestamp القراءة
/// - Returns: الاتجاه المنعم بالدرجات
/// - Throws: `CompassError` إذا فشلت المعالجة
func processHeading(_ heading: Double, timestamp: TimeInterval) throws -> Double {
    // ...
}
```

#### Class Documentation
```swift
/// Extended Kalman Filter للبوصلة
///
/// يستخدم هذا الفلتر لتنعيم قراءات البوصلة ودمج المستشعرات.
/// يدعم حالة 6D (Roll, Pitch, Yaw + Rates).
final class ExtendedKalmanFilter {
    // ...
}
```

### Error Handling

#### Use Result Type
```swift
// ✅ جيد
func calculateHeading() -> Result<Double, CompassError> {
    // ...
}

// ❌ سيء
func calculateHeading() throws -> Double {
    // ...
}
```

#### Specific Error Types
```swift
enum CompassError: Error {
    case calibrationNeeded
    case interferenceDetected
    case locationUnavailable
    case sensorUnavailable
}
```

### Access Control

#### Use `final` for Classes
```swift
// ✅ جيد
final class CompassService { }

// ❌ سيء
class CompassService { }
```

#### Use `private` by Default
```swift
// ✅ جيد
private let locationManager = CLLocationManager()
private func processHeading(_ heading: Double) { }

// ❌ سيء
let locationManager = CLLocationManager()
func processHeading(_ heading: Double) { }
```

### Performance

#### Avoid Force Unwrapping
```swift
// ✅ جيد
guard let heading = optionalHeading else { return }
// أو
if let heading = optionalHeading {
    // ...
}

// ❌ سيء
let heading = optionalHeading!
```

#### Use Weak References
```swift
// ✅ جيد
adaptiveUpdateRate.onStateChanged = { [weak self] state in
    self?.updateMotionManagerInterval(for: state)
}

// ❌ سيء
adaptiveUpdateRate.onStateChanged = { state in
    self.updateMotionManagerInterval(for: state)
}
```

#### Background Processing
```swift
// ✅ جيد
filterProcessingQueue.async { [weak self] in
    guard let self = self else { return }
    // Process on background queue
}

// ❌ سيء
// Process on main queue
```

### Testing

#### Test Naming
```swift
// ✅ جيد
func testEKFInitializesCorrectly() { }
func testAnomalyDetectorDetectsInterference() { }

// ❌ سيء
func test1() { }
func testEKF() { }
```

#### Arrange-Act-Assert
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

## Architecture Standards

### SOLID Principles

#### Single Responsibility
```swift
// ✅ جيد - كل class له مسؤولية واحدة
final class ExtendedKalmanFilter { }  // Filtering only
final class MagneticAnomalyDetector { }  // Detection only

// ❌ سيء - class واحد يقوم بأشياء متعددة
final class CompassProcessor {
    func filter() { }
    func detect() { }
    func calculate() { }
}
```

#### Dependency Injection
```swift
// ✅ جيد
final class CompassService {
    private let ekf: ExtendedKalmanFilter
    private let detector: MagneticAnomalyDetector
    
    init(ekf: ExtendedKalmanFilter, detector: MagneticAnomalyDetector) {
        self.ekf = ekf
        self.detector = detector
    }
}

// ❌ سيء
final class CompassService {
    private let ekf = ExtendedKalmanFilter()
    private let detector = MagneticAnomalyDetector()
}
```

### Protocols

#### Use Protocols for Abstraction
```swift
// ✅ جيد
protocol FilterProtocol {
    func update(measurement: SensorMeasurement) -> Double
    func reset()
}

final class ExtendedKalmanFilter: FilterProtocol {
    // ...
}
```

## Documentation Standards

### README Files
- يجب أن تحتوي على نظرة عامة
- أمثلة استخدام
- تعليمات الإعداد

### Code Comments
- اشرح الـ "لماذا" وليس الـ "ماذا"
- استخدم التعليقات للسياق المعقد
- تجنب التعليقات الواضحة

### ADRs
- استخدم Template القياسي
- املأ جميع الأقسام
- أضف المراجع

## المراجع

- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- [Contribution Guidelines](../guides/contributing.md)
