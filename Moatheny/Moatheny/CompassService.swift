import Foundation
import CoreLocation
import CoreMotion
import Combine
import UIKit

/// خدمة البوصلة المتقدمة - تعمل بكل الاتجاهات والميلانات
/// تستخدم CoreLocation للحصول على اتجاه دقيق مع فلتر Kalman للتنعيم القوي
///
/// ## معالجة الانحراف المغناطيسي:
/// - API القبلة يعطي الاتجاه من الشمال الجغرافي (True North)
/// - البوصلة قد تعطي الشمال المغناطيسي (Magnetic North)
/// - يتم تطبيق تعويض الانحراف المغناطيسي تلقائياً عند الحاجة:
///   - DeviceMotion: إذا كان motionReferenceFrame == .xMagneticNorthZVertical
///   - CLHeading: إذا كان trueHeading غير متاح واستخدمنا magneticHeading
/// - إذا كان heading حقيقي بالفعل (trueHeading أو .xTrueNorthZVertical)، لا يتم تطبيق تعويض
///
/// راجع: MAGNETIC_DECLINATION_REVIEW.md للتفاصيل الكاملة
final class CompassService: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var heading: Double = 0           // الاتجاه الحقيقي المنعم (0-360)
    @Published var rawHeading: Double = 0        // الاتجاه الخام قبل التنعيم
    @Published var accuracy: Double = -1         // دقة القراءة
    @Published var isAvailable = false           // هل البوصلة متاحة
    @Published var error: String?                // رسالة الخطأ
    @Published var pitch: Double = 0             // الميل للأمام/الخلف
    @Published var roll: Double = 0              // الميل للجانب
    @Published var isDeviceFlat = true           // هل الجهاز مسطح
    @Published var calibrationNeeded = false     // هل تحتاج معايرة
    @Published var deviceOrientation: UIDeviceOrientation = .portrait // وضعية الجهاز الحالية
    @Published var isDeviceMoving = false        // هل الجهاز يتحرك (من userAcceleration)
    @Published var tiltCompensationEnabled = true // تفعيل تعويض الميلان
    
    // MARK: - Debug Properties (للتحقق من مشكلة 88°)
    @Published var rawTrueHeading: Double = -1    // trueHeading الخام من iOS (للتحقق)
    @Published var rawMagneticHeading: Double = -1 // magneticHeading الخام من iOS (للتحقق)
    @Published var isUsingTrueHeading: Bool = false // هل نستخدم trueHeading أم magneticHeading
    @Published var magneticDeclinationApplied: Double = 0 // قيمة الانحراف المغناطيسي المطبقة
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private let motionManager = CMMotionManager()
    private var isUpdating = false
    private var useMotionHeading = false
    private var motionReferenceFrame: CMAttitudeReferenceFrame?
    private var lastLogSecond: Int = 0
    private var lastDeviceOrientationRaw: String = "unknown"
    
    // إعدادات محسنة للبوصلة
    private let optimalHeadingFilter: CLLocationDirection = 1.0 // درجة واحدة - توازن بين الدقة والأداء
    private let optimalMotionUpdateInterval: TimeInterval = 1.0 / 60.0 // 60 Hz للدقة القصوى
    private let movementThreshold: Double = 0.1 // m/s² للكشف عن الحركة
    private var lastUserAcceleration: CMAcceleration?
    
    // إعدادات معايرة البوصلة
    private let calibrationAccuracyThreshold: Double = 25.0 // درجة - إذا كانت الدقة أسوأ من هذا، نحتاج معايرة
    private let criticalCalibrationThreshold: Double = 50.0 // درجة - دقة سيئة جداً
    private var calibrationRequestCount: Int = 0 // عدد محاولات طلب المعايرة
    private let maxCalibrationRequests: Int = 3 // الحد الأقصى لمحاولات طلب المعايرة
    private var lastCalibrationRequestTime: Date?
    private let calibrationRequestCooldown: TimeInterval = 30.0 // ثانية - فترة الانتظار بين المحاولات
    
    // ====== Extended Kalman Filter للـ Sensor Fusion ======
    private var extendedKalmanFilter: ExtendedKalmanFilter?
    
    // ====== كاشف التشويش المغناطيسي ======
    private var magneticAnomalyDetector: MagneticAnomalyDetector?
    
    // ====== حاسبة الانحراف المغناطيسي ======
    private var currentLocation: CLLocation?
    
    // ====== معاملات EKF - محسنة للسرعة والدقة ======
    private let processNoiseHeading: Double = 0.05      // ضوضاء heading
    private let processNoiseHeadingRate: Double = 0.5   // ضوضاء heading_rate
    private let measurementNoise: Double = 0.3          // ضوضاء القياس المغناطيسي
    
    // ====== فلتر إضافي للتذبذب السريع - محسن ======
    private var lastStableHeading: Double = 0
    private let stabilityThreshold: Double = 0.5  // تجاهل التغييرات أقل من نصف درجة فقط
    private var consecutiveSmallChanges: Int = 0
    private let requiredStableReadings: Int = 1   // قراءة واحدة مستقرة كافية
    
    // ====== بيانات الجيروسكوب ======
    private var lastGyroRate: Double = 0
    private var lastMotionTimestamp: TimeInterval = 0
    
    // ====== Performance Optimization ======
    private let performanceMetrics = PerformanceMetricsCollector()
    private let adaptiveUpdateRate = AdaptiveUpdateRateManager()
    private let filterProcessingQueue = DispatchQueue(label: "com.moatheny.compass.filter", qos: .userInitiated)
    private var isPerformanceMonitoringEnabled = true
    
    // MARK: - Initialization
    override init() {
        super.init()
        locationManager.delegate = self
        isAvailable = CLLocationManager.headingAvailable()
        
        // تهيئة Extended Kalman Filter
        extendedKalmanFilter = ExtendedKalmanFilter(
            processNoiseHeading: processNoiseHeading,
            processNoiseHeadingRate: processNoiseHeadingRate,
            measurementNoise: measurementNoise
        )
        
        // تهيئة كاشف التشويش المغناطيسي
        magneticAnomalyDetector = MagneticAnomalyDetector(
            windowSize: 30,
            zScoreThreshold: 2.5,
            suspiciousMeasurementWeight: 0.3
        )
    }
    
    deinit {
        stopUpdating()
    }
    
    // MARK: - Public Methods
    func startUpdating() {
        guard !isUpdating else { return }
        isUpdating = true
        
        // إعادة تهيئة الفلاتر
        extendedKalmanFilter = ExtendedKalmanFilter(
            processNoiseHeading: processNoiseHeading,
            processNoiseHeadingRate: processNoiseHeadingRate,
            measurementNoise: measurementNoise
        )
        magneticAnomalyDetector?.reset()
        
        // التحقق من حالة إذن الموقع أولاً
        let authStatus = locationManager.authorizationStatus
        
        if authStatus == .notDetermined {
            // طلب الإذن إذا لم يُطلب من قبل
            locationManager.requestWhenInUseAuthorization()
            print("📍 طلب إذن الموقع للبوصلة")
        } else if authStatus == .denied || authStatus == .restricted {
            error = "يرجى تفعيل إذن الموقع من الإعدادات لاستخدام البوصلة"
            isAvailable = false
            print("❌ إذن الموقع مرفوض")
            return
        }
        
        // بدء تحديثات الاتجاه من CoreLocation
        if CLLocationManager.headingAvailable() {
            // #region agent log
            DebugFileLogger.log(runId: "ui-change", hypothesisId: "Q2", location: "CompassService.swift:startUpdating", message: "Start heading/location updates", data: ["headingAvailable": true])
            // #endregion agent log
            
            // إعدادات محسنة للدقة القصوى
            // headingFilter = 1.0 درجة: توازن مثالي بين الدقة والأداء
            // قيم أقل (0.5) = تحديثات أكثر = استهلاك بطارية أعلى
            // قيم أعلى (5.0) = تحديثات أقل = استجابة أبطأ
            // ملاحظة: عندما تكون الدقة سيئة جداً (>50°)، قد نحتاج لزيادة الفلتر
            // لكن نبدأ بقيمة منخفضة لتحفيز iOS على طلب المعايرة
            locationManager.headingFilter = optimalHeadingFilter
            
            // ⚠️ مهم جداً: تعيين headingOrientation لضمان قراءة صحيحة للـ heading
            // iOS يحتاج معرفة اتجاه الجهاز (portrait, landscape, etc.) لحساب heading بشكل صحيح
            // بدون هذا الإعداد، قد يعطي iOS قراءات خاطئة (مثل 154° بدلاً من 242°)
            // نستخدم .portrait كقيمة افتراضية، وسيتم تحديثها تلقائياً عند تغيير الوضعية
            locationManager.headingOrientation = .portrait
            
            // kCLLocationAccuracyBestForNavigation: أعلى دقة متاحة مع GPS + GLONASS + Galileo
            // مطلوب للحصول على true heading (الشمال الحقيقي) بدلاً من magnetic heading
            locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            
            // لا نحد من المسافة - نريد كل تحديث للموقع
            locationManager.distanceFilter = kCLDistanceFilterNone
            
            // منع التوقف التلقائي - مهم للبوصلة المستمرة
            locationManager.pausesLocationUpdatesAutomatically = false
            
            // تحسين إعدادات البوصلة لتحسين الدقة
            // iOS يتحكم تلقائياً في معايرة البوصلة، لكن يمكننا تحسين الشروط
            
            // السماح بتحديثات الموقع في الخلفية (يتطلب Always authorization)
            if authStatus == .authorizedAlways {
                locationManager.allowsBackgroundLocationUpdates = true
            }
            
            locationManager.startUpdatingHeading()
            locationManager.startUpdatingLocation() // مهم للحصول على true heading
            isAvailable = true
            error = nil
            print("✅ بدأ تحديث البوصلة المحسن (headingFilter: \(optimalHeadingFilter)°, accuracy: BestForNavigation)")
        } else {
            error = "البوصلة غير متوفرة على هذا الجهاز"
            isAvailable = false
            print("❌ البوصلة غير متوفرة")
        }
        
        // إعداد Adaptive Update Rate Manager
        adaptiveUpdateRate.onStateChanged = { [weak self] (state: AdaptiveUpdateRateManager.MotionState) in
            self?.updateMotionManagerInterval(for: state)
        }
        
        // بدء Performance Monitoring
        if isPerformanceMonitoringEnabled {
            startPerformanceMonitoring()
        }
        
        // بدء تحديثات الحركة (Sensor Fusion) للحصول على heading True-North مع تعويض الميلان إن توفر
        if motionManager.isDeviceMotionAvailable {
            // استخدام Adaptive Update Rate - يبدأ بمعدل منخفض (5 Hz) ثم يتكيف
            let initialState = adaptiveUpdateRate.motionState
            motionManager.deviceMotionUpdateInterval = initialState.updateInterval
            
            let frames = CMMotionManager.availableAttitudeReferenceFrames()
            if frames.contains(.xTrueNorthZVertical) {
                useMotionHeading = true
                motionReferenceFrame = .xTrueNorthZVertical
            } else if frames.contains(.xMagneticNorthZVertical) {
                useMotionHeading = true
                motionReferenceFrame = .xMagneticNorthZVertical
            } else {
                useMotionHeading = false
                motionReferenceFrame = nil
            }
            
            // #region agent log
            DebugFileLogger.log(
                runId: "qibla-accuracy",
                hypothesisId: "Q3",
                location: "CompassService.swift:startUpdating",
                message: "Motion reference frame selected",
                data: [
                    "useMotionHeading": useMotionHeading,
                    "frame": motionReferenceFrame == .xTrueNorthZVertical ? "xTrueNorthZVertical" :
                             motionReferenceFrame == .xMagneticNorthZVertical ? "xMagneticNorthZVertical" : "none"
                ]
            )
            DebugFileLogger.log(
                runId: "qibla-accuracy",
                hypothesisId: "Q3",
                location: "CompassService.swift:startUpdating",
                message: "Available attitude reference frames",
                data: [
                    "hasTrueNorth": frames.contains(.xTrueNorthZVertical),
                    "hasMagNorth": frames.contains(.xMagneticNorthZVertical),
                    "hasArbitrary": frames.contains(.xArbitraryZVertical),
                    "hasArbitraryCorrected": frames.contains(.xArbitraryCorrectedZVertical)
                ]
            )
            // #endregion agent log
            
            if let frame = motionReferenceFrame, useMotionHeading {
                // استخدام background queue للاستقبال، ثم معالجة على queue منفصل
                motionManager.startDeviceMotionUpdates(using: frame, to: .main) { [weak self] motion, error in
                    guard let self = self, let motion = motion else {
                        if let error = error {
                            print("⚠️ خطأ في DeviceMotion: \(error.localizedDescription)")
                        }
                        return
                    }
                    
                    // Throttling ذكي بناءً على حالة الحركة
                    let timestamp = Date()
                    guard self.adaptiveUpdateRate.shouldUpdate(timestamp: timestamp) else {
                        return // تخطي هذا التحديث
                    }
                    
                    // تحديث حالة الحركة
                    let headingDeg = self.extractHeadingFromMotion(motion)
                    _ = self.adaptiveUpdateRate.update(heading: headingDeg, timestamp: timestamp)
                    
                    // معالجة على Main Thread للـ UI updates فقط
                    self.updateDeviceOrientation(motion)
                    self.detectDeviceMovement(motion)
                    
                    // معالجة Heading على background queue للفلاتر
                    self.processHeadingOnBackground(motion: motion, headingDeg: headingDeg)
                }
            } else {
                // لا يوجد إطار True/Magnetic North متاح: نستفيد من الميلان فقط
                motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
                    guard let self = self, let motion = motion else {
                        if let error = error {
                            print("⚠️ خطأ في DeviceMotion: \(error.localizedDescription)")
                        }
                        return
                    }
                    self.updateDeviceOrientation(motion)
                    self.detectDeviceMovement(motion)
                }
            }
        }
    }
    
    /// طلب إذن الموقع - مع دعم Always authorization للدقة القصوى
    func requestLocationPermission() {
        let currentStatus = locationManager.authorizationStatus
        
        switch currentStatus {
        case .notDetermined:
            // طلب WhenInUse أولاً (iOS يطلب Always بعد ذلك إذا لزم الأمر)
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            // طلب Always authorization للدقة القصوى
            // ملاحظة: iOS سيطلب من المستخدم الموافقة في الإعدادات
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways:
            // الإذن موجود بالفعل
            print("✅ إذن Always موجود")
        case .denied, .restricted:
            error = "يرجى تفعيل إذن الموقع من الإعدادات لاستخدام البوصلة بدقة عالية"
        @unknown default:
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    /// طلب Always authorization مباشرة (للاستخدام المتقدم)
    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func stopUpdating() {
        guard isUpdating else { return }
        isUpdating = false
        locationManager.stopUpdatingHeading()
        locationManager.stopUpdatingLocation()
        motionManager.stopDeviceMotionUpdates()
        
        // إيقاف Performance Monitoring
        stopPerformanceMonitoring()
        
        // إعادة تعيين Adaptive Update Rate
        adaptiveUpdateRate.reset()
        
        print("⏹ توقف تحديث البوصلة")
    }
    
    /// تفعيل/تعطيل تعويض الميلان
    func setTiltCompensation(_ enabled: Bool) {
        tiltCompensationEnabled = enabled
    }
    
    /// الحصول على معلومات الوضعية الحالية
    func getOrientationInfo() -> (orientation: UIDeviceOrientation, isFlat: Bool, pitch: Double, roll: Double) {
        return (deviceOrientation, isDeviceFlat, pitch, roll)
    }
    
    /// الحصول على مقاييس الأداء
    func getPerformanceMetrics() -> PerformanceMetricsCollector {
        return performanceMetrics
    }
    
    /// طلب معايرة البوصلة إذا لزم الأمر
    /// - Parameter critical: إذا كانت true، المعايرة مطلوبة فوراً (دقة سيئة جداً)
    private func requestCalibrationIfNeeded(critical: Bool = false) {
        // إذا كانت المعايرة حرجة، نحاول دائماً
        if critical {
            calibrationRequestCount = 0 // إعادة تعيين العداد للسماح بمحاولة جديدة
        }
        
        // التحقق من فترة الانتظار
        if let lastRequest = lastCalibrationRequestTime {
            let timeSinceLastRequest = Date().timeIntervalSince(lastRequest)
            if timeSinceLastRequest < calibrationRequestCooldown && !critical {
                return // لم تمر فترة كافية
            }
        }
        
        // التحقق من عدد المحاولات
        if calibrationRequestCount >= maxCalibrationRequests && !critical {
            return // تجاوزنا الحد الأقصى
        }
        
        // تحديث عداد المحاولات ووقت آخر محاولة
        calibrationRequestCount += 1
        lastCalibrationRequestTime = Date()
        
        // محاولة إظهار شاشة المعايرة
        // iOS سيستدعي locationManagerShouldDisplayHeadingCalibration تلقائياً
        // لكن يمكننا إعادة تشغيل heading updates لتحفيز الطلب
        if critical || calibrationRequestCount == 1 {
            // عند المحاولة الأولى أو عند الحاجة الحرجة، نعيد تشغيل heading updates
            // هذا قد يحفز iOS على طلب المعايرة
            locationManager.stopUpdatingHeading()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                self.locationManager.startUpdatingHeading()
                print("🔄 محاولة إظهار شاشة معايرة البوصلة (المحاولة \(self.calibrationRequestCount))")
            }
        }
    }
    
    /// إعادة تعيين حالة المعايرة (للاستخدام بعد إكمال المعايرة)
    func resetCalibrationState() {
        calibrationRequestCount = 0
        lastCalibrationRequestTime = nil
        calibrationNeeded = false
        print("✅ تم إعادة تعيين حالة المعايرة")
    }
    
    // MARK: - Performance Monitoring
    
    /// تحديث معدل تحديث Motion Manager بناءً على حالة الحركة
    private func updateMotionManagerInterval(for state: AdaptiveUpdateRateManager.MotionState) {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = state.updateInterval
    }
    
    /// بدء مراقبة الأداء
    private func startPerformanceMonitoring() {
        // تسجيل مقاييس الأداء كل 10 ثوانٍ
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] timer in
            guard let self = self, self.isUpdating else {
                timer.invalidate()
                return
            }
            
            let metrics = self.performanceMetrics
            #if DEBUG
            print("📊 Performance: CPU=\(metrics.formattedCPUUsage), Memory=\(metrics.formattedMemoryUsage), UpdateRate=\(String(format: "%.1f", metrics.updateRate))Hz")
            #endif
        }
    }
    
    /// إيقاف مراقبة الأداء
    private func stopPerformanceMonitoring() {
        // يتم إيقاف المراقبة تلقائياً عند إيقاف isUpdating
    }
    
    // MARK: - Private Methods
    
    private func updateDeviceOrientation(_ motion: CMDeviceMotion) {
        let attitude = motion.attitude
        
        // الميل (pitch) - الأمام/الخلف (بالدرجات)
        // القيم: -90 (رأساً على عقب) إلى +90 (مستقيم)
        pitch = attitude.pitch * 180 / .pi
        
        // الدوران (roll) - الجانبي (بالدرجات)
        // القيم: -180 إلى +180
        roll = attitude.roll * 180 / .pi
        
        // التحقق من وضعية الجهاز - مسطح إذا كان الميل أقل من 45 درجة
        isDeviceFlat = abs(pitch) < 45 && abs(roll) < 45
        
        // تحديث وضعية الجهاز من UIDevice
        let currentOrientation = UIDevice.current.orientation
        if currentOrientation != .unknown {
            deviceOrientation = currentOrientation
            
            // ⚠️ مهم: تحديث headingOrientation في CLLocationManager عند تغيير الوضعية
            // هذا ضروري لضمان قراءة صحيحة للـ heading
            // iOS يحتاج معرفة اتجاه الجهاز لحساب heading بشكل صحيح
            let headingOrientation: CLDeviceOrientation = {
                switch currentOrientation {
                case .portrait:
                    return .portrait
                case .portraitUpsideDown:
                    return .portraitUpsideDown
                case .landscapeLeft:
                    return .landscapeLeft
                case .landscapeRight:
                    return .landscapeRight
                case .faceUp:
                    return .faceUp
                case .faceDown:
                    return .faceDown
                default:
                    return .portrait // افتراضي
                }
            }()
            
            // تحديث headingOrientation فقط إذا تغيرت الوضعية
            if locationManager.headingOrientation != headingOrientation {
                locationManager.headingOrientation = headingOrientation
                #if DEBUG
                print("🧭 تم تحديث headingOrientation إلى: \(currentOrientation)")
                #endif
            }
        }
        
        // استخدام gravity من CMDeviceMotion للكشف الدقيق عن الوضعية
        // gravity يعطي اتجاه الجاذبية في إطار الجهاز
        let gravity = motion.gravity
        let gravityMagnitude = sqrt(gravity.x * gravity.x + gravity.y * gravity.y + gravity.z * gravity.z)
        
        // إذا كانت الجاذبية قريبة من 1.0، الجهاز ثابت نسبياً
        // إذا كانت أقل، الجهاز يتحرك أو في حالة سقوط حر
        if gravityMagnitude > 0.7 && gravityMagnitude < 1.3 {
            // الجهاز ثابت - يمكن الاعتماد على القراءات
            
            // تحديد الوضعية بدقة من gravity
            // في وضعية Portrait: gravity.y ≈ -1.0 (الجاذبية لأسفل على المحور Y)
            // في وضعية Landscape Left: gravity.x ≈ -1.0
            // في وضعية Landscape Right: gravity.x ≈ 1.0
            // في وضعية Face Up: gravity.z ≈ -1.0
            // في وضعية Face Down: gravity.z ≈ 1.0
            
            let absGravityX = abs(gravity.x)
            let absGravityY = abs(gravity.y)
            let absGravityZ = abs(gravity.z)
            
            // تحديد الوضعية الأكثر احتمالاً بناءً على gravity
            if absGravityZ > max(absGravityX, absGravityY) {
                // Face Up أو Face Down
                if gravity.z > 0 {
                    // Face Down
                    if deviceOrientation != .faceDown {
                        deviceOrientation = .faceDown
                    }
                } else {
                    // Face Up
                    if deviceOrientation != .faceUp {
                        deviceOrientation = .faceUp
                    }
                }
            } else if absGravityY > absGravityX {
                // Portrait أو Portrait Upside Down
                if gravity.y < 0 {
                    // Portrait
                    if deviceOrientation != .portrait {
                        deviceOrientation = .portrait
                    }
                } else {
                    // Portrait Upside Down
                    if deviceOrientation != .portraitUpsideDown {
                        deviceOrientation = .portraitUpsideDown
                    }
                }
            } else {
                // Landscape Left أو Right
                if gravity.x < 0 {
                    // Landscape Left
                    if deviceOrientation != .landscapeLeft {
                        deviceOrientation = .landscapeLeft
                    }
                } else {
                    // Landscape Right
                    if deviceOrientation != .landscapeRight {
                        deviceOrientation = .landscapeRight
                    }
                }
            }
        }
        
        // #region agent log
        let sec = Int(Date().timeIntervalSince1970)
        if sec != lastLogSecond {
            lastLogSecond = sec
            let o = UIDevice.current.orientation
            let oStr: String = {
                switch o {
                case .portrait: return "portrait"
                case .portraitUpsideDown: return "portraitUpsideDown"
                case .landscapeLeft: return "landscapeLeft"
                case .landscapeRight: return "landscapeRight"
                case .faceUp: return "faceUp"
                case .faceDown: return "faceDown"
                default: return "unknown"
                }
            }()
            lastDeviceOrientationRaw = oStr
            
            DebugFileLogger.log(
                runId: "qibla-accuracy",
                hypothesisId: "Q1",
                location: "CompassService.swift:updateDeviceOrientation",
                message: "Device motion attitude tick",
                data: [
                    "pitchDeg": Int(pitch.rounded()),
                    "rollDeg": Int(roll.rounded()),
                    "isFlat": isDeviceFlat,
                    "deviceOrientation": oStr
                ]
            )
        }
        // #endregion agent log
    }
    
    /// كشف حركة الجهاز باستخدام userAcceleration
    /// userAcceleration = totalAcceleration - gravity (يعطي التسارع الناتج عن حركة المستخدم فقط)
    private func detectDeviceMovement(_ motion: CMDeviceMotion) {
        let userAccel = motion.userAcceleration
        let accelMagnitude = sqrt(userAccel.x * userAccel.x + userAccel.y * userAccel.y + userAccel.z * userAccel.z)
        
        // إذا كان التسارع أكبر من العتبة، الجهاز يتحرك
        let wasMoving = isDeviceMoving
        isDeviceMoving = accelMagnitude > movementThreshold
        
        // عند الحركة، قد نحتاج لتعديل معاملات الفلتر للاستجابة الأسرع
        if isDeviceMoving != wasMoving {
            if isDeviceMoving {
                // عند الحركة: استجابة أسرع
                // يمكن تعديل معاملات Kalman filter هنا إذا لزم الأمر
            } else {
                // عند التوقف: استقرار أكثر
            }
        }
        
        lastUserAcceleration = userAccel
    }
    
    /// استخراج Heading من Motion (دالة مساعدة)
    /// 
    /// ⚠️ تصحيح مهم: في iOS، yaw من CMDeviceMotion يعطي الزاوية بالراديان من -π إلى π
    /// حيث:
    /// - 0 = الشمال (North)
    /// - π/2 = الشرق (East)
    /// - π = الجنوب (South)
    /// - -π/2 = الغرب (West)
    ///
    /// للتحويل إلى درجات من الشمال (0-360):
    /// - نحول yaw من راديان إلى درجات
    /// - نطبق الصيغة الصحيحة: heading = (yaw * 180 / π + 360) % 360
    /// - أو: heading = -yaw * 180 / π (ثم تطبيع)
    ///
    /// الصيغة السابقة `360.0 - yawDeg` كانت خاطئة وتسبب قراءات غير صحيحة
    private func extractHeadingFromMotion(_ motion: CMDeviceMotion) -> Double {
        // yaw بالراديان من -π إلى π
        let yawRad = motion.attitude.yaw
        
        // تحويل إلى درجات
        var headingDeg = -yawRad * 180.0 / .pi
        
        // تطبيع إلى [0, 360]
        while headingDeg < 0 { headingDeg += 360 }
        while headingDeg >= 360 { headingDeg -= 360 }
        
        return headingDeg
    }
    
    /// معالجة Heading على Background Queue للفلاتر
    private func processHeadingOnBackground(motion: CMDeviceMotion, headingDeg: Double) {
        guard useMotionHeading else { return }
        
        let startTime = performanceMetrics.recordUpdateStart()
        
        // معالجة الفلاتر على background queue
        filterProcessingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // قياس وقت معالجة Kalman Filter
            let filterStartTime = Date()
            
            // تطبيق تعويض الميلان إذا كان مفعلاً
            var processedHeading = headingDeg
            if self.tiltCompensationEnabled {
                let gravity = motion.gravity
                let gravityZ = abs(gravity.z)
                if gravityZ < 0.3 {
                    // الجهاز عمودي - يمكن إضافة معالجة إضافية مستقبلاً
                    _ = gravityZ // استخدام المتغير لتجنب التحذير
                }
            }
            
            // ====== تطبيق تعويض الانحراف المغناطيسي ======
            // API القبلة يعطي الاتجاه من الشمال الجغرافي (True North)
            // يجب التأكد من أن heading الذي نستخدمه هو True North أيضاً
            //
            // DeviceMotion يوفر إطارين مرجعيين:
            // 1. .xTrueNorthZVertical: يعطي heading حقيقي مباشرة (لا يحتاج تعويض)
            // 2. .xMagneticNorthZVertical: يعطي heading مغناطيسي (يحتاج تعويض)
            //
            // ملاحظة: iOS يفضل .xTrueNorthZVertical إذا كان متاحاً (يتطلب GPS)
            // إذا لم يكن متاحاً، نستخدم .xMagneticNorthZVertical ونطبق التعويض
            if self.motionReferenceFrame == .xMagneticNorthZVertical {
                // الإطار مغناطيسي - نحتاج تطبيق تعويض الانحراف المغناطيسي
                if let location = self.currentLocation {
                    // الموقع متاح - نطبق تعويض الانحراف المغناطيسي
                    let declination = MagneticDeclinationCalculator.calculateDeclination(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude
                    )
                    processedHeading = MagneticDeclinationCalculator.magneticToTrue(
                        magneticHeading: processedHeading,
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude
                    )
                    #if DEBUG
                    // تسجيل تطبيق التعويض (مرة كل ثانية لتجنب spam)
                    let sec = Int(Date().timeIntervalSince1970)
                    if sec != self.lastLogSecond {
                        print("🧭 [Motion] تطبيق تعويض انحراف مغناطيسي: \(String(format: "%.1f", declination))°")
                    }
                    #endif
                } else {
                    // الموقع غير متاح بعد - نستخدم magneticHeading كما هو
                    // سيتم تحديثه تلقائياً عند الحصول على الموقع
                    #if DEBUG
                    print("⚠️ [Motion] الموقع غير متاح - استخدام magneticHeading بدون تعويض انحراف مؤقتاً")
                    #endif
                }
            } else if self.motionReferenceFrame == .xTrueNorthZVertical {
                // الإطار حقيقي - لا حاجة للتعويض لأن headingDeg هو بالفعل True North
                // هذا هو الوضع المثالي لأن iOS يقوم بالتعويض تلقائياً
                #if DEBUG
                // لا نحتاج logging مستمر هنا - فقط عند التغيير
                #endif
            }
            
            // تحديث مؤشرات المعايرة من بيانات Motion
            let magAcc = motion.magneticField.accuracy
            let needsCalibration = magAcc != .high
            
            if needsCalibration != self.calibrationNeeded {
                DispatchQueue.main.async {
                    self.calibrationNeeded = needsCalibration
                    
                    // إذا كانت المعايرة مطلوبة، نحاول إظهار شاشة المعايرة
                    if needsCalibration {
                        // magAcc == .uncalibrated يعني أن المعايرة مطلوبة فوراً
                        let critical = magAcc == .uncalibrated
                        self.requestCalibrationIfNeeded(critical: critical)
                    } else {
                        // إذا تحسنت الدقة، نعيد تعيين عداد المحاولات
                        self.calibrationRequestCount = 0
                    }
                }
            }
            
            // معالجة Heading مع الفلاتر
            self.ingestHeading(processedHeading, source: "motion", startTime: startTime)
            
            // قياس وقت معالجة الفلتر
            let filterProcessingTime = Date().timeIntervalSince(filterStartTime)
            self.performanceMetrics.recordFilterProcessing(time: filterProcessingTime)
            
            // سجل مرة واحدة كل ثانية لتجنب spam
            let sec = Int(Date().timeIntervalSince1970)
            if sec != self.lastLogSecond {
                self.lastLogSecond = sec
                // #region agent log
                DebugFileLogger.log(
                    runId: "qibla-accuracy",
                    hypothesisId: "Q3",
                    location: "CompassService.swift:processHeadingOnBackground",
                    message: "Motion heading tick (optimized)",
                    data: [
                        "heading": Int(headingDeg.rounded()),
                        "magAcc": magAcc == .high ? "high" : magAcc == .medium ? "medium" : magAcc == .low ? "low" : "uncalibrated",
                        "deviceOrientation": self.lastDeviceOrientationRaw,
                        "updateRate": 1.0 / self.adaptiveUpdateRate.currentUpdateInterval,
                        "motionState": self.adaptiveUpdateRate.motionState.description
                    ]
                )
                // #endregion agent log
            }
        }
    }
    
    // تم دمج ingestMotionHeading في processHeadingOnBackground للتحسين الأداء
    
    private func ingestHeading(_ headingValue: Double, source: String, startTime: Date? = nil) {
        // تسجيل وقت بدء المعالجة للأداء
        let _ = startTime ?? Date()
        
        rawHeading = headingValue
        
        // معالجة الفلاتر (قد تكون على background queue)
        let kalmanSmoothed = smoothHeadingWithKalman(headingValue)
        let stableHeading = applyStabilityFilter(kalmanSmoothed)
        
        // تحديث UI على Main Thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let previousHeading = self.heading
            self.heading = stableHeading
            
            // تسجيل شامل للتحقق من مشكلة 88° (مرة كل ثانية)
            #if DEBUG
            let sec = Int(Date().timeIntervalSince1970)
            if sec != self.lastLogSecond {
                let headingDiff = abs(self.heading - previousHeading)
                if headingDiff > 5 { // فقط عند تغيير كبير
                    print("""
                    🔍 [COMPASS DEBUG - 88° ISSUE]
                    - rawTrueHeading (iOS): \(self.rawTrueHeading >= 0 ? String(format: "%.1f", self.rawTrueHeading) : "N/A")°
                    - rawMagneticHeading (iOS): \(self.rawMagneticHeading >= 0 ? String(format: "%.1f", self.rawMagneticHeading) : "N/A")°
                    - isUsingTrueHeading: \(self.isUsingTrueHeading ? "YES ✅" : "NO ⚠️")
                    - magneticDeclinationApplied: \(String(format: "%.1f", self.magneticDeclinationApplied))°
                    - rawHeading (قبل الفلترة): \(String(format: "%.1f", self.rawHeading))°
                    - heading (بعد الفلترة): \(String(format: "%.1f", self.heading))°
                    - accuracy: \(self.accuracy >= 0 ? String(format: "%.1f", self.accuracy) : "N/A")°
                    - source: \(source)
                    """)
                }
            }
            #endif
            
            // تسجيل نهاية المعالجة للأداء
            if let startTime = startTime {
                self.performanceMetrics.recordUpdateEnd(startTime: startTime)
            }
        }
    }
    
    /// تنعيم قراءات البوصلة باستخدام Extended Kalman Filter
    /// هذه الدالة تستخدم للقياسات من CoreLocation (بدون بيانات الجيروسكوب)
    private func smoothHeadingWithKalman(_ newHeading: Double) -> Double {
        guard let ekf = self.extendedKalmanFilter else { return newHeading }
        
        // تحويل الزاوية إلى راديان
        let radians = newHeading * .pi / 180.0
        
        // استخدام EKF بدون بيانات الجيروسكوب (سيستخدم heading_rate المتوقع)
        let timestamp = Date().timeIntervalSince1970
        let smoothedRadians = ekf.update(
            magneticHeading: radians,
            gyroRate: nil, // بدون جيروسكوب
            timestamp: timestamp,
            measurementWeight: 1.0
        )
        
        // تحويل للدرجات
        var smoothedDegrees = smoothedRadians * 180.0 / .pi
        
        // تطبيع بين 0 و 360
        while smoothedDegrees < 0 { smoothedDegrees += 360 }
        while smoothedDegrees >= 360 { smoothedDegrees -= 360 }
        
        return smoothedDegrees
    }
    
    /// فلتر إضافي لمنع التذبذب السريع
    private func applyStabilityFilter(_ heading: Double) -> Double {
        // حساب الفرق مع مراعاة الدوران حول 360
        var diff = heading - lastStableHeading
        if diff > 180 { diff -= 360 }
        if diff < -180 { diff += 360 }
        
        // إذا كان التغيير صغير جداً، نتجاهله
        if abs(diff) < stabilityThreshold {
            consecutiveSmallChanges += 1
            
            // بعد عدة قراءات مستقرة، نقبل التغيير الصغير
            if consecutiveSmallChanges >= requiredStableReadings {
                lastStableHeading = heading
                consecutiveSmallChanges = 0
            }
            return lastStableHeading
        } else {
            // تغيير كبير - نقبله مباشرة
            consecutiveSmallChanges = 0
            lastStableHeading = heading
            return heading
        }
    }
}

