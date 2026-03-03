# Data Flow Diagrams - Compass System

## تدفق البيانات الرئيسي

```
┌──────────────────────────────────────────────────────────────┐
│                    Sensor Input Layer                        │
└──────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
┌───────▼──────┐   ┌────────▼────────┐  ┌──────▼──────┐
│ CoreLocation │   │  CoreMotion     │  │  Location   │
│              │   │                 │  │  (GPS)      │
│ CLHeading    │   │ CMDeviceMotion  │  │             │
│ - magnetic   │   │ - attitude      │  │ CLLocation  │
│ - true       │   │ - rotationRate  │  │ - lat/lon   │
│ - accuracy   │   │ - magneticField │  │             │
└───────┬──────┘   └────────┬────────┘  └──────┬──────┘
        │                   │                   │
        └───────────────────┼───────────────────┘
                            │
┌───────────────────────────▼───────────────────────────────┐
│              CompassService                              │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Input Processing                                  │  │
│  │  - Extract heading from motion                    │  │
│  │  - Validate readings                              │  │
│  │  - Apply throttling                                │  │
│  └────────────────────────────────────────────────────┘  │
└───────────────────────────┬───────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
┌───────▼──────┐   ┌────────▼────────┐  ┌──────▼──────┐
│   EKF        │   │  Anomaly       │  │ Declination │
│              │   │  Detector       │  │ Calculator   │
│ predict()    │   │                 │  │             │
│ update()     │   │ analyze()       │  │ calculate() │
│              │   │ ────────────── │  │             │
│ Returns:     │   │ Returns:        │  │ Returns:    │
│ smoothed     │   │ weight          │  │ declination │
│ heading      │   │ confidence     │  │             │
└───────┬──────┘   └────────┬────────┘  └──────┬──────┘
        │                   │                   │
        └───────────────────┼───────────────────┘
                            │
┌───────────────────────────▼───────────────────────────────┐
│              Data Fusion Layer                             │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Combine Results                                   │  │
│  │  - Apply EKF smoothing                             │  │
│  │  - Weight by anomaly detection                     │  │
│  │  - Apply declination correction                    │  │
│  └────────────────────────────────────────────────────┘  │
└───────────────────────────┬───────────────────────────────┘
                            │
┌───────────────────────────▼───────────────────────────────┐
│              Performance Monitoring                        │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Metrics Collection                                 │  │
│  │  - Record latency                                   │  │
│  │  - Measure CPU/Memory                               │  │
│  │  - Check budgets                                    │  │
│  └────────────────────────────────────────────────────┘  │
└───────────────────────────┬───────────────────────────────┘
                            │
┌───────────────────────────▼───────────────────────────────┐
│              Output Layer                                  │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Final Heading (True North)                        │  │
│  │  - heading: Double                                  │  │
│  │  - accuracy: Double                                 │  │
│  │  - pitch: Double                                    │  │
│  │  - roll: Double                                     │  │
│  └────────────────────────────────────────────────────┘  │
└───────────────────────────┬───────────────────────────────┘
                            │
                    ┌───────▼────────┐
                    │  UI Updates    │
                    │  @Published    │
                    └────────────────┘
```

## تدفق Extended Kalman Filter

```
┌──────────────────────────────────────────────────────────────┐
│                    EKF Processing Flow                        │
└──────────────────────────────────────────────────────────────┘

Input: SensorMeasurement
    │
    ├─→ [Type Check]
    │       │
    │       ├─→ Accelerometer
    │       ├─→ Gyroscope
    │       ├─→ Magnetometer
    │       └─→ DeviceMotion
    │
    ├─→ [Calculate Measurement Matrix H]
    │       │
    │       └─→ Based on measurement type
    │
    ├─→ [Predict Step]
    │       │
    │       ├─→ Calculate state transition matrix F
    │       ├─→ Predict state: x_k|k-1 = F * x_k-1|k-1
    │       └─→ Update covariance: P_k|k-1 = F * P_k-1 * F^T + Q
    │
    ├─→ [Update Step]
    │       │
    │       ├─→ Calculate innovation: y = z_k - H * x_k|k-1
    │       ├─→ Calculate innovation covariance: S = H * P_k|k-1 * H^T + R
    │       ├─→ Calculate Kalman gain: K = P_k|k-1 * H^T * S^-1
    │       ├─→ Update state: x_k|k = x_k|k-1 + K * y
    │       └─→ Update covariance: P_k|k = (I - K * H) * P_k|k-1
    │
    ├─→ [Normalize Angles]
    │       │
    │       └─→ Normalize roll, pitch, yaw to [-π, π]
    │
    └─→ Output: EKFState (smoothed heading)
```

## تدفق Magnetic Anomaly Detection

```
┌──────────────────────────────────────────────────────────────┐
│           Anomaly Detection Flow                             │
└──────────────────────────────────────────────────────────────┘

Input: CMMagneticField, Timestamp
    │
    ├─→ [Calculate Magnitude]
    │       │
    │       └─→ magnitude = sqrt(mx² + my² + mz²)
    │
    ├─→ [Update History]
    │       │
    │       ├─→ Add to magnitudeHistory
    │       ├─→ Add to timestampHistory
    │       └─→ Maintain window size (30 samples)
    │
    ├─→ [Calculate Statistics]
    │       │
    │       ├─→ movingAverage = mean(magnitudeHistory)
    │       └─→ movingStdDev = std(magnitudeHistory)
    │
    ├─→ [Detect Anomaly]
    │       │
    │       ├─→ Check range: magnitude in [15, 70] μT?
    │       ├─→ Calculate Z-score: |magnitude - mean| / std
    │       ├─→ Check sudden change: |magnitude - last| > threshold?
    │       └─→ isAnomaly = (range violation || zScore > threshold || sudden change)
    │
    ├─→ [Calculate Weight]
    │       │
    │       ├─→ If anomaly:
    │       │       weight = suspiciousWeight - consecutivePenalty
    │       └─→ Else:
    │               weight = 1.0
    │
    ├─→ [Calculate Confidence]
    │       │
    │       ├─→ normalRatio = count(normal) / total
    │       ├─→ coefficientOfVariation = std / mean
    │       └─→ confidence = normalRatio * 0.6 + stabilityScore * 0.4
    │
    └─→ Output: (weight: Double, isAnomaly: Bool, confidence: Double)
```

