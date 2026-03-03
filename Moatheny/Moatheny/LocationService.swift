import Foundation
import CoreLocation
import Combine
import MapKit

/// Handles location permission and updates.
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentCityName: String = ""
    private let manager = CLLocationManager()
    private var reverseGeocodeTask: Task<Void, Never>?
    private var reverseGeocodeRequest: MKReverseGeocodingRequest?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest // أعلى دقة للموقع
        manager.distanceFilter = kCLDistanceFilterNone
        authorizationStatus = manager.authorizationStatus
    }

    func request() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }
    
    func startUpdating() {
        manager.startUpdatingLocation()
    }
    
    func stopUpdating() {
        manager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // استخدم آخر موقع وأدقه
        if let location = locations.last {
            currentLocation = location
            
            // حفظ اسم المدينة في UserDefaults المشترك للويدجت
            saveCityName(for: location)
        }
    }
    
    private func saveCityName(for location: CLLocation) {
        // إلغاء أي طلب سابق (بديل cancelGeocode في iOS 26)
        reverseGeocodeTask?.cancel()
        reverseGeocodeRequest?.cancel()
        
        reverseGeocodeTask = Task { [weak self] in
            guard let self else { return }
            
            var cityName = "الموقع الحالي"
            do {
                // iOS 26+: بديل CLGeocoder
                guard let request = MKReverseGeocodingRequest(location: location) else {
                    throw NSError(domain: "Moatheny.LocationService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create MKReverseGeocodingRequest"])
                }
                self.reverseGeocodeRequest = request
                let mapItems = try await request.mapItems
                let item = mapItems.first
                
                // أفضلية: اسم المدينة من addressRepresentations ثم name ثم address
                if let reps = item?.addressRepresentations,
                   let city = reps.cityName ?? reps.cityWithContext,
                   !city.isEmpty {
                    cityName = city
                } else if let n = item?.name, !n.isEmpty {
                    cityName = n
                } else if let short = item?.address?.shortAddress, !short.isEmpty {
                    cityName = short.components(separatedBy: ",").first ?? short
                } else if let full = item?.address?.fullAddress, !full.isEmpty {
                    cityName = full.components(separatedBy: ",").first ?? full
                }
            } catch {
                // فشل الجلب ليس قاتلاً، نكتفي بالقيمة الافتراضية
                print("Reverse geocoding error: \(error.localizedDescription)")
            }
            
            if Task.isCancelled { return }
            self.reverseGeocodeRequest = nil
            
            // تقصير الاسم لو كان طويلاً جداً
            if cityName.count > 50 {
                cityName = cityName.components(separatedBy: ",").first ?? cityName
            }
            
            await MainActor.run {
                self.currentCityName = cityName
            }
            
            // حفظ في UserDefaults المشترك
            if let sharedDefaults = UserDefaults(suiteName: "group.com.YourMangaApp.Moatheny") {
                sharedDefaults.set(cityName, forKey: "lastKnownCity")
                sharedDefaults.set(location.coordinate.latitude, forKey: "lastKnownLatitude")
                sharedDefaults.set(location.coordinate.longitude, forKey: "lastKnownLongitude")
                sharedDefaults.synchronize()
            }
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let nsError = error as NSError
        
        // kCLErrorDomain error 0 يعني أن الموقع غير متاح مؤقتاً
        if nsError.domain == kCLErrorDomain && nsError.code == 0 {
            print("⚠️ الموقع غير متاح مؤقتاً، جاري المحاولة...")
            // نحاول مرة أخرى بعد ثانيتين
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.manager.requestLocation()
            }
        } else if nsError.code == 1 { // kCLErrorLocationUnknown
            print("❌ الموقع غير معروف، تأكد من تفعيل GPS")
        } else {
            // ✅ Security Fix: Logging آمن بدون تفاصيل حساسة
            // تم إزالة print() لتجنب تسريب معلومات في logs
            #if DEBUG
            print("❌ Location error occurred")
            #endif
        }
    }
}

