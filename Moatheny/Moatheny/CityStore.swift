import Foundation
import CoreLocation
import Combine

/// مدينة محفوظة للاختيار اليدوي (تعمل كـ "ملف مستخدم" محلي حسب المدينة).
struct SavedCity: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    
    init(id: UUID = UUID(), name: String, latitude: Double, longitude: Double) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// إدارة المدينة الحالية (GPS أو مدينة مختارة يدوياً) مع حفظ محلي.
@MainActor
final class CityStore: ObservableObject {
    @Published var useCurrentLocation: Bool {
        didSet { persist() }
    }
    
    @Published var selectedCityId: UUID? {
        didSet { persist() }
    }
    
    @Published var savedCities: [SavedCity] {
        didSet { persist() }
    }
    
    private let defaults: UserDefaults
    private let location: LocationService
    
    private let keyUseCurrent = "CityStore.useCurrentLocation"
    private let keySelectedId = "CityStore.selectedCityId"
    private let keySavedCities = "CityStore.savedCities"
    
    init(location: LocationService, defaults: UserDefaults = .standard) {
        self.location = location
        self.defaults = defaults
        
        self.useCurrentLocation = defaults.object(forKey: keyUseCurrent) as? Bool ?? true
        
        if let idStr = defaults.string(forKey: keySelectedId), let uuid = UUID(uuidString: idStr) {
            self.selectedCityId = uuid
        } else {
            self.selectedCityId = nil
        }
        
        if let data = defaults.data(forKey: keySavedCities),
           let decoded = try? JSONDecoder().decode([SavedCity].self, from: data) {
            self.savedCities = decoded
        } else {
            self.savedCities = []
        }
        
        // ضمان حالة منطقية
        if useCurrentLocation == false, selectedCityId == nil, let first = savedCities.first {
            selectedCityId = first.id
        }
    }
    
    var activeCity: SavedCity? {
        guard !useCurrentLocation, let id = selectedCityId else { return nil }
        return savedCities.first(where: { $0.id == id })
    }
    
    var activeCityName: String {
        if useCurrentLocation {
            return location.currentCityName.isEmpty ? "الموقع الحالي" : location.currentCityName
        }
        return activeCity?.name ?? "مدينة غير محددة"
    }
    
    var activeCoordinate: CLLocationCoordinate2D? {
        if useCurrentLocation {
            return location.currentLocation?.coordinate
        }
        return activeCity?.coordinate
    }
    
    /// مفتاح كاش مستقل لكل مدينة/ملف.
    var activeCacheKey: String {
        if useCurrentLocation {
            return "gps"
        }
        return activeCity?.id.uuidString ?? "manual"
    }
    
    func selectCurrentLocation() {
        useCurrentLocation = true
    }
    
    func selectCity(_ city: SavedCity) {
        if !savedCities.contains(city) {
            savedCities.append(city)
        }
        selectedCityId = city.id
        useCurrentLocation = false
    }
    
    func deleteCity(_ city: SavedCity) {
        savedCities.removeAll(where: { $0.id == city.id })
        if selectedCityId == city.id {
            selectedCityId = savedCities.first?.id
            if selectedCityId == nil {
                useCurrentLocation = true
            }
        }
    }
    
    private func persist() {
        defaults.set(useCurrentLocation, forKey: keyUseCurrent)
        if let id = selectedCityId {
            defaults.set(id.uuidString, forKey: keySelectedId)
        } else {
            defaults.removeObject(forKey: keySelectedId)
        }
        if let data = try? JSONEncoder().encode(savedCities) {
            defaults.set(data, forKey: keySavedCities)
        }
    }
}