## تدفق Magnetic Declination Calculation

```
┌──────────────────────────────────────────────────────────────┐
│        Declination Calculation Flow                          │
└──────────────────────────────────────────────────────────────┘

Input: Latitude, Longitude, Date
    │
    ├─→ [Check Cache]
    │       │
    │       ├─→ Generate cache key: "lat,lon"
    │       ├─→ Check if cached and valid
    │       └─→ If found: return cached value
    │
    ├─→ [Calculate Fractional Year]
    │       │
    │       ├─→ year = calendar.component(.year, from: date)
    │       ├─→ dayOfYear = calendar.ordinality(...)
    │       └─→ fractionalYear = year + (dayOfYear - 1) / 365.25
    │
    ├─→ [Update WMM Coefficients]
    │       │
    │       ├─→ yearsSinceEpoch = fractionalYear - 2020.0
    │       ├─→ g10 = g10_base + g10Dot * yearsSinceEpoch
    │       ├─→ g11 = g11_base + g11Dot * yearsSinceEpoch
    │       └─→ h11 = h11_base + h11Dot * yearsSinceEpoch
    │
    ├─→ [Calculate Magnetic Field Components]
    │       │
    │       ├─→ Convert lat/lon to radians
    │       ├─→ Calculate sin/cos
    │       ├─→ X = g10 * cosLat + (g11 * cosLon + h11 * sinLon) * sinLat
    │       ├─→ Y = g11 * sinLon - h11 * cosLon
    │       └─→ Z = g10 * sinLat - (g11 * cosLon + h11 * sinLon) * cosLat
    │
    ├─→ [Calculate Declination]
    │       │
    │       └─→ declination = atan2(Y, X) * 180 / π
    │
    ├─→ [Cache Result]
    │       │
    │       └─→ Store in cache with timestamp
    │
    └─→ Output: Declination (degrees)
```

## تدفق Adaptive Update Rate

```
┌──────────────────────────────────────────────────────────────┐
│         Adaptive Update Rate Flow                            │
└──────────────────────────────────────────────────────────────┘

Input: Heading, Timestamp
    │
    ├─→ [Update History]
    │       │
    │       ├─→ Add heading to history
    │       ├─→ Add timestamp to history
    │       └─→ Clean old entries (> 0.5s)
    │
    ├─→ [Calculate Angular Velocity]
    │       │
    │       ├─→ For each pair in history:
    │       │       diff = normalizeAngle(curr - prev)
    │       │       totalChange += abs(diff)
    │       │       totalTime += timeDiff
    │       └─→ angularVelocity = totalChange / totalTime
    │
    ├─→ [Determine Motion State]
    │       │
    │       ├─→ If angularVelocity < 0.5 deg/s:
    │       │       state = .stationary (5 Hz)
    │       ├─→ Else if angularVelocity < 5.0 deg/s:
    │       │       state = .slowMovement (15 Hz)
    │       └─→ Else:
    │               state = .fastMovement (30 Hz)
    │
    ├─→ [Check Throttling]
    │       │
    │       ├─→ timeSinceLastUpdate = now - lastUpdateTime
    │       ├─→ requiredInterval = state.updateInterval
    │       └─→ shouldUpdate = timeSinceLastUpdate >= requiredInterval
    │
    └─→ Output: MotionState, UpdateInterval, shouldUpdate
```

## تدفق Performance Monitoring

```
┌──────────────────────────────────────────────────────────────┐
│         Performance Monitoring Flow                            │
└──────────────────────────────────────────────────────────────┘

┌─────────────────┐
│ Update Start    │──→ recordUpdateStart() → Store timestamp
└─────────────────┘

┌─────────────────┐
│ Filter Process  │──→ recordFilterProcessing(time) → Store time
└─────────────────┘

┌─────────────────┐
│ Update End      │──→ recordUpdateEnd(startTime) → Calculate latency
└─────────────────┘
        │
        ├─→ [Calculate Metrics]
        │       │
        │       ├─→ updateRate = count(updates in window) / windowSize
        │       ├─→ averageLatency = mean(latencyMeasurements)
        │       ├─→ maxLatency = max(latencyMeasurements)
        │       ├─→ filterTime = mean(filterProcessingTimes)
        │       ├─→ cpuUsage = estimateCPU(latency, updateRate)
        │       └─→ memoryUsage = getCurrentMemoryUsage()
        │
        ├─→ [Check Budgets]
        │       │
        │       ├─→ Check CPU: < 5%?
        │       ├─→ Check Latency: < 16ms?
        │       ├─→ Check Memory: < 10MB?
        │       └─→ Check Filter Time: < 1ms?
        │
        └─→ Output: Metrics, Budget Violations
```

## المراجع

- [Architecture Overview](./overview.md)
- [Component Diagrams](./components.md)
- [ADR Index](../adr/index.md)
