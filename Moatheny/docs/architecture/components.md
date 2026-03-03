# Component Diagrams - Compass System

## مخطط المكونات الرئيسية

```
┌─────────────────────────────────────────────────────────────┐
│                      CompassService                         │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  @Published Properties                                │  │
│  │  - heading: Double                                    │  │
│  │  - rawHeading: Double                                 │  │
│  │  - accuracy: Double                                   │  │
│  │  - pitch: Double                                      │  │
│  │  - roll: Double                                       │  │
│  │  - isDeviceFlat: Bool                                 │  │
│  │  - calibrationNeeded: Bool                            │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Core Components                                       │  │
│  │  ┌────────────────┐  ┌──────────────────────────┐   │  │
│  │  │ ExtendedKalman │  │ MagneticAnomaly         │   │  │
│  │  │ Filter         │  │ Detector                 │   │  │
│  │  └────────────────┘  └──────────────────────────┘   │  │
│  │                                                       │  │
│  │  ┌────────────────┐  ┌──────────────────────────┐   │  │
│  │  │ Magnetic       │  │ PerformanceMetrics        │   │  │
│  │  │ Declination    │  │ Collector                │   │  │
│  │  │ Calculator      │  └──────────────────────────┘   │  │
│  │  └────────────────┘                                  │  │
│  │                                                       │  │
│  │  ┌──────────────────────────────────────────────┐   │  │
│  │  │ AdaptiveUpdateRateManager                     │   │  │
│  │  └──────────────────────────────────────────────┘   │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Sensor Managers                                      │  │
│  │  - CLLocationManager                                  │  │
│  │  - CMMotionManager                                    │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Extended Kalman Filter Component

```
┌─────────────────────────────────────────────────────────────┐
│              ExtendedKalmanFilter                          │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  State (6D)                                           │ │
│  │  - roll: Double                                       │ │
│  │  - pitch: Double                                      │ │
│  │  - yaw: Double                                        │ │
│  │  - rollRate: Double                                   │ │
│  │  - pitchRate: Double                                  │ │
│  │  - yawRate: Double                                    │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  Matrices                                             │ │
│  │  - covariance: Matrix (6x6)                          │ │
│  │  - stateTransitionMatrix: Matrix                     │ │
│  │  - measurementMatrix: Matrix                          │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  Methods                                              │ │
│  │  - predict(dt: TimeInterval) -> EKFState             │ │
│  │  - update(measurement: SensorMeasurement) -> EKFState │ │
│  │  - reset()                                            │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                             │
│  Input: SensorMeasurement                                  │
│  Output: Smoothed Heading (Double)                         │
└─────────────────────────────────────────────────────────────┘
```

## Magnetic Anomaly Detector Component

```
┌─────────────────────────────────────────────────────────────┐
│           MagneticAnomalyDetector                          │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  State                                                │ │
│  │  - magnitudeHistory: [Double]                        │ │
│  │  - timestampHistory: [TimeInterval]                   │ │
│  │  - movingAverage: Double                              │ │
│  │  - movingStdDev: Double                               │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  Configuration                                        │ │
│  │  - windowSize: Int (30)                               │ │
│  │  - zScoreThreshold: Double (2.5)                      │ │
│  │  - minNormalMagnitude: Double (15.0 μT)               │ │
│  │  - maxNormalMagnitude: Double (70.0 μT)                │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  Methods                                              │ │
│  │  - analyze(magneticField, timestamp)                  │ │
│  │    -> (weight: Double, isAnomaly: Bool,              │ │
│  │        confidence: Double)                            │ │
│  │  - reset()                                            │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                             │
│  Input: CMMagneticField, TimeInterval                      │
│  Output: Weight, Anomaly Status, Confidence                 │
└─────────────────────────────────────────────────────────────┘
```

## Magnetic Declination Calculator Component

```
┌─────────────────────────────────────────────────────────────┐
│        MagneticDeclinationCalculator                       │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  WMM Coefficients                                    │ │
│  │  - g10, g11, h11: Double                              │ │
│  │  - g10Dot, g11Dot, h11Dot: Double                     │ │
│  │  - epoch: Double (2020.0)                            │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  Cache                                                │ │
│  │  - declinationCache: [String: (declination, timestamp)]│ │
│  │  - cacheValidityDuration: TimeInterval (3600s)       │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  Methods                                              │ │
│  │  - calculateDeclination(lat, lon, date) -> Double    │ │
│  │  - magneticToTrue(magneticHeading, lat, lon)          │ │
│  │    -> Double                                          │ │
│  │  - trueToMagnetic(trueHeading, lat, lon)             │ │
│  │    -> Double                                          │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                             │
│  Input: Latitude, Longitude, Date                          │
│  Output: Declination (degrees)                             │
└─────────────────────────────────────────────────────────────┘
```

## Performance Metrics Collector Component

```
┌─────────────────────────────────────────────────────────────┐
│         PerformanceMetricsCollector                        │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  Metrics Storage                                     │ │
│  │  - updateTimestamps: [Date]                          │ │
│  │  - latencyMeasurements: [TimeInterval]                │ │
│  │  - filterProcessingTimes: [TimeInterval]             │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  Metrics Structure                                   │ │
│  │  - cpuUsage: Double                                   │ │
│  │  - memoryUsage: Int64                                 │ │
│  │  - averageLatency: TimeInterval                       │ │
│  │  - maxLatency: TimeInterval                           │ │
│  │  - updateRate: Double                                 │ │
│  │  - filterProcessingTime: TimeInterval                 │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  Methods                                              │ │
│  │  - recordUpdateStart() -> Date                        │ │
│  │  - recordUpdateEnd(startTime: Date)                   │ │
│  │  - recordFilterProcessing(time: TimeInterval)         │ │
│  │  - currentMetrics -> Metrics                          │ │
│  │  - checkPerformanceBudgets() -> BudgetCheckResult     │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                             │
│  Output: Performance Metrics, Budget Violations             │
└─────────────────────────────────────────────────────────────┘
```

## Adaptive Update Rate Manager Component

```
┌─────────────────────────────────────────────────────────────┐
│         AdaptiveUpdateRateManager                          │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  Motion State                                         │ │
│  │  enum MotionState {                                   │ │
│  │    case stationary      // 5 Hz                       │ │
│  │    case slowMovement    // 15 Hz                      │ │
│  │    case fastMovement    // 30 Hz                      │ │
│  │  }                                                     │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  State                                                │ │
│  │  - headingHistory: [Double]                           │ │
│  │  - headingTimestamps: [Date]                         │ │
│  │  - currentState: MotionState                           │ │
│  │  - lastUpdateTime: Date?                              │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  Methods                                              │ │
│  │  - update(heading, timestamp) -> MotionState         │ │
│  │  - shouldUpdate(timestamp) -> Bool                   │ │
│  │  - reset()                                            │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                             │
│  Input: Heading, Timestamp                                 │
│  Output: MotionState, Update Interval                       │
└─────────────────────────────────────────────────────────────┘
```

## علاقات المكونات

```
CompassService
    │
    ├──→ ExtendedKalmanFilter
    │       └──→ Matrix (math utilities)
    │
    ├──→ MagneticAnomalyDetector
    │       └──→ CMMagneticField (input)
    │
    ├──→ MagneticDeclinationCalculator
    │       └──→ CLLocation (input)
    │
    ├──→ PerformanceMetricsCollector
    │       └──→ Metrics (output)
    │
    ├──→ AdaptiveUpdateRateManager
    │       └──→ MotionState (output)
    │
    ├──→ CLLocationManager
    │       └──→ CLHeading, CLLocation
    │
    └──→ CMMotionManager
            └──→ CMDeviceMotion
```

## التفاعلات بين المكونات

```
┌──────────────┐
│ CompassService│
└──────┬───────┘
       │
       ├─────────────────────────────────────┐
       │                                     │
┌──────▼──────────┐              ┌────────────▼──────────┐
│ EKF             │              │ Anomaly Detector      │
│                 │              │                       │
│ predict()       │              │ analyze()             │
│ update()        │              │ ──────────────────── │
│                 │              │ Returns: weight      │
└──────┬──────────┘              └────────────┬──────────┘
       │                                     │
       │                                     │
       └──────────────┬─────────────────────┘
                      │
              ┌───────▼────────┐
              │ Final Heading  │
              │ (Smoothed)     │
              └───────┬────────┘
                      │
              ┌───────▼────────┐
              │ Declination    │
              │ Calculator     │
              │                │
              │ magneticToTrue()│
              └───────┬────────┘
                      │
              ┌───────▼────────┐
              │ True Heading   │
              │ (Final)        │
              └────────────────┘
```

## المراجع

- [Architecture Overview](./overview.md)
- [Data Flow Diagrams](./data-flow.md)
- [ADR Index](../adr/index.md)
