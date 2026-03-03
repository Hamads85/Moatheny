import Foundation
import CoreLocation
import Combine

/// خدمة البوصلة البسيطة - تستخدم CLLocationManager فقط
/// 
/// المبادئ:
/// - KISS (Keep It Simple Stupid)
/// - استخدام trueHeading مباشرة من iOS
/// - لا حاجة لـ Kalman Filter أو DeviceMotion
/// - بسيط، واضح، وفعال
final class SimpleCompassService: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var heading: Double = 0           // الاتجاه الحقيقي (0-360)
    @Published var accuracy: Double = -1          // دقة القراءة
    @Published var isAvailable = false            // هل البوصلة متاحة
    @Published var error: String?                 // رسالة الخطأ
    @Published var calibrationNeeded = false      // هل تحتاج معايرة
    
    // خصائص إضافية للتوافق مع Views.swift
    /// هل الجهاز مسطح (دائماً true لأن SimpleCompassService لا يستخدم DeviceMotion)
    @Published var isDeviceFlat = true
    /// الميل للأمام/الخلف (دائماً 0 لأن SimpleCompassService لا يستخدم DeviceMotion)
    @Published var pitch: Double = 0
    /// الميل للجانب (دائماً 0 لأن SimpleCompassService لا يستخدم DeviceMotion)
    @Published var roll: Double = 0
    /// trueHeading الخام من iOS (للتحقق)
    @Published var rawTrueHeading: Double = -1
    /// magneticHeading الخام من iOS (للتحقق)
    @Published var rawMagneticHeading: Double = -1
    /// هل نستخدم trueHeading أم magneticHeading
    @Published var isUsingTrueHeading: Bool = false
    /// قيمة الانحراف المغناطيسي المطبقة (دائماً 0 لأننا نستخدم trueHeading)
    @Published var magneticDeclinationApplied: Double = 0
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private var isUpdating = false
    
    // إعدادات البوصلة
    private let headingFilter: CLLocationDirection = 1.0  // درجة واحدة - توازن بين الدقة والأداء
    /// عتبة المعايرة بالدرجات - إذا كانت الدقة أسوأ من هذا، نحتاج معايرة
    private let calibrationThreshold: Double = 25.0
    
    // MARK: - Deinitialization
    deinit {
        stopUpdating()
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        locationManager.delegate = self
        isAvailable = CLLocationManager.headingAvailable()
    }
    
    // MARK: - Public Methods
    
    /// بدء تحديث البوصلة
    func startUpdating() {
        guard !isUpdating else { return }
        guard CLLocationManager.headingAvailable() else {
            error = "البوصلة غير متاحة على هذا الجهاز"
            isAvailable = false
            return
        }
        
        // طلب الإذن إذا لم يكن متاحاً
        let authStatus = locationManager.authorizationStatus
        if authStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            return
        }
        
        guard authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways else {
            error = "يرجى تفعيل إذن الموقع من الإعدادات لاستخدام البوصلة"
            isAvailable = false
            return
        }
        
        // إعدادات البوصلة
        locationManager.headingFilter = headingFilter
        locationManager.headingOrientation = .portrait
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = kCLDistanceFilterNone
        
        // بدء التحديثات
        locationManager.startUpdatingHeading()
        locationManager.startUpdatingLocation() // مطلوب للحصول على trueHeading
        
        isUpdating = true
        error = nil
        isAvailable = true
    }
    
    /// إيقاف تحديث البوصلة
    func stopUpdating() {
        guard isUpdating else { return }
        locationManager.stopUpdatingHeading()
        locationManager.stopUpdatingLocation()
        isUpdating = false
    }
    
    /// طلب معايرة البوصلة
    func requestCalibration() {
        // iOS يعرض شاشة المعايرة تلقائياً عند الحاجة
        // لكن يمكننا إجبارها عن طريق تغيير headingFilter مؤقتاً
        let originalFilter = locationManager.headingFilter
        locationManager.headingFilter = 0.1 // قيمة صغيرة جداً لإجبار المعايرة
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.locationManager.headingFilter = originalFilter
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension SimpleCompassService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // تحديث الدقة
            self.accuracy = newHeading.headingAccuracy
            
            // تحديد الحاجة للمعايرة
            self.calibrationNeeded = newHeading.headingAccuracy < 0 || 
                                    newHeading.headingAccuracy > self.calibrationThreshold
            
            // حفظ القيم الخام للتحقق
            self.rawTrueHeading = newHeading.trueHeading
            self.rawMagneticHeading = newHeading.magneticHeading
            
            // استخدام trueHeading إذا كان متاحاً، وإلا magneticHeading
            var headingValue: Double
            if newHeading.trueHeading >= 0 && newHeading.trueHeading <= 360 {
                headingValue = newHeading.trueHeading
                self.isUsingTrueHeading = true
            } else {
                headingValue = newHeading.magneticHeading
                self.isUsingTrueHeading = false
            }
            
            // تطبيع الزاوية إلى 0-360
            var normalizedHeading = headingValue.truncatingRemainder(dividingBy: 360)
            if normalizedHeading < 0 {
                normalizedHeading += 360
            }
            
            self.heading = normalizedHeading
            
            #if DEBUG
            // طباعة للتحقق
            print("🧭 Heading: \(String(format: "%.1f", normalizedHeading))° | trueHeading: \(String(format: "%.1f", newHeading.trueHeading))° | magneticHeading: \(String(format: "%.1f", newHeading.magneticHeading))° | using: \(self.isUsingTrueHeading ? "TRUE" : "MAGNETIC")")
            #endif
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.error = "خطأ في البوصلة: \(error.localizedDescription)"
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                self.error = nil
                self.isAvailable = CLLocationManager.headingAvailable()
                if !self.isUpdating {
                    self.startUpdating()
                }
            case .denied:
                self.error = "يرجى تفعيل إذن الموقع من الإعدادات لاستخدام البوصلة"
                self.isAvailable = false
                self.stopUpdating()
            case .restricted:
                self.error = "إذن الموقع مقيد على هذا الجهاز"
                self.isAvailable = false
                self.stopUpdating()
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }
    
    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        // السماح لـ iOS بعرض شاشة المعايرة تلقائياً عند الحاجة
        return calibrationNeeded
    }
}