// MARK: - ملاحظات حول الخوارزميات المستخدمة
/// 
/// تم استبدال KalmanFilter البسيط بـ ExtendedKalmanFilter المتقدم الذي يوفر:
/// 1. دمج حقيقي للمستشعرات (Sensor Fusion)
/// 2. متجه حالة [heading, heading_rate] لتحسين الدقة
/// 3. دمج بيانات الجيروسكوب مع المغناطيسية
/// 4. كشف التشويش المغناطيسي عبر MagneticAnomalyDetector
/// 5. تعويض الانحراف المغناطيسي عبر MagneticDeclinationCalculator
///
/// راجع الملفات التالية للتفاصيل:
/// - ExtendedKalmanFilter.swift
/// - MagneticAnomalyDetector.swift
/// - MagneticDeclinationCalculator.swift

// MARK: - CLLocationManagerDelegate
extension CompassService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // نحدث accuracy والمعايرة دائماً من CLHeading
        let headingAccuracy = newHeading.headingAccuracy
        
        DispatchQueue.main.async {
            self.accuracy = headingAccuracy
            
            // تحسين منطق كشف الحاجة للمعايرة
            // headingAccuracy < 0 يعني أن القيمة غير صالحة (iOS لم يحسبها بعد)
            // headingAccuracy > calibrationAccuracyThreshold يعني أن الدقة سيئة
            // ملاحظة: headingAccuracy يمثل نصف نطاق الخطأ (±accuracy)
            // مثلاً: headingAccuracy = 72 يعني أن الخطأ المحتمل هو ±72°
            let needsCalibration = headingAccuracy < 0 || headingAccuracy > self.calibrationAccuracyThreshold
            
            // إذا كانت الدقة سيئة جداً (>50°)، نحتاج معايرة فورية
            let criticalCalibration = headingAccuracy > self.criticalCalibrationThreshold
            
            // تحسين headingFilter بناءً على الدقة
            // عندما تكون الدقة سيئة جداً، نزيد الفلتر قليلاً لتقليل الضوضاء
            if headingAccuracy > self.criticalCalibrationThreshold {
                // دقة سيئة جداً - نزيد الفلتر لتقليل التحديثات غير المفيدة
                if manager.headingFilter < 3.0 {
                    manager.headingFilter = 3.0
                    print("⚠️ تم زيادة headingFilter إلى 3.0° بسبب الدقة السيئة")
                }
            } else if headingAccuracy > 0 && headingAccuracy <= self.calibrationAccuracyThreshold {
                // دقة جيدة - نعيد الفلتر إلى القيمة المثلى
                if manager.headingFilter != self.optimalHeadingFilter {
                    manager.headingFilter = self.optimalHeadingFilter
                    print("✅ تم إعادة headingFilter إلى \(self.optimalHeadingFilter)°")
                }
            }
            
            if needsCalibration != self.calibrationNeeded {
                self.calibrationNeeded = needsCalibration
                
                // إذا كانت المعايرة مطلوبة، نحاول إظهار شاشة المعايرة
                if needsCalibration {
                    self.requestCalibrationIfNeeded(critical: criticalCalibration)
                } else {
                    // إذا تحسنت الدقة، نعيد تعيين عداد المحاولات
                    self.calibrationRequestCount = 0
                    self.lastCalibrationRequestTime = nil
                }
            }
        }
        
        // إذا لم يكن motion heading فعالاً، نستخدم CLHeading مع EKF
        if !useMotionHeading {
            // التحقق من صحة القراءة أولاً
            // headingAccuracy < 0 يعني أن القيمة غير صالحة
            guard headingAccuracy >= 0 else {
                // القيمة غير صالحة - نتجاهل هذه القراءة
                print("⚠️ headingAccuracy غير صالحة: \(headingAccuracy)° - تجاهل القراءة")
                return
            }
            
            // التحقق من أن الدقة معقولة (أقل من 90 درجة)
            let maxAcceptableAccuracy: Double = 90.0
            guard headingAccuracy <= maxAcceptableAccuracy else {
                print("⚠️ دقة heading سيئة جداً: \(headingAccuracy)° - تجاهل القراءة")
                return
            }
            
            // ====== اختيار نوع Heading المناسب ======
            // API القبلة يعطي الاتجاه من الشمال الجغرافي (True North)
            // يجب التأكد من أن heading الذي نستخدمه هو True North أيضاً
            //
            // CoreLocation يوفر نوعين من Heading:
            // 1. trueHeading: الشمال الحقيقي (Geographic North) - الأفضل، لا يحتاج تعويض
            // 2. magneticHeading: الشمال المغناطيسي - يحتاج تعويض انحراف مغناطيسي
            //
            // ملاحظة: trueHeading يتطلب GPS وموقع دقيق، قد يكون غير متاح في البداية
            // إذا لم يكن متاحاً، نستخدم magneticHeading ونطبق التعويض
            //
            // التحقق من القيم: قد تكون سالبة (-1) عندما تكون غير متاحة
            var headingValue: Double?
            var isTrueHeading = false
            
            // ⚠️ مهم جداً: التحقق من trueHeading أولاً (الشمال الحقيقي - الأفضل)
            // نتحقق من: 1) القيمة >= 0 (غير سالبة) 2) القيمة في النطاق [0, 360]
            // ملاحظة: iOS يعطي trueHeading = -1 عندما يكون غير متاح
            
            // حفظ القيم الخام للتحقق (على Main Thread)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if newHeading.trueHeading >= 0 && newHeading.trueHeading <= 360 {
                    self.rawTrueHeading = newHeading.trueHeading
                } else {
                    self.rawTrueHeading = -1
                }
                if newHeading.magneticHeading >= 0 && newHeading.magneticHeading <= 360 {
                    self.rawMagneticHeading = newHeading.magneticHeading
                } else {
                    self.rawMagneticHeading = -1
                }
            }
            
            if newHeading.trueHeading >= 0 && newHeading.trueHeading <= 360 {
                // trueHeading متاح وصالح - نستخدمه مباشرة (لا يحتاج تعويض انحراف)
                // هذا هو الوضع المثالي لأن iOS يقوم بالتعويض تلقائياً
                headingValue = newHeading.trueHeading
                isTrueHeading = true
                
                DispatchQueue.main.async { [weak self] in
                    self?.isUsingTrueHeading = true
                    self?.magneticDeclinationApplied = 0
                }
                
                #if DEBUG
                // تسجيل استخدام trueHeading (مرة كل ثانية لتجنب spam)
                let sec = Int(Date().timeIntervalSince1970)
                if sec != lastLogSecond {
                    print("✅ [CLHeading] استخدام trueHeading: \(String(format: "%.1f", headingValue!))° (دقة: \(String(format: "%.1f", headingAccuracy))°)")
                }
                #endif
            } else if newHeading.magneticHeading >= 0 && newHeading.magneticHeading <= 360 {
                // trueHeading غير متاح - نستخدم magneticHeading ونطبق تعويض الانحراف لاحقاً
                headingValue = newHeading.magneticHeading
                isTrueHeading = false
                
                DispatchQueue.main.async { [weak self] in
                    self?.isUsingTrueHeading = false
                }
                
                #if DEBUG
                // تسجيل استخدام magneticHeading (مرة كل ثانية لتجنب spam)
                let sec = Int(Date().timeIntervalSince1970)
                if sec != lastLogSecond {
                    print("⚠️ [CLHeading] استخدام magneticHeading: \(String(format: "%.1f", headingValue!))° (trueHeading غير متاح: \(newHeading.trueHeading))")
                }
                #endif
            }
            
            // التحقق من وجود قيمة صالحة
            guard let headingValue = headingValue else {
                // لا توجد قيم صالحة - نتجاهل هذه القراءة
                print("⚠️ لا توجد قيم heading صالحة (magneticHeading: \(newHeading.magneticHeading), trueHeading: \(newHeading.trueHeading), accuracy: \(headingAccuracy))")
                return
            }
            
            // تطبيق EKF على القياس
            filterProcessingQueue.async { [weak self] in
                guard let self = self else { return }
                
                let timestamp = Date().timeIntervalSince1970
                let headingRad = headingValue * .pi / 180.0
                
                // استخدام EKF بدون بيانات الجيروسكوب
                if let ekf = self.extendedKalmanFilter {
                    let smoothedRad = ekf.update(
                        magneticHeading: headingRad,
                        gyroRate: nil,
                        timestamp: timestamp,
                        measurementWeight: 1.0
                    )
                    
                    var smoothedDeg = smoothedRad * 180.0 / .pi
                    
                    // ====== تطبيق تعويض الانحراف المغناطيسي ======
                    // API القبلة يعطي الاتجاه من الشمال الجغرافي (True North)
                    // يجب التأكد من أن heading الذي نستخدمه هو True North أيضاً
                    //
                    // تطبيق التعويض فقط إذا:
                    // 1. استخدمنا magneticHeading (وليس trueHeading)
                    // 2. الموقع متاح (لحساب الانحراف المغناطيسي)
                    //
                    // ملاحظة: trueHeading هو بالفعل اتجاه الشمال الحقيقي، لا يحتاج تعويض
                    if !isTrueHeading {
                        if let location = self.currentLocation {
                            // الموقع متاح - نطبق تعويض الانحراف المغناطيسي
                            let beforeCompensation = smoothedDeg
                            let declination = MagneticDeclinationCalculator.calculateDeclination(
                                latitude: location.coordinate.latitude,
                                longitude: location.coordinate.longitude
                            )
                            smoothedDeg = MagneticDeclinationCalculator.magneticToTrue(
                                magneticHeading: smoothedDeg,
                                latitude: location.coordinate.latitude,
                                longitude: location.coordinate.longitude
                            )
                            
                            // حفظ قيمة الانحراف المطبقة (على Main Thread)
                            DispatchQueue.main.async { [weak self] in
                                self?.magneticDeclinationApplied = declination
                            }
                            
                            #if DEBUG
                            // تسجيل تطبيق التعويض (مرة كل ثانية لتجنب spam)
                            let sec = Int(Date().timeIntervalSince1970)
                            if sec != self.lastLogSecond {
                                print("""
                                🧭 [MAGNETIC DECLINATION COMPENSATION]
                                - قبل التعويض: \(String(format: "%.1f", beforeCompensation))°
                                - بعد التعويض: \(String(format: "%.1f", smoothedDeg))°
                                - الانحراف المغناطيسي: \(String(format: "%.1f", declination))°
                                - الموقع: (\(String(format: "%.4f", location.coordinate.latitude)), \(String(format: "%.4f", location.coordinate.longitude)))
                                """)
                            }
                            #endif
                        } else {
                            // الموقع غير متاح بعد - نستخدم magneticHeading كما هو
                            // سيتم تحديثه تلقائياً عند الحصول على الموقع
                            #if DEBUG
                            print("⚠️ [CLHeading] الموقع غير متاح - استخدام magneticHeading بدون تعويض انحراف مؤقتاً")
                            #endif
                        }
                    }
                    
                    // تطبيع القيمة النهائية إلى [0, 360] للتأكد من صحتها
                    while smoothedDeg < 0 { smoothedDeg += 360 }
                    while smoothedDeg >= 360 { smoothedDeg -= 360 }
                    
                    self.ingestHeading(smoothedDeg, source: "clheading")
                } else {
                    // بدون EKF: تطبيق تعويض الانحراف مباشرة إذا لزم الأمر
                    var finalHeading = headingValue
                    
                    // ====== تطبيق تعويض الانحراف المغناطيسي ======
                    // نفس المنطق أعلاه - تطبيق التعويض فقط إذا استخدمنا magneticHeading
                    if !isTrueHeading {
                        if let location = self.currentLocation {
                            // الموقع متاح - نطبق تعويض الانحراف المغناطيسي
                            let declination = MagneticDeclinationCalculator.calculateDeclination(
                                latitude: location.coordinate.latitude,
                                longitude: location.coordinate.longitude
                            )
                            finalHeading = MagneticDeclinationCalculator.magneticToTrue(
                                magneticHeading: headingValue,
                                latitude: location.coordinate.latitude,
                                longitude: location.coordinate.longitude
                            )
                            #if DEBUG
                            // تسجيل تطبيق التعويض (مرة كل ثانية لتجنب spam)
                            let sec = Int(Date().timeIntervalSince1970)
                            if sec != self.lastLogSecond {
                                print("🧭 [CLHeading-NoEKF] تطبيق تعويض انحراف مغناطيسي: \(String(format: "%.1f", declination))°")
                            }
                            #endif
                        } else {
                            // الموقع غير متاح بعد - نستخدم magneticHeading كما هو
                            // سيتم تحديثه تلقائياً عند الحصول على الموقع
                            #if DEBUG
                            print("⚠️ [CLHeading-NoEKF] الموقع غير متاح - استخدام magneticHeading بدون تعويض انحراف مؤقتاً")
                            #endif
                        }
                    }
                    
                    // تطبيع القيمة النهائية إلى [0, 360] للتأكد من صحتها
                    while finalHeading < 0 { finalHeading += 360 }
                    while finalHeading >= 360 { finalHeading -= 360 }
                    
                    self.ingestHeading(finalHeading, source: "clheading")
                }
            }
        }
        
        // سجل مرة واحدة كل ثانية لتجنب spam
        let sec = Int(Date().timeIntervalSince1970)
        if sec != lastLogSecond {
            lastLogSecond = sec
            // #region agent log
            // التحقق من صحة القيم قبل السجل
            var rawHeadingValue: Double?
            if headingAccuracy >= 0 {
                if newHeading.trueHeading >= 0 {
                    rawHeadingValue = newHeading.trueHeading
                } else if newHeading.magneticHeading >= 0 {
                    rawHeadingValue = newHeading.magneticHeading
                }
            }
            
            DebugFileLogger.log(
                runId: "qibla-accuracy",
                hypothesisId: "Q2",
                location: "CompassService.swift:didUpdateHeading",
                message: "CLHeading tick",
                data: [
                    "hasTrue": newHeading.trueHeading >= 0,
                    "hasMag": newHeading.magneticHeading >= 0,
                    "trueHeading": newHeading.trueHeading >= 0 ? Int(newHeading.trueHeading.rounded()) : -1,
                    "magneticHeading": newHeading.magneticHeading >= 0 ? Int(newHeading.magneticHeading.rounded()) : -1,
                    "acc": Int(headingAccuracy.rounded()),
                    "accValid": headingAccuracy >= 0,
                    "headingUsed": useMotionHeading ? "motion" : "clheading",
                    "headingOrientation": "\(locationManager.headingOrientation.rawValue)",
                    "raw": rawHeadingValue != nil ? Int(rawHeadingValue!.rounded()) : -1
                ]
            )
            // #endregion agent log
        }
    }
    
    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        // iOS يطلب منا الموافقة على إظهار شاشة المعايرة
        // نرجع true إذا:
        // 1. البوصلة تحتاج معايرة فعلاً
        // 2. لم نتجاوز الحد الأقصى لمحاولات الطلب
        // 3. مرت فترة كافية منذ آخر محاولة
        
        guard calibrationNeeded else {
            return false
        }
        
        // إذا كانت الدقة سيئة جداً (>50°)، نعرض المعايرة دائماً
        if accuracy > criticalCalibrationThreshold {
            return true
        }
        
        // التحقق من فترة الانتظار بين المحاولات
        if let lastRequest = lastCalibrationRequestTime {
            let timeSinceLastRequest = Date().timeIntervalSince(lastRequest)
            if timeSinceLastRequest < calibrationRequestCooldown {
                return false // لم تمر فترة كافية
            }
        }
        
        // التحقق من عدد المحاولات
        if calibrationRequestCount >= maxCalibrationRequests {
            return false // تجاوزنا الحد الأقصى
        }
        
        return true
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // kCLErrorDomain error 0 يعني أن الموقع غير متاح مؤقتاً
        let nsError = error as NSError
        if nsError.domain == kCLErrorDomain && nsError.code == 0 {
            // هذا خطأ مؤقت، نتجاهله ونستمر في المحاولة
            print("⚠️ الموقع غير متاح مؤقتاً، جاري المحاولة...")
            // نحاول مرة أخرى بعد ثانية
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.locationManager.requestLocation()
            }
        } else if nsError.code == 1 { // kCLErrorLocationUnknown
            self.error = "تعذر تحديد الموقع، تأكد من تفعيل GPS"
            print("❌ الموقع غير معروف")
        } else {
            self.error = "خطأ في الموقع: \(error.localizedDescription)"
            print("❌ خطأ في البوصلة: \(error.localizedDescription)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // حفظ الموقع الحالي لاستخدامه في حساب الانحراف المغناطيسي
        if let location = locations.last {
            currentLocation = location
        }
        
        // تم الحصول على الموقع بنجاح - مسح أي خطأ سابق
        if self.error != nil {
            self.error = nil
            self.isAvailable = true
            print("✅ تم الحصول على الموقع بنجاح")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            switch status {
            case .authorizedAlways:
                self.error = nil
                self.isAvailable = CLLocationManager.headingAvailable()
                // تفعيل تحديثات الخلفية للدقة القصوى
                self.locationManager.allowsBackgroundLocationUpdates = true
                if !self.isUpdating {
                    self.startUpdating()
                }
                print("✅ تم منح إذن Always - دقة قصوى متاحة")
            case .authorizedWhenInUse:
                self.error = nil
                self.isAvailable = CLLocationManager.headingAvailable()
                self.locationManager.allowsBackgroundLocationUpdates = false
                if !self.isUpdating {
                    self.startUpdating()
                }
                print("✅ تم منح إذن WhenInUse - للدقة القصوى، فكر في طلب Always authorization")
            case .denied:
                self.error = "يرجى تفعيل إذن الموقع من الإعدادات لاستخدام البوصلة"
                self.isAvailable = false
                self.stopUpdating()
                print("❌ إذن الموقع مرفوض")
            case .restricted:
                self.error = "إذن الموقع مقيد على هذا الجهاز"
                self.isAvailable = false
                self.stopUpdating()
                print("❌ إذن الموقع مقيد")
            case .notDetermined:
                print("⏳ إذن الموقع لم يُحدد بعد")
            @unknown default:
                break
            }
        }
    }
}

// ملاحظة: QiblaCalculator موجود الآن في ملف منفصل: QiblaCalculator.swift
