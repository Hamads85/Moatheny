# Architecture Decision Records (ADRs)

## الفهرس

### التحسينات الرئيسية للبوصلة

1. [ADR-002: Extended Kalman Filter Implementation](./ADR-002-Extended-Kalman-Filter.md)
2. [ADR-003: Magnetic Anomaly Detector](./ADR-003-Magnetic-Anomaly-Detector.md)
3. [ADR-004: Magnetic Declination Calculator](./ADR-004-Magnetic-Declination-Calculator.md)
4. [ADR-005: Sensor Fusion Engine](./ADR-005-Sensor-Fusion-Engine.md)
5. [ADR-006: Performance Metrics Collector](./ADR-006-Performance-Metrics-Collector.md)
6. [ADR-007: Adaptive Update Rate Manager](./ADR-007-Adaptive-Update-Rate-Manager.md)

### القرارات المعمارية السابقة

- [ADR-001: Compass Architecture Refactoring](../ADRs/ADR-001-Compass-Architecture-Refactoring.md)

---

## ما هي ADR؟

Architecture Decision Record (ADR) هو وثيقة تسجل قراراً معمارياً مهماً، بما في ذلك:
- السياق الذي تم اتخاذ القرار فيه
- القرار المتخذ
- العواقب (الإيجابية والسلبية)
- البدائل المدروسة

## متى نستخدم ADR؟

يجب إنشاء ADR عند:
- اتخاذ قرار معماري مهم يؤثر على بنية النظام
- اختيار تقنية أو مكتبة جديدة
- تغيير نهج التصميم الحالي
- حل مشكلة معمارية معقدة
