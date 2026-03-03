# Architecture Overview - Compass System

## نظرة عامة

نظام البوصلة المحسنة في تطبيق مؤذني يستخدم تقنيات متقدمة لتحقيق دقة عالية واستقرار في قراءات الاتجاه.

## المكونات الرئيسية

### 1. CompassService
الخدمة الرئيسية التي تدير البوصلة وتوفر واجهة موحدة للـ UI.

**المسؤوليات:**
- إدارة المستشعرات (Location, Motion)
- تنسيق المكونات الأخرى
- تحديث UI عبر `@Published` properties

### 2. Extended Kalman Filter (EKF)
فلتر متقدم لتنعيم قراءات البوصلة ودمج المستشعرات.

**المسؤوليات:**
- تنعيم قراءات Heading
- دمج Accelerometer, Gyroscope, Magnetometer
- معالجة الانتقالات الزاوية (359° → 0°)

### 3. Magnetic Anomaly Detector
كاشف التشويش المغناطيسي.

**المسؤوليات:**
- كشف التشويش المغناطيسي
- حساب وزن القياسات
- توفير معلومات عن الثقة

### 4. Magnetic Declination Calculator
حاسبة الانحراف المغناطيسي.

**المسؤوليات:**
- حساب الانحراف بناءً على الموقع
- تحويل المغناطيسي إلى الحقيقي
- Cache للنتائج

### 5. Performance Metrics Collector
جامع مقاييس الأداء.

**المسؤوليات:**
- قياس CPU, Memory, Latency
- التحقق من Performance Budgets
- توفير تقارير الأداء

### 6. Adaptive Update Rate Manager
مدير معدل التحديث التكيفي.

**المسؤوليات:**
- تعديل معدل التحديث بناءً على الحركة
- توفير البطارية
- Throttling ذكي

## تدفق البيانات

```
┌─────────────────┐
│  CoreLocation   │──┐
│  (CLHeading)    │  │
└─────────────────┘  │
                     │
┌─────────────────┐  │    ┌──────────────────────┐
│  CoreMotion     │──┼───→│   CompassService     │
│  (DeviceMotion) │  │    │                      │
└─────────────────┘  │    │  - Heading Updates  │
                     │    │  - Error Handling    │
┌─────────────────┐  │    │  - UI Updates        │
│  Location       │──┘    └──────────────────────┘
│  (GPS)          │              │
└─────────────────┘              │
                                  │
                    ┌─────────────┴─────────────┐
                    │                           │
        ┌───────────▼──────────┐   ┌───────────▼──────────┐
        │  Extended Kalman      │   │  Magnetic Anomaly    │
        │  Filter (EKF)         │   │  Detector            │
        │                       │   │                      │
        │  - Smooth Heading     │   │  - Detect Interference│
        │  - Sensor Fusion      │   │  - Calculate Weight   │
        │  - Angle Normalization│   │  - Confidence Score  │
        └───────────┬──────────┘   └───────────┬──────────┘
                    │                           │
                    └─────────────┬─────────────┘
                                  │
                    ┌─────────────▼─────────────┐
                    │  Magnetic Declination     │
                    │  Calculator               │
                    │                           │
                    │  - Calculate Declination  │
                    │  - Magnetic → True        │
                    │  - Cache Results          │
                    └─────────────┬─────────────┘
                                  │
                    ┌─────────────▼─────────────┐
                    │  Final Heading            │
                    │  (True North)             │
                    └───────────────────────────┘
```

## طبقات النظام

### Presentation Layer
- **Views**: SwiftUI views للبوصلة
- **ViewModels**: إدارة الحالة والمنطق

### Business Logic Layer
- **CompassService**: الخدمة الرئيسية
- **QiblaCalculator**: حساب اتجاه القبلة

### Data Processing Layer
- **ExtendedKalmanFilter**: معالجة البيانات
- **MagneticAnomalyDetector**: كشف التشويش
- **MagneticDeclinationCalculator**: حساب الانحراف

### Sensor Layer
- **CoreLocation**: قراءات البوصلة والموقع
- **CoreMotion**: قراءات المستشعرات

## التكامل مع النظام

```
┌─────────────────────────────────────────┐
│           Moatheny App                  │
│                                          │
│  ┌──────────────────────────────────┐  │
│  │      QiblaView                   │  │
│  │  (UI Layer)                      │  │
│  └────────────┬─────────────────────┘  │
│               │                         │
│  ┌────────────▼─────────────────────┐  │
│  │      CompassService               │  │
│  │  (Business Logic)                  │  │
│  └────────────┬─────────────────────┘  │
│               │                         │
│  ┌────────────▼─────────────────────┐  │
│  │  Processing Components            │  │
│  │  - EKF                            │  │
│  │  - Anomaly Detector               │  │
│  │  - Declination Calculator         │  │
│  └───────────────────────────────────┘  │
│                                          │
│  ┌──────────────────────────────────┐  │
│  │  Performance & Optimization        │  │
│  │  - Metrics Collector              │  │
│  │  - Adaptive Update Rate           │  │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

## المبادئ المعمارية

### 1. Separation of Concerns
كل مكون له مسؤولية واحدة واضحة.

### 2. Dependency Injection
الاعتماد على Protocols للواجهات.

### 3. Performance First
تحسين الأداء واستهلاك البطارية.

### 4. Testability
تصميم قابل للاختبار.

### 5. Maintainability
كود واضح وموثق.

## الأداء

### Performance Budgets
- **CPU Usage**: < 5% average
- **Memory**: < 10MB for compass processing
- **Latency**: < 16ms (60fps)
- **Update Rate**: 5-30 Hz (adaptive)

### Optimizations
- Background queue للفلاتر
- Cache للانحراف المغناطيسي
- Adaptive update rate
- Throttling ذكي

## الأمان والخصوصية

- **Location Privacy**: استخدام WhenInUse فقط (ما لم يطلب المستخدم Always)
- **No Data Collection**: لا يتم جمع أو إرسال أي بيانات
- **Local Processing**: جميع المعالجات محلية

## التوافق

- **iOS Version**: iOS 16.0+
- **Devices**: جميع الأجهزة المدعومة
- **Orientations**: جميع الوضعيات

## المراجع

- [ADR-002: Extended Kalman Filter](../adr/ADR-002-Extended-Kalman-Filter.md)
- [ADR-003: Magnetic Anomaly Detector](../adr/ADR-003-Magnetic-Anomaly-Detector.md)
- [ADR-004: Magnetic Declination Calculator](../adr/ADR-004-Magnetic-Declination-Calculator.md)
- [ADR-005: Sensor Fusion Engine](../adr/ADR-005-Sensor-Fusion-Engine.md)
- [ADR-006: Performance Metrics Collector](../adr/ADR-006-Performance-Metrics-Collector.md)
- [ADR-007: Adaptive Update Rate Manager](../adr/ADR-007-Adaptive-Update-Rate-Manager.md)
