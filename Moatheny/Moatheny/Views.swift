import SwiftUI
import CoreLocation
import MapKit
import UIKit

// MARK: - Qibla Theme (Dark-Blue & Gold Luxury)
private enum QiblaTheme {
    static let background = Color(hex: "0A1024")
    static let surface = Color(hex: "0F1833").opacity(0.92)
    static let accent = Color(hex: "D4AF37")
    static let accentStrong = Color(hex: "00D26A")
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let stroke = Color.white.opacity(0.12)
}

// MARK: - Root Tab View
struct RootTabView: View {
    var body: some View {
        TabView {
            PrayerTimesView()
                .tabItem { Label("الصلاة", systemImage: "clock") }
            QuranView()
                .tabItem { Label("القرآن", systemImage: "book") }
            AzkarView()
                .tabItem { Label("الأذكار", systemImage: "hands.sparkles") }
            MoreView()
                .tabItem { Label("المزيد", systemImage: "ellipsis") }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar"))
    }
}

// MARK: - Prayer Times View
struct PrayerTimesView: View {
    @EnvironmentObject var vm: PrayerTimesViewModel
    @EnvironmentObject var container: AppContainer
    @EnvironmentObject var cityStore: CityStore
    
    @State private var showCityPicker = false

    var body: some View {
        NavigationView {
            ZStack {
                // خلفية متدرجة
                LinearGradient(
                    colors: [Color(hex: "1B4332"), Color(hex: "2D6A4F")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
            Group {
                if let day = vm.day {
                        ScrollView {
                            VStack(spacing: 16) {
                                // بطاقة التاريخ
                                DateCard(
                                    cityName: day.cityName ?? cityStore.activeCityName,
                                    hijriDate: day.hijriDate ?? container.hijri.hijriString(for: day.date)
                                )
                                
                                // أوقات الصلاة
                                ForEach(day.prayers) { prayer in
                                    PrayerCard(prayer: prayer)
                                }
                            }
                            .padding()
                    }
                } else if vm.isLoading {
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text("جاري تحميل أوقات الصلاة...")
                                .foregroundColor(.white)
                        }
                    } else if vm.error != nil {
                        VStack(spacing: 16) {
                            Image(systemName: "location.slash")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.7))
                            Text("الموقع غير متاح")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                            Text("يرجى تفعيل خدمات الموقع من الإعدادات")
                                .foregroundColor(.white.opacity(0.8))
                            Button("طلب الموقع") {
                                container.location.request()
                                Task { await vm.refresh() }
                            }
                            .buttonStyle(GreenButtonStyle())
                        }
                } else {
                        VStack(spacing: 16) {
                            Image(systemName: "clock")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.7))
                            Text("اضغط لتحميل أوقات الصلاة")
                                .foregroundColor(.white)
                            Button("تحميل أوقات الصلاة") {
                                container.location.request()
                                Task { await vm.refresh() }
                            }
                            .buttonStyle(GreenButtonStyle())
                        }
                    }
                }
            }
            .navigationTitle("أوقات الصلاة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showCityPicker = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.and.ellipse")
                            Text(cityStore.activeCityName)
                                .lineLimit(1)
                                .font(.caption.bold())
                        }
                        .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        container.location.request()
                        Task { await vm.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.white)
                    }
                }
            }
            .onAppear {
                container.location.request()
                Task { await vm.refresh() }
            }
            .environment(\.layoutDirection, .rightToLeft)
            .sheet(isPresented: $showCityPicker) {
                CityPickerSheet()
                    .environmentObject(cityStore)
            }
        }
    }
}

// MARK: - Date Card
struct DateCard: View {
    let cityName: String
    let hijriDate: String
    
    var body: some View {
        VStack(spacing: 8) {
            // اسم المدينة: في منتصف الشاشة وبنفس حجم التاريخ
            Text(cityName)
                .font(.headline) // نفس حجم التاريخ (Date(), style: .date) في هذا الكارت
                .foregroundColor(Color(hex: "D4AF37"))
                .frame(maxWidth: .infinity, alignment: .center)
                .environment(\.layoutDirection, .rightToLeft)
            
            Text(Date(), style: .date)
                .font(.headline)
                .foregroundColor(.white)
            
            // التاريخ الهجري
            Text(hijriDate)
                .font(.title2.bold())
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.15))
        .cornerRadius(16)
    }
}

// MARK: - City Picker Sheet
struct CityPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var cityStore: CityStore
    
    @State private var showSearch = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Toggle("استخدام موقعي الحالي (GPS)", isOn: $cityStore.useCurrentLocation)
                        .environment(\.layoutDirection, .rightToLeft)
                }
                
                Section(header: Text("مدن محفوظة").environment(\.layoutDirection, .rightToLeft)) {
                    if cityStore.savedCities.isEmpty {
                        Text("لا توجد مدن محفوظة بعد")
                            .foregroundColor(.secondary)
                            .environment(\.layoutDirection, .rightToLeft)
                    }
                    
                    ForEach(cityStore.savedCities) { city in
                        Button {
                            cityStore.selectCity(city)
                            dismiss()
                        } label: {
                            HStack {
                                if cityStore.selectedCityId == city.id && !cityStore.useCurrentLocation {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color(hex: "43AA8B"))
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(city.name)
                                    .foregroundColor(.primary)
                            }
                            .environment(\.layoutDirection, .rightToLeft)
                        }
                    }
                    .onDelete { indexSet in
                        for idx in indexSet {
                            let city = cityStore.savedCities[idx]
                            cityStore.deleteCity(city)
                        }
                    }
                }
            }
            .navigationTitle("المدينة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("تم") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSearch = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showSearch) {
                CitySearchView()
                    .environmentObject(cityStore)
            }
        }
    }
}

// MARK: - City Search (MapKit)
struct CitySearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var cityStore: CityStore
    
    @State private var query: String = ""
    @State private var results: [MKMapItem] = []
    @State private var isSearching = false
    @State private var error: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                HStack {
                    TextField("ابحث عن مدينة…", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .environment(\.layoutDirection, .rightToLeft)
                    
                    Button("بحث") {
                        Task { await search() }
                    }
                    .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
                }
                .padding(.horizontal)
                
                if let error {
                    Text(error)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                        .environment(\.layoutDirection, .rightToLeft)
                }
                
                List {
                    ForEach(results, id: \.self) { item in
                        Button {
                            let name = item.name ?? query
                            let c = item.location.coordinate
                            cityStore.selectCity(SavedCity(name: name, latitude: c.latitude, longitude: c.longitude))
                            dismiss()
                        } label: {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(item.name ?? "بدون اسم")
                                    .font(.headline)
                                if let reps = item.addressRepresentations,
                                   let addr = reps.fullAddress(includingRegion: true, singleLine: true) {
                                    Text(addr)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else if let short = item.address?.shortAddress {
                                    Text(short)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else if let full = item.address?.fullAddress {
                                    Text(full)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .environment(\.layoutDirection, .rightToLeft)
                        }
                    }
                }
            }
            .navigationTitle("إضافة مدينة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("إلغاء") { dismiss() }
                }
            }
        }
    }
    
    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        await MainActor.run {
            isSearching = true
            error = nil
        }
        
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = trimmed
        // region اختياري: لو عندنا GPS نستخدمه لتحسين النتائج
        if let coord = cityStore.activeCoordinate {
            req.region = MKCoordinateRegion(center: coord, latitudinalMeters: 500_000, longitudinalMeters: 500_000)
        }
        
        do {
            let resp = try await MKLocalSearch(request: req).start()
            await MainActor.run {
                results = resp.mapItems
                isSearching = false
                if results.isEmpty {
                    error = "لا توجد نتائج، جرّب كتابة الاسم بشكل مختلف"
                }
            }
        } catch {
            await MainActor.run {
                isSearching = false
                self.error = "تعذر البحث الآن: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Prayer Card (محسّن)
struct PrayerCard: View {
    let prayer: Prayer
    
    // تحديد الأيقونة حسب الصلاة
    var prayerIcon: String {
        switch prayer.name.lowercased() {
        case "fajr": return "sun.haze.fill"
        case "sunrise": return "sunrise.fill"
        case "dhuhr": return "sun.max.fill"
        case "asr": return "sun.min.fill"
        case "maghrib": return "sunset.fill"
        case "isha": return "moon.stars.fill"
        default: return "clock.fill"
        }
    }
    
    // لون مميز لكل صلاة
    var accentColor: Color {
        switch prayer.name.lowercased() {
        case "fajr": return Color(hex: "7B68EE")
        case "sunrise": return Color(hex: "FFB347")
        case "dhuhr": return Color(hex: "FFD700")
        case "asr": return Color(hex: "F4A460")
        case "maghrib": return Color(hex: "FF6B6B")
        case "isha": return Color(hex: "6C63FF")
        default: return Color(hex: "D4AF37")
        }
    }
    
    // هل هذه الصلاة القادمة؟
    var isNextPrayer: Bool {
        return prayer.time > Date() && prayer.time.timeIntervalSinceNow < 3600 * 6
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // الوقت على اليسار
            VStack(alignment: .leading, spacing: 2) {
                Text(prayer.time.formattedTime())
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(isNextPrayer ? Color(hex: "D4AF37") : .white)
                
                // الوقت المتبقي
                if isNextPrayer {
                    Text(timeRemaining())
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Spacer()
            
            // اسم الصلاة على اليمين
            VStack(alignment: .trailing, spacing: 4) {
                Text(prayer.arabicName)
                    .font(.headline)
                    .foregroundColor(.white)
                
                if isNextPrayer {
                    Text(timeRemainingShort())
                        .font(.caption2.bold())
                        .foregroundColor(Color(hex: "90BE6D"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(hex: "90BE6D").opacity(0.2))
                        .cornerRadius(4)
                }
            }
            
            // أيقونة الصلاة على أقصى اليمين
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: prayerIcon)
                    .font(.system(size: 22))
                    .foregroundColor(accentColor)
            }
        }
        .padding()
        .environment(\.layoutDirection, .rightToLeft)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(isNextPrayer ? 0.2 : 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isNextPrayer ? Color(hex: "D4AF37").opacity(0.5) : Color.clear, lineWidth: 1)
                )
        )
    }
    
    private func timeRemaining() -> String {
        let interval = prayer.time.timeIntervalSinceNow
        if interval <= 0 { return "" }
        
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if hours > 0 {
            return "باقي \(hours) ساعة و \(minutes) دقيقة"
        } else {
            return "باقي \(minutes) دقيقة"
        }
    }
    
    private func timeRemainingShort() -> String {
        let interval = prayer.time.timeIntervalSinceNow
        if interval <= 0 { return "الآن" }
        
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if hours > 0 {
            return "باقي \(hours)س \(minutes)د"
        } else if minutes > 0 {
            return "باقي \(minutes) دقيقة"
        } else {
            return "أقل من دقيقة"
        }
    }
}

// MARK: - Quran View
struct QuranView: View {
    @EnvironmentObject var vm: QuranViewModel
    @State private var searchText = ""
    @AppStorage("last_read_surah") private var lastReadSurah: Int = 0
    @AppStorage("last_read_ayah") private var lastReadAyah: Int = 0
    
    var filteredSurahs: [Surah] {
        if searchText.isEmpty {
            return vm.surahs
        }
        return vm.surahs.filter {
            $0.name.contains(searchText) ||
            $0.englishName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // الحصول على السورة المحفوظة
    var lastReadSurahData: Surah? {
        vm.surahs.first { $0.id == lastReadSurah }
    }
    
    // تحويل الأرقام إلى عربية
    private func toArabicNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ar")
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0D1B2A").ignoresSafeArea()
                
                Group {
                    if vm.isLoading {
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text("جاري تحميل القرآن الكريم...")
                                .foregroundColor(.white)
                        }
                    } else if let err = vm.error {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 60))
                                .foregroundColor(.yellow)
                            Text("خطأ في تحميل القرآن")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                            Button("إعادة المحاولة") {
                                Task { await vm.load() }
                            }
                            .buttonStyle(GoldButtonStyle())
                        }
                        .padding()
                    } else if vm.surahs.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.5))
                            Text("لا توجد بيانات")
                                .foregroundColor(.white)
                            Button("تحميل القرآن") {
                                Task { await vm.load() }
                            }
                            .buttonStyle(GoldButtonStyle())
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                // زر متابعة القراءة (إذا كان هناك موضع محفوظ)
                                if let savedSurah = lastReadSurahData, lastReadAyah > 0 {
                                    NavigationLink(destination: SurahDetailView(surah: savedSurah)) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "bookmark.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(Color(hex: "D4AF37"))
                                            
                                            VStack(alignment: .trailing, spacing: 4) {
                                                Text("متابعة القراءة")
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                                Text("\(savedSurah.name) - الآية \(toArabicNumber(lastReadAyah))")
                                                    .font(.subheadline)
                                                    .foregroundColor(.white.opacity(0.7))
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.left")
                                                .foregroundColor(Color(hex: "D4AF37"))
                                        }
                                        .padding()
                                        .background(
                                            LinearGradient(
                                                colors: [Color(hex: "D4AF37").opacity(0.2), Color(hex: "B8860B").opacity(0.1)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .cornerRadius(16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color(hex: "D4AF37").opacity(0.5), lineWidth: 1)
                                        )
                                    }
                                    .environment(\.layoutDirection, .rightToLeft)
                                }
                                
                                ForEach(filteredSurahs) { surah in
                NavigationLink(destination: SurahDetailView(surah: surah)) {
                                        SurahCard(surah: surah)
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("القرآن الكريم")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "ابحث عن سورة...")
            .task { await vm.load() }
        }
    }
}

// MARK: - Surah Card
struct SurahCard: View {
    let surah: Surah
    
    var body: some View {
        HStack(spacing: 16) {
            // رقم السورة (سيظهر على اليمين مع RTL)
            ZStack {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: "D4AF37"))
                Text("\(surah.id)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // اسم السورة (وسط)
            VStack(alignment: .trailing, spacing: 4) {
                Text(surah.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Text(surah.englishName)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            // عدد الآيات ونوع السورة (سيظهر على اليسار مع RTL)
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(surah.numberOfAyahs) آية")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                Text(surah.revelationType == "Meccan" ? "مكية" : "مدنية")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: "D4AF37").opacity(0.3))
                    .cornerRadius(8)
                    .foregroundColor(Color(hex: "D4AF37"))
            }
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - Surah Detail View
struct SurahDetailView: View {
    let surah: Surah
    @EnvironmentObject var container: AppContainer
    @EnvironmentObject var audio: AudioPlayerService
    @EnvironmentObject var mp3Quran: MP3QuranService
    @EnvironmentObject var quranVM: QuranViewModel
    @State private var fontSize: CGFloat = 24
    @State private var showReciterPicker = false
    @State private var selectedReciter: MP3Reciter?
    @State private var showMushafMode = false
    
    @AppStorage("last_read_surah") private var lastReadSurah: Int = 0
    @AppStorage("last_read_ayah") private var lastReadAyah: Int = 0
    @State private var scrollProxy: ScrollViewProxy?
    @State private var showBookmarkSaved = false
    
    // حساب الجزء والحزب
    var juzNumber: Int {
        if let firstAyah = surah.ayahs.first {
            return firstAyah.juz
        }
        return min(30, max(1, (surah.id - 1) / 4 + 1))
    }
    
    var hizbNumber: Int {
        if let firstAyah = surah.ayahs.first {
            return firstAyah.hizb
        }
        return (juzNumber - 1) * 2 + 1
    }
    
    private var continuousSurahs: [Surah] {
        guard !quranVM.surahs.isEmpty,
              let idx = quranVM.surahs.firstIndex(where: { $0.id == surah.id }) else {
            return [surah]
        }
        return Array(quranVM.surahs[idx...])
    }
    
    // تحويل الأرقام إلى عربية
    private func toArabicNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ar")
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    // التحقق من توفر السورة للقارئ المختار
    private var isSurahAvailable: Bool {
        guard let reciter = selectedReciter ?? mp3Quran.currentReciter,
              let moshaf = reciter.moshaf.first else { return false }
        return moshaf.surahList.contains(surah.id)
    }
    
    var body: some View {
        ZStack {
            Color(hex: "0D1B2A").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // شريط التشغيل الثابت في الأعلى إذا كان يعمل
                if audio.isPlaying && audio.currentTitle.contains(surah.name) {
                    AudioPlayerBar()
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.3))
                }
                
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 20) {
                            // شريط الإشارة المرجعية (إذا كان هناك موضع محفوظ في هذه السورة)
                            if lastReadSurah == surah.id && lastReadAyah > 0 {
                                Button {
                                    withAnimation {
                                        proxy.scrollTo("ayah_\(lastReadAyah)", anchor: .top)
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "bookmark.fill")
                                            .foregroundColor(Color(hex: "D4AF37"))
                                        Text("متابعة من الآية \(toArabicNumber(lastReadAyah))")
                                            .font(.subheadline.bold())
                                            .foregroundColor(.white)
                                        Spacer()
                                        Image(systemName: "arrow.down.circle.fill")
                                            .foregroundColor(Color(hex: "D4AF37"))
                                    }
                                    .padding()
                                    .background(
                                        LinearGradient(
                                            colors: [Color(hex: "D4AF37").opacity(0.2), Color(hex: "B8860B").opacity(0.1)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(hex: "D4AF37").opacity(0.5), lineWidth: 1)
                                    )
                                }
                                .padding(.horizontal)
                            }
                            
                            // رسالة تأكيد الحفظ
                            if showBookmarkSaved {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("تم حفظ موضع القراءة")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                                .transition(.opacity)
                            }
                            
                            // معلومات السورة (الجزء والحزب والآيات)
                            HStack(spacing: 12) {
                                VStack(spacing: 4) {
                                    Text("الجزء")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                    Text(toArabicNumber(juzNumber))
                                        .font(.title2.bold())
                                        .foregroundColor(Color(hex: "D4AF37"))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)
                                
                                VStack(spacing: 4) {
                                    Text("الحزب")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                    Text(toArabicNumber(hizbNumber))
                                        .font(.title2.bold())
                                        .foregroundColor(Color(hex: "D4AF37"))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)
                                
                                VStack(spacing: 4) {
                                    Text("الآيات")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                    Text(toArabicNumber(surah.numberOfAyahs))
                                        .font(.title2.bold())
                                        .foregroundColor(Color(hex: "D4AF37"))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .environment(\.layoutDirection, .rightToLeft)
                        
                        // شريط تشغيل السورة
                        VStack(spacing: 12) {
                            HStack(spacing: 16) {
                                // زر التشغيل على اليمين
                                Button {
                                    togglePlayback()
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(audio.isPlaying && audio.currentTitle.contains(surah.name) ? "إيقاف" : "تشغيل")
                                        Image(systemName: audio.isPlaying && audio.currentTitle.contains(surah.name) ? "stop.fill" : "play.fill")
                                    }
                                    .font(.subheadline.bold())
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(isSurahAvailable ? Color(hex: "D4AF37") : Color.gray)
                                    .cornerRadius(8)
                                }
                                .disabled(!isSurahAvailable)
                                
                                Spacer()
                                
                                // اختيار القارئ على اليسار
                                Button {
                                    showReciterPicker = true
                                } label: {
                                    HStack(spacing: 8) {
                                        Text(selectedReciter?.name ?? mp3Quran.currentReciter?.name ?? "اختر القارئ")
                                            .lineLimit(1)
                                        Image(systemName: "person.wave.2.fill")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.15))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal)
                            .environment(\.layoutDirection, .rightToLeft)
                            
                            // رسالة خطأ إذا وجدت
                            if let error = audio.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.horizontal)
                            }
                            
                            // رسالة إذا السورة غير متوفرة
                            if !isSurahAvailable && selectedReciter != nil {
                                Text("⚠️ هذه السورة غير متوفرة لهذا القارئ")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                                    .padding(.horizontal)
                            }
                        }
                        
                        LazyVStack(spacing: 20) {
                            ForEach(continuousSurahs) { currentSurah in
                                if currentSurah.id != surah.id {
                                    surahDivider(for: currentSurah)
                                        .id("surah_\(currentSurah.id)")
                                }
                                
                                if showMushafMode {
                                    mushafInlineContent(for: currentSurah)
                                } else {
                                    if currentSurah.id != 1 && currentSurah.id != 9 {
                                        Text("بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ")
                                            .font(.system(size: fontSize + 4, weight: .medium))
                                            .foregroundColor(Color(hex: "D4AF37"))
                                            .padding()
                                            .frame(maxWidth: .infinity)
                                    }
                                    
                                    ForEach(currentSurah.ayahs) { ayah in
                                        AyahView(
                                            ayah: ayah,
                                            fontSize: fontSize,
                                            selectedReciter: selectedReciter ?? mp3Quran.currentReciter,
                                            surahId: currentSurah.id,
                                            surahName: currentSurah.name,
                                            onBookmark: {
                                                saveReadingPosition(surahId: currentSurah.id, ayahNumber: ayah.numberInSurah)
                                            }
                                        )
                                        .id("ayah_\(currentSurah.id)_\(ayah.numberInSurah)")
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
                .onAppear {
                    scrollProxy = proxy
                }
            }
            }
        }
        .navigationTitle(surah.name)
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.layoutDirection, .rightToLeft)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showMushafMode.toggle()
                        }
                    } label: {
                        Image(systemName: showMushafMode ? "list.bullet" : "book.fill")
                            .foregroundColor(Color(hex: "D4AF37"))
                    }
                    
                    Button {
                        saveReadingPosition(surahId: surah.id, ayahNumber: 1)
                    } label: {
                        Image(systemName: "bookmark")
                            .foregroundColor(Color(hex: "D4AF37"))
                    }
                    
                    Menu {
                        Button("صغير") { fontSize = 20 }
                        Button("متوسط") { fontSize = 24 }
                        Button("كبير") { fontSize = 28 }
                        Button("كبير جداً") { fontSize = 32 }
                    } label: {
                        Image(systemName: "textformat.size")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .sheet(isPresented: $showReciterPicker) {
            ReciterPickerSheet(selectedReciter: $selectedReciter)
        }
        .onAppear {
            // استخدام القارئ الافتراضي إذا لم يتم اختيار قارئ
            if selectedReciter == nil {
                selectedReciter = mp3Quran.currentReciter
            }
        }
    }
    
    private func saveReadingPosition(surahId: Int? = nil, ayahNumber: Int) {
        lastReadSurah = surahId ?? surah.id
        lastReadAyah = ayahNumber
        withAnimation { showBookmarkSaved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showBookmarkSaved = false }
        }
    }
    
    @ViewBuilder
    private func surahDivider(for targetSurah: Surah) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color(hex: "D4AF37").opacity(0.4), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                
                Image(systemName: "star.fill")
                    .font(.system(size: 8))
                    .foregroundColor(Color(hex: "D4AF37").opacity(0.5))
                
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color(hex: "D4AF37").opacity(0.4), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
            }
            .padding(.top, 24)
            
            VStack(spacing: 8) {
                Text(targetSurah.name)
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundColor(Color(hex: "D4AF37"))
                
                HStack(spacing: 16) {
                    Text(targetSurah.revelationType == "Meccan" ? "مكية" : "مدنية")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                    
                    Text("\(toArabicNumber(targetSurah.numberOfAyahs)) آية")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "D4AF37").opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "D4AF37").opacity(0.12), lineWidth: 0.5)
                    )
            )
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
    
    @ViewBuilder
    private func mushafInlineContent(for targetSurah: Surah) -> some View {
        VStack(spacing: 16) {
            if targetSurah.id != 1 && targetSurah.id != 9 {
                Text("بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ")
                    .font(.system(size: fontSize + 2, weight: .medium, design: .serif))
                    .foregroundColor(Color(hex: "D4AF37"))
                    .frame(maxWidth: .infinity)
            }
            
            Text(buildMushafText(for: targetSurah))
                .font(.system(size: fontSize + 2, design: .serif))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(fontSize * 0.75)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 4)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color(hex: "D4AF37").opacity(0.4), Color(hex: "B8860B").opacity(0.15), Color(hex: "D4AF37").opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .environment(\.layoutDirection, .rightToLeft)
    }
    
    private func buildMushafText(for targetSurah: Surah) -> AttributedString {
        var result = AttributedString()
        for ayah in targetSurah.ayahs {
            var verseText = AttributedString(ayah.text + " ")
            verseText.foregroundColor = .white
            var numberText = AttributedString(" \(toArabicNumber(ayah.numberInSurah)) ")
            numberText.foregroundColor = Color(hex: "D4AF37")
            numberText.font = .system(size: fontSize - 2, weight: .bold, design: .serif)
            result.append(verseText)
            result.append(numberText)
        }
        return result
    }
    
    private func togglePlayback() {
        if audio.isPlaying && audio.currentTitle.contains(surah.name) {
            audio.stop()
        } else {
            // تشغيل السورة
            guard let reciter = selectedReciter ?? mp3Quran.currentReciter else {
                return
            }
            audio.playSurah(reciter: reciter, surahNumber: surah.id, surahName: surah.name)
        }
    }
}

// MARK: - Audio Player Bar (شريط التشغيل)
struct AudioPlayerBar: View {
    @EnvironmentObject var audio: AudioPlayerService
    
    var body: some View {
        VStack(spacing: 8) {
            // شريط التقدم
            if !audio.isStreaming {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 4)
                        
                        Rectangle()
                            .fill(Color(hex: "D4AF37"))
                            .frame(width: geometry.size.width * audio.progress, height: 4)
                    }
                    .cornerRadius(2)
                }
                .frame(height: 4)
            }
            
            HStack {
                // عنوان التشغيل
                Text(audio.currentTitle)
                    .font(.caption)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                // أزرار التحكم
                HStack(spacing: 16) {
                    Button {
                        audio.togglePlayPause()
                    } label: {
                        Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                    
                    Button {
                        audio.stop()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

// MARK: - Reciter Picker Sheet
struct ReciterPickerSheet: View {
    @Binding var selectedReciter: MP3Reciter?
    @Environment(\.dismiss) var dismiss
    @StateObject private var mp3Service = MP3QuranService()
    @State private var searchText = ""
    
    var filteredReciters: [MP3Reciter] {
        if searchText.isEmpty { return mp3Service.reciters }
        return mp3Service.reciters.filter { $0.name.contains(searchText) }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0D1B2A").ignoresSafeArea()
                
                if mp3Service.isLoading {
                    VStack(spacing: 12) {
                        ProgressView().tint(.white)
                        Text("جاري تحميل القراء...")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                } else if filteredReciters.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white.opacity(0.5))
                        Text("لا يوجد قراء")
                            .foregroundColor(.white.opacity(0.7))
                    }
                } else {
                    List(filteredReciters) { reciter in
                        Button {
                            selectedReciter = reciter
                            dismiss()
                        } label: {
                            HStack {
                                // علامة الاختيار على اليمين
                                if selectedReciter?.id == reciter.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color(hex: "D4AF37"))
                                }
                                
                                Spacer()
                                
                                // معلومات القارئ على اليسار (تظهر على اليمين مع RTL)
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(reciter.name)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.trailing)
                                    if let moshaf = reciter.moshaf.first {
                                        Text(moshaf.name)
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.6))
                                            .multilineTextAlignment(.trailing)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                    .listStyle(.plain)
                    .searchable(text: $searchText, prompt: "ابحث عن قارئ...")
                }
            }
            .navigationTitle("اختر القارئ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { dismiss() }
                        .foregroundColor(Color(hex: "D4AF37"))
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - Ayah View
struct AyahView: View {
    let ayah: Ayah
    let fontSize: CGFloat
    let selectedReciter: MP3Reciter?
    var surahId: Int = 1
    var surahName: String = ""
    var onBookmark: (() -> Void)? = nil
    @EnvironmentObject var audio: AudioPlayerService
    @State private var isPlayingThisAyah = false
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            // نص الآية مع رقمها في النهاية (الطريقة الصحيحة للقرآن)
            // النص يبدأ من اليمين ورقم الآية في نهاية الآية
            Text(buildVerseText())
                .font(.system(size: fontSize, weight: .regular))
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
                .lineSpacing(12)
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            // أزرار التحكم
            HStack {
                // زر حفظ الموضع (على اليسار)
                Button {
                    onBookmark?()
                } label: {
                    Image(systemName: "bookmark")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "43AA8B"))
                }
                
                Spacer()
                
                // رقم الآية بالعربي (على اليمين)
                Text("الآية \(toArabicNumber(ayah.numberInSurah))")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.top, 4)
            
            if let translations = ayah.translations, let first = translations.first {
                Text(first.text)
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .environment(\.layoutDirection, .rightToLeft)
        .onReceive(audio.$isPlaying) { playing in
            // تحديث حالة التشغيل
            if !playing {
                isPlayingThisAyah = false
            }
        }
    }
    
    private func playAyah() {
        guard let reciter = selectedReciter else { return }
        
        if isPlayingThisAyah {
            audio.stop()
            isPlayingThisAyah = false
        } else {
            // تشغيل السورة من هذا القارئ
            audio.playSurah(reciter: reciter, surahNumber: surahId, surahName: surahName)
            isPlayingThisAyah = true
        }
    }
    
    private func buildVerseText() -> AttributedString {
        var verse = AttributedString(ayah.text + " ")
        verse.foregroundColor = .white
        var num = AttributedString(toArabicNumber(ayah.numberInSurah))
        num.foregroundColor = Color(hex: "D4AF37")
        num.font = .system(size: fontSize - 2, weight: .bold)
        verse.append(num)
        return verse
    }

    private func toArabicNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ar")
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// MARK: - Azkar View
struct AzkarView: View {
    @EnvironmentObject var vm: AzkarViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "1A1A2E"), Color(hex: "16213E")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                Group {
                    if vm.isLoading {
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text("جاري تحميل الأذكار...")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    } else if let err = vm.error {
                        VStack(alignment: .trailing, spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 60))
                                .foregroundColor(.yellow)
                            Text("خطأ في تحميل الأذكار")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Button("إعادة المحاولة") {
                                Task { await vm.load() }
                            }
                            .buttonStyle(GoldButtonStyle())
                        }
                    } else if vm.azkarByCategory.isEmpty {
                        VStack(alignment: .trailing, spacing: 16) {
                            Image(systemName: "hands.sparkles")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.5))
                            Text("لا توجد أذكار")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Button("تحميل الأذكار") {
                                Task { await vm.load() }
                            }
                            .buttonStyle(GoldButtonStyle())
                        }
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .trailing, spacing: 16) {
                                ForEach(AzkarCategory.allCases, id: \.self) { category in
                                    if let azkar = vm.azkarByCategory[category], !azkar.isEmpty {
                                        NavigationLink(destination: AzkarCategoryView(category: category, azkar: azkar)) {
                                            AzkarCategoryCard(category: category, count: azkar.count)
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("الأذكار والأدعية")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.layoutDirection, .rightToLeft)
            .task { await vm.load() }
        }
    }
}

// MARK: - Azkar Category Card
struct AzkarCategoryCard: View {
    let category: AzkarCategory
    let count: Int
    
    var icon: String {
        switch category {
        case .morning: return "sun.and.horizon.fill"
        case .evening: return "moon.stars.fill"
        case .sleep: return "bed.double.fill"
        case .wakeUp: return "alarm.fill"
        case .afterPrayer: return "hands.and.sparkles.fill"
        case .food: return "fork.knife"
        case .travel: return "airplane"
        case .mosque: return "building.columns.fill"
        case .ablution: return "drop.fill"
        case .quranicDuas: return "book.fill"
        case .propheticDuas: return "star.fill"
        case .ruqyah: return "shield.fill"
        case .namesOfAllah: return "sparkles"
        case .distress: return "heart.fill"
        case .forgiveness: return "arrow.uturn.backward.circle.fill"
        case .salawat: return "heart.text.square.fill"
        case .friday: return "calendar"
        case .gratitude: return "hand.raised.fill"
        case .protection: return "lock.shield.fill"
        case .istikhara: return "person.fill.questionmark"
        }
    }
    
    var color: Color {
        switch category {
        case .morning: return Color(hex: "F4A261")
        case .evening: return Color(hex: "7B68EE")
        case .sleep: return Color(hex: "4A4E69")
        case .wakeUp: return Color(hex: "90BE6D")
        case .afterPrayer: return Color(hex: "43AA8B")
        case .food: return Color(hex: "F9844A")
        case .travel: return Color(hex: "277DA1")
        case .mosque: return Color(hex: "577590")
        case .ablution: return Color(hex: "4D908E")
        case .quranicDuas: return Color(hex: "D4AF37")
        case .propheticDuas: return Color(hex: "F9C74F")
        case .ruqyah: return Color(hex: "90BE6D")
        case .namesOfAllah: return Color(hex: "F94144")
        case .distress: return Color(hex: "E63946")
        case .forgiveness: return Color(hex: "2A9D8F")
        case .salawat: return Color(hex: "E9C46A")
        case .friday: return Color(hex: "264653")
        case .gratitude: return Color(hex: "F4A261")
        case .protection: return Color(hex: "6D597A")
        case .istikhara: return Color(hex: "9C27B0")
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // السهم على اليسار (للـ RTL)
            Image(systemName: "chevron.left")
                .foregroundColor(.white.opacity(0.5))
            
            Spacer()
            
            // النص على اليمين
            VStack(alignment: .trailing, spacing: 4) {
                Text(category.arabicName)
                    .font(.headline)
                    .foregroundColor(.white)
                Text("\(count) ذكر")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            // الأيقونة على أقصى اليمين
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 56, height: 56)
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
            }
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - Azkar Category View
struct AzkarCategoryView: View {
    let category: AzkarCategory
    let azkar: [Zikr]
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1A1A2E"), Color(hex: "16213E")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                LazyVStack(alignment: .trailing, spacing: 16) {
                    ForEach(azkar) { zikr in
                        ZikrCard(zikr: zikr)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(category.arabicName)
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - Zikr Card (محسّن)
struct ZikrCard: View {
    let zikr: Zikr
    @State private var counter = 0
    @State private var isExpanded = false
    @State private var showCompletionAnimation = false
    
    var isCompleted: Bool {
        counter >= zikr.repetitionCount
    }
    
    var progress: Double {
        guard zikr.repetitionCount > 0 else { return 0 }
        return Double(counter) / Double(zikr.repetitionCount)
    }
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 16) {
            // شريط التقدم
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: isCompleted ? 
                                    [Color(hex: "90BE6D"), Color(hex: "43AA8B")] :
                                    [Color(hex: "D4AF37"), Color(hex: "FFD700")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 4)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 4)
            
            // النص العربي
            Text(zikr.arabicText)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
                .lineSpacing(10)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .lineLimit(isExpanded ? nil : 4)
            
            // زر التوسيع إذا كان النص طويلاً
            if zikr.arabicText.count > 150 {
                Button {
                    withAnimation { isExpanded.toggle() }
                } label: {
                    HStack {
                        Text(isExpanded ? "عرض أقل" : "عرض المزيد")
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    }
                    .font(.caption)
                    .foregroundColor(Color(hex: "D4AF37"))
                }
            }
            
            // الترجمة
            if !zikr.translation.isEmpty {
                Text(zikr.translation)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.trailing)
                    .padding(.top, 4)
            }
            
            // المرجع والفائدة
            VStack(alignment: .trailing, spacing: 8) {
                if let benefit = zikr.benefit {
                    HStack {
                        Spacer()
                        Image(systemName: "sparkles")
                            .foregroundColor(Color(hex: "D4AF37"))
                        Text(benefit)
                            .font(.caption)
                            .foregroundColor(Color(hex: "D4AF37"))
                    }
                    .padding(8)
                    .background(Color(hex: "D4AF37").opacity(0.1))
                    .cornerRadius(8)
                }
                
                if let reference = zikr.reference {
                    HStack {
                        Spacer()
                        Image(systemName: "book.closed.fill")
                            .foregroundColor(.white.opacity(0.5))
                        Text(reference)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // العداد المحسّن
            HStack {
                // عدد التكرارات
                VStack(alignment: .leading, spacing: 2) {
                    Text("التكرار")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                    Text("\(zikr.repetitionCount) مرة")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // العداد التفاعلي
                HStack(spacing: 16) {
                    // زر إعادة التعيين
                    Button {
                        withAnimation { counter = 0 }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    // العداد
                    ZStack {
                        // الدائرة الخلفية
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 4)
                            .frame(width: 60, height: 60)
                        
                        // دائرة التقدم
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                isCompleted ? Color(hex: "90BE6D") : Color(hex: "D4AF37"),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.3), value: progress)
                        
                        // الرقم
                        Text("\(counter)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(isCompleted ? Color(hex: "90BE6D") : .white)
                    }
                    
                    // زر الزيادة
                    Button {
                        if counter < zikr.repetitionCount {
                            counter += 1
                            // اهتزاز خفيف
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            
                            if counter >= zikr.repetitionCount {
                                showCompletionAnimation = true
                                let success = UINotificationFeedbackGenerator()
                                success.notificationOccurred(.success)
                            }
                        }
                    } label: {
                        Image(systemName: isCompleted ? "checkmark" : "plus")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(isCompleted ? Color(hex: "90BE6D") : .black)
                            .frame(width: 50, height: 50)
                            .background(
                                isCompleted ? 
                                    Color(hex: "90BE6D").opacity(0.2) :
                                    Color(hex: "D4AF37")
                            )
                            .clipShape(Circle())
                            .scaleEffect(showCompletionAnimation ? 1.2 : 1)
                            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: showCompletionAnimation)
                    }
                    .disabled(isCompleted)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(isCompleted ? 0.12 : 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            isCompleted ? Color(hex: "90BE6D").opacity(0.3) : Color.clear,
                            lineWidth: 1
                        )
                )
        )
        .onChange(of: showCompletionAnimation) { _, newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showCompletionAnimation = false
                }
            }
        }
    }
}

// MARK: - More View
struct MoreView: View {
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "1B4332"), Color(hex: "081C15")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // الأدوات الرئيسية
                        SectionHeader(title: "الأدوات")
                        
                        NavigationLink(destination: TasbihView()) {
                            FeatureCard(
                                icon: "circle.grid.3x3.fill",
                                title: "المسبحة الإلكترونية",
                                subtitle: "سبّح واستغفر",
                                color: Color(hex: "D4AF37")
                            )
                        }
                        
                        NavigationLink(destination: QiblaView()) {
                            FeatureCard(
                                icon: "location.north.fill",
                                title: "اتجاه القبلة",
                                subtitle: "البوصلة الذكية",
                                color: Color(hex: "43AA8B")
                            )
                        }
                        
                        NavigationLink(destination: DailyVerseView()) {
                            FeatureCard(
                                icon: "text.book.closed.fill",
                                title: "آية اليوم",
                                subtitle: "تدبر آية كل يوم",
                                color: Color(hex: "7B68EE")
                            )
                        }
                        
                        // القرآن الصوتي
                        SectionHeader(title: "🎧 القرآن الصوتي")
                        
                        NavigationLink(destination: AudioRecitersView()) {
                            FeatureCard(
                                icon: "person.wave.2.fill",
                                title: "تلاوات القراء",
                                subtitle: "استمع للقرآن بأصوات القراء",
                                color: Color(hex: "E07A5F")
                            )
                        }
                        
                        NavigationLink(destination: QuranRadioView()) {
                            FeatureCard(
                                icon: "radio.fill",
                                title: "المكتبة الإسلامية الصوتية الشاملة",
                                subtitle: "بث مباشر على مدار الساعة",
                                color: Color(hex: "81B29A")
                            )
                        }
                        
                        // ميزات إضافية
                        SectionHeader(title: "المواقيت والتقويم")
                        
                        NavigationLink(destination: IslamicEventsView()) {
                            FeatureCard(
                                icon: "calendar.badge.clock",
                                title: "المناسبات الإسلامية",
                                subtitle: "أحداث السنة الهجرية",
                                color: Color(hex: "F4A261")
                            )
                        }
                        
                        NavigationLink(destination: MoonPhaseView()) {
                            FeatureCard(
                                icon: "moon.stars.fill",
                                title: "مرحلة القمر",
                                subtitle: "تتبع منازل القمر",
                                color: Color(hex: "6C63FF")
                            )
                        }
                        
                        NavigationLink(destination: NightTimesView()) {
                            FeatureCard(
                                icon: "moon.zzz.fill",
                                title: "أوقات الليل",
                                subtitle: "منتصف الليل والثلث الأخير",
                                color: Color(hex: "2D3047")
                            )
                        }
                        
                        // الإعدادات والمعلومات
                        SectionHeader(title: "المزيد")
                        
                        NavigationLink(destination: SettingsView()) {
                            FeatureCard(
                                icon: "gear",
                                title: "الإعدادات",
                                subtitle: "تخصيص التطبيق",
                                color: Color(hex: "577590")
                            )
                        }
                        
                        NavigationLink(destination: AboutView()) {
                            FeatureCard(
                                icon: "heart.fill",
                                title: "نبذة عن التطبيق",
                                subtitle: "صدقة جارية",
                                color: Color(hex: "F94144")
                            )
                        }
                        
                        // ميزات إضافية
                        SectionHeader(title: "✨ ميزات أخرى")
                        
                        // مخفي مؤقتاً - تجربة الأذان والإقامة (للاستخدام المستقبلي)
                        /*
                        NavigationLink(destination: DeveloperTestView()) {
                            FeatureCard(
                                icon: "hammer.fill",
                                title: "تجربة الأذان والإقامة",
                                subtitle: "اختبار الأصوات والإشعارات",
                                color: Color(hex: "FF6B6B")
                            )
                        }
                        */
                        
                        NavigationLink(destination: ExcuseCalculatorView()) {
                            FeatureCard(
                                icon: "calendar.badge.clock",
                                title: "حاسبة العذر الشرعي",
                                subtitle: "حساب الصلوات الفائتة للمرأة",
                                color: Color(hex: "E91E63")
                            )
                        }
                        
                        NavigationLink(destination: DuaOfDayView()) {
                            FeatureCard(
                                icon: "hands.sparkles.fill",
                                title: "دعاء اليوم",
                                subtitle: "دعاء متجدد يومياً",
                                color: Color(hex: "95E1D3")
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("المزيد")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    
    var body: some View {
        HStack {
            Spacer()
            Text(title)
                .font(.headline)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.top, 8)
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - Feature Card
struct FeatureCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            // السهم على اليسار
            Image(systemName: "chevron.left")
                .foregroundColor(.white.opacity(0.5))
            
            Spacer()
            
            // النص على اليمين
            VStack(alignment: .trailing, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            // الأيقونة على أقصى اليمين
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(color)
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - Tasbih View (Enhanced)
struct TasbihView: View {
    // حفظ العدادات لكل ذكر بشكل منفصل
    @AppStorage("tasbih_سبحان الله") private var countSubhanAllah = 0
    @AppStorage("tasbih_الحمد لله") private var countAlhamdulillah = 0
    @AppStorage("tasbih_الله أكبر") private var countAllahuAkbar = 0
    @AppStorage("tasbih_لا إله إلا الله") private var countLaIlaha = 0
    @AppStorage("tasbih_أستغفر الله") private var countAstaghfir = 0
    @AppStorage("tasbih_لا حول ولا قوة إلا بالله") private var countLaHawla = 0
    @AppStorage("tasbih_target") private var target = 33
    
    @State private var selectedPhrase = "سبحان الله"
    
    let phrases = [
        "سبحان الله",
        "الحمد لله",
        "الله أكبر",
        "لا إله إلا الله",
        "أستغفر الله",
        "لا حول ولا قوة إلا بالله"
    ]
    
    // الحصول على العداد الحالي للذكر المختار
    var currentCount: Int {
        switch selectedPhrase {
        case "سبحان الله": return countSubhanAllah
        case "الحمد لله": return countAlhamdulillah
        case "الله أكبر": return countAllahuAkbar
        case "لا إله إلا الله": return countLaIlaha
        case "أستغفر الله": return countAstaghfir
        case "لا حول ولا قوة إلا بالله": return countLaHawla
        default: return 0
        }
    }
    
    // زيادة العداد للذكر المختار
    private func incrementCount() {
        switch selectedPhrase {
        case "سبحان الله": countSubhanAllah += 1
        case "الحمد لله": countAlhamdulillah += 1
        case "الله أكبر": countAllahuAkbar += 1
        case "لا إله إلا الله": countLaIlaha += 1
        case "أستغفر الله": countAstaghfir += 1
        case "لا حول ولا قوة إلا بالله": countLaHawla += 1
        default: break
        }
    }
    
    // إعادة تعيين العداد للذكر المختار
    private func resetCurrentCount() {
        switch selectedPhrase {
        case "سبحان الله": countSubhanAllah = 0
        case "الحمد لله": countAlhamdulillah = 0
        case "الله أكبر": countAllahuAkbar = 0
        case "لا إله إلا الله": countLaIlaha = 0
        case "أستغفر الله": countAstaghfir = 0
        case "لا حول ولا قوة إلا بالله": countLaHawla = 0
        default: break
        }
    }
    
    // إعادة تعيين جميع العدادات
    private func resetAllCounts() {
        countSubhanAllah = 0
        countAlhamdulillah = 0
        countAllahuAkbar = 0
        countLaIlaha = 0
        countAstaghfir = 0
        countLaHawla = 0
    }
    
    var body: some View {
        ZStack {
            // خلفية متدرجة
            RadialGradient(
                colors: [Color(hex: "1B4332"), Color(hex: "081C15")],
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // اختيار الذكر
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(phrases, id: \.self) { phrase in
                            Button {
                                selectedPhrase = phrase
                                // لا نعيد العداد عند التبديل - نحافظ على القيمة المحفوظة
                            } label: {
                                Text(phrase)
                                    .font(.subheadline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(selectedPhrase == phrase ? Color(hex: "D4AF37") : Color.white.opacity(0.1))
                                    .foregroundColor(selectedPhrase == phrase ? .black : .white)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // الذكر المختار
                Text(selectedPhrase)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                
                // العداد الدائري
                ZStack {
                    // الدائرة الخارجية
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 20)
                        .frame(width: 250, height: 250)
                    
                    // شريط التقدم
                    Circle()
                        .trim(from: 0, to: min(CGFloat(currentCount) / CGFloat(target), 1))
                        .stroke(
                            Color(hex: "D4AF37"),
                            style: StrokeStyle(lineWidth: 20, lineCap: .round)
                        )
                        .frame(width: 250, height: 250)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: currentCount)
                    
                    // العدد
                    VStack(spacing: 8) {
                        Text("\(currentCount)")
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("من \(target)")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .onTapGesture {
                    incrementCount()
                    // اهتزاز خفيف
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                }
                
                Spacer()
                
                // اختيار الهدف
                HStack(spacing: 20) {
                    ForEach([33, 99, 100], id: \.self) { t in
                        Button {
                            target = t
                            // لا نعيد العداد عند تغيير الهدف
                        } label: {
                            Text("\(t)")
                                .font(.headline)
                                .frame(width: 60, height: 60)
                                .background(target == t ? Color(hex: "D4AF37") : Color.white.opacity(0.1))
                                .foregroundColor(target == t ? .black : .white)
                                .cornerRadius(30)
                        }
                    }
                }
                
                // أزرار إعادة التعيين
                HStack(spacing: 20) {
                    // إعادة تعيين الذكر الحالي فقط
                    Button {
                        resetCurrentCount()
                    } label: {
            HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("إعادة التعيين")
                        }
                        .foregroundColor(.white.opacity(0.7))
                    }
                    
                    // إعادة تعيين الكل
                    Button {
                        resetAllCounts()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("مسح الكل")
                        }
                        .foregroundColor(.red.opacity(0.7))
                    }
                }
                .padding(.bottom)
            }
            .padding()
        }
        .navigationTitle("المسبحة")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Qibla View (Fixed Arrow - Rotating Compass)
// المنطق الصحيح: السهم ثابت دائماً للأعلى، البوصلة تدور
// عندما يدور المستخدم الجهاز، البوصلة تدور حتى يصبح اتجاه القبلة للأعلى
struct QiblaView: View {
    @EnvironmentObject var container: AppContainer
    @EnvironmentObject var cityStore: CityStore
    @StateObject private var compass = SimpleCompassService()
    
    @State private var qiblaDirection: Double = 0
    @State private var distance: Double = 0
    @State private var qiblaSource: QiblaService.Source = .api
    @State private var qiblaIsStale: Bool = false
    @State private var isCalculating = false
    @State private var lastUpdate: Date?
    @State private var showCalibrationHelp = false
    @State private var previousQiblaState = false
    
    // Haptic feedback manager
    private let hapticManager = HapticFeedbackManager.shared
    
    // ====== نظام البوصلة الجديد ======
    // السهم ثابت دائماً للأعلى
    // البوصلة تدور بحيث يكون اتجاه القبلة للأعلى عند التوجه الصحيح
    
    /// زاوية دوران السهم (يتحرك باستمرار نحو القبلة)
    var arrowRotation: Double {
        QiblaCalculator.calculateArrowRotation(qiblaDirection: qiblaDirection, deviceHeading: compass.heading)
    }
    
    // هل الجهاز في وضعية صحيحة للقراءة
    var isDeviceReady: Bool {
        return compass.isDeviceFlat || abs(compass.pitch) < 60
    }
    
    // هل الجهاز موجه للقبلة (±7 درجات) مع شرط دقة/معايرة جيدة
    var isPointingToQibla: Bool {
        let diff = abs(normalizeAngle(compass.heading - qiblaDirection))
        let pointing = (diff < 7 || diff > 353)
        let accuracyOk = (compass.accuracy < 0) || (compass.accuracy <= 25)
        return pointing && accuracyOk && !compass.calibrationNeeded
    }
    
    // تطبيع الزاوية بين 0 و 360
    private func normalizeAngle(_ angle: Double) -> Double {
        var normalized = angle.truncatingRemainder(dividingBy: 360)
        if normalized < 0 { normalized += 360 }
        return normalized
    }
    
    // حساب حالة التشويش المغناطيسي
    private var magneticInterference: (hasInterference: Bool, level: MagneticInterferenceIndicator.InterferenceLevel) {
        MagneticInterferenceIndicator.detectInterference(
            accuracy: compass.accuracy,
            calibrationNeeded: compass.calibrationNeeded
        )
    }
    
    // يمكن إضافة عوامل إضافية في المستقبل:
    // - heading variance (تباين الاتجاه)
    // - magnetic field magnitude (قوة المجال المغناطيسي)
    // - confidence من MagneticAnomalyDetector
    // عندها يمكن استخدام detectInterferenceAdvanced بدلاً من detectInterference
    
    var body: some View {
        ZStack {
            // خلفية متدرجة
            LinearGradient(
                colors: [QiblaTheme.background, Color(hex: "0F1A35")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // معلومات الموقع
                    VStack(spacing: 8) {
                        HStack {
                            Spacer()
                            Text(cityStore.activeCityName)
                                .font(.title3.bold())
                                .foregroundColor(.white)
                            Image(systemName: "location.fill")
                                .foregroundColor(Color(hex: "43AA8B"))
                        }
                        
                        if distance > 0 {
                            HStack {
                                Spacer()
                                Text("المسافة إلى مكة: \(distance, specifier: "%.0f") كم")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                                Image(systemName: "arrow.triangle.swap")
                                    .foregroundColor(Color(hex: "D4AF37"))
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    .environment(\.layoutDirection, .rightToLeft)
                    
                    // رسالة خطأ البوصلة/الموقع
                    if let errorMessage = compass.error {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(errorMessage)
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                            }
                            
                            if container.location.authorizationStatus == .denied {
                                Button {
                                    // فتح إعدادات التطبيق
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "gear")
                                        Text("فتح الإعدادات")
                                    }
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.red.opacity(0.8))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding()
                        .background(Color.red.opacity(0.15))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // تحذير وضعية الجهاز
                    if !isDeviceReady && compass.isAvailable && compass.error == nil {
                        HStack {
                            Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                                .foregroundColor(.orange)
                            Text("للحصول على قراءة دقيقة، ضع الجهاز بشكل مسطح أو عمودي")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // مصدر البيانات + مؤشرات الدقة
                    VStack(spacing: 12) {
                        HStack {
                            SourceBadge(source: qiblaSource, isStale: qiblaIsStale)
                            Spacer()
                            if isCalculating {
                                ProgressView().tint(QiblaTheme.accent)
                            }
                        }
                        .padding(.horizontal)
                        
                        // مؤشر دقة البوصلة المبسط (رقم فقط)
                        SimpleAccuracyIndicator(accuracy: compass.accuracy)
                            .padding(.horizontal)
                        
                        // مؤشر المعايرة المحسن (يظهر فقط عند الحاجة)
                        if compass.calibrationNeeded && compass.error == nil {
                            EnhancedCalibrationIndicator(
                                calibrationNeeded: true,
                                onCalibrate: {
                                    showCalibrationHelp = true
                                    DebugFileLogger.log(runId: "qibla-accuracy", hypothesisId: "Q5", location: "Views.swift:QiblaView", message: "Open calibration help", data: [:])
                                }
                            )
                            .padding(.horizontal)
                        }
                    }
                    
                    // البوصلة المحسنة + سهم متحرك
                    EnhancedCompassView(
                        arrowRotation: arrowRotation,
                        isPointingToQibla: isPointingToQibla,
                        deviceHeading: compass.heading
                    )
                    .frame(height: 340)
                    
                    // معلومات الاتجاه
                    VStack(spacing: 12) {
                        Text("اتجاه القبلة")
                            .font(.headline)
                            .foregroundColor(QiblaTheme.textSecondary)
                        
                        Text("\(qiblaDirection, specifier: "%.1f")°")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(QiblaTheme.accent)
                        
                        Text(container.qibla.directionName(for: qiblaDirection))
                            .font(.title2.bold())
                            .foregroundColor(QiblaTheme.textPrimary)
                        
                        Text("وجّه الهاتف حتى يتحول السهم إلى الأخضر. في حال ضعف الدقة، أدر الجهاز بشكل الرقم 8 أو ابتعد عن مصادر المعادن.")
                            .font(.footnote)
                            .foregroundColor(QiblaTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    
                    // قسم Debug للتحقق من مشكلة 88° (فقط في DEBUG mode)
                    #if DEBUG
                    VStack(spacing: 8) {
                        Text("🔍 Debug Info (88° Issue)")
                            .font(.caption.bold())
                            .foregroundColor(.yellow)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("iOS trueHeading:")
                                Spacer()
                                Text(compass.rawTrueHeading >= 0 ? "\(compass.rawTrueHeading, specifier: "%.1f")°" : "N/A")
                                    .foregroundColor(compass.rawTrueHeading >= 0 ? .green : .gray)
                            }
                            
                            HStack {
                                Text("iOS magneticHeading:")
                                Spacer()
                                Text(compass.rawMagneticHeading >= 0 ? "\(compass.rawMagneticHeading, specifier: "%.1f")°" : "N/A")
                                    .foregroundColor(compass.rawMagneticHeading >= 0 ? .orange : .gray)
                            }
                            
                            HStack {
                                Text("Our heading:")
                                Spacer()
                                Text("\(compass.heading, specifier: "%.1f")°")
                                    .foregroundColor(.blue)
                            }
                            
                            HStack {
                                Text("Using trueHeading:")
                                Spacer()
                                Text(compass.isUsingTrueHeading ? "YES ✅" : "NO ⚠️")
                                    .foregroundColor(compass.isUsingTrueHeading ? .green : .orange)
                            }
                            
                            if compass.magneticDeclinationApplied != 0 {
                                HStack {
                                    Text("Declination applied:")
                                    Spacer()
                                    Text("\(compass.magneticDeclinationApplied, specifier: "%.1f")°")
                                        .foregroundColor(.purple)
                                }
                            }
                            
                            if compass.rawTrueHeading >= 0 {
                                let diff = abs(compass.heading - compass.rawTrueHeading)
                                let normalizedDiff = min(diff, 360 - diff) // أقصر مسار
                                HStack {
                                    Text("Difference:")
                                    Spacer()
                                    Text("\(normalizedDiff, specifier: "%.1f")°")
                                        .foregroundColor(normalizedDiff > 5 ? .red : .green)
                                }
                            }
                            
                            HStack {
                                Text("Qibla direction:")
                                Spacer()
                                Text("\(qiblaDirection, specifier: "%.1f")°")
                                    .foregroundColor(.yellow)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    }
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    #endif
                    
                    // التعليمات المحسنة
                    EnhancedInstructionsView(
                        isPointingToQibla: isPointingToQibla,
                        isDeviceReady: isDeviceReady,
                        accuracyLevel: AccuracyLevel.from(accuracy: compass.accuracy)
                    )
                    .padding(.horizontal)
                    
                    // زر التحديث
                    if isCalculating {
                        ProgressView()
                            .tint(.white)
                            .padding()
                    } else {
                        Button {
                            updateQibla()
                        } label: {
                            HStack {
                                Image(systemName: "location.fill")
                                Text("تحديث الموقع")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(hex: "D4AF37"))
                            .foregroundColor(.black)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("اتجاه القبلة")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            compass.startUpdating()
            updateQibla()
            DebugFileLogger.log(runId: "ui-change", hypothesisId: "Q1", location: "Views.swift:QiblaView.onAppear", message: "QiblaView appeared", data: ["useGPS": cityStore.useCurrentLocation, "cityLen": cityStore.activeCityName.count])
        }
        .onDisappear {
            compass.stopUpdating()
        }
        .onChange(of: isPointingToQibla) { oldValue, newValue in
            // تحديث Haptic feedback عند تغيير حالة التوجيه
            hapticManager.updateState(
                isPointingToQibla: newValue,
                accuracy: compass.accuracy
            )
            previousQiblaState = newValue
        }
        .onChange(of: compass.accuracy) { oldValue, newValue in
            // تحديث Haptic feedback عند تغيير الدقة
            hapticManager.updateState(
                isPointingToQibla: isPointingToQibla,
                accuracy: newValue
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("بوصلة القبلة")
        .accessibilityHint("استخدم هذه البوصلة لتحديد اتجاه القبلة. حرّك جهازك حتى يشير السهم الذهبي إلى القبلة")
        .sheet(isPresented: $showCalibrationHelp) {
            VStack(spacing: 14) {
                Text("معايرة البوصلة")
                    .font(.title2.bold())
                Text("لأفضل دقة: ابتعد عن المعادن/الأجهزة القوية، ثم حرّك الجهاز بحركة رقم 8 (∞) لعدة ثوانٍ. إذا استمرت المشكلة أعد تشغيل خدمات الموقع.")
                    .multilineTextAlignment(.trailing)
                    .environment(\.layoutDirection, .rightToLeft)
                    .foregroundColor(.secondary)
                Button("إغلاق") { showCalibrationHelp = false }
                    .font(.headline)
                    .padding(.top, 6)
            }
            .padding()
            .presentationDetents([.medium])
        }
        // التنعيم يتم الآن في CompassService باستخدام فلتر Kalman
        // لا حاجة لفلتر إضافي هنا
    }
    
    private func updateQibla() {
        isCalculating = true
        DebugFileLogger.log(runId: "qibla-accuracy", hypothesisId: "Q4", location: "Views.swift:updateQibla", message: "updateQibla invoked", data: ["useGPS": cityStore.useCurrentLocation])
        
        Task {
            // إذا كان المستخدم على GPS نطلب تحديث الموقع، وإلا نستخدم المدينة اليدوية مباشرة
            if cityStore.useCurrentLocation {
                container.location.request()
                
                var attempts = 0
                while container.location.currentLocation == nil && attempts < 30 {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    attempts += 1
                }
            }
            
            guard let coord = cityStore.activeCoordinate else {
                await MainActor.run { isCalculating = false }
                DebugFileLogger.log(runId: "ui-change", hypothesisId: "Q1", location: "Views.swift:updateQibla", message: "Missing activeCoordinate", data: ["useGPS": cityStore.useCurrentLocation])
                return
            }
            
            // =====================================================
            // التحقق من صحة الإحداثيات وإصلاح الإحداثيات المعكوسة
            // =====================================================
            var correctedLat = coord.latitude
            var correctedLon = coord.longitude
            var coordinatesWereSwapped = false
            
            // التحقق من NaN و Infinity
            guard correctedLat.isFinite && correctedLon.isFinite else {
                print("❌ خطأ: إحداثيات غير صالحة (NaN أو Infinity)")
                await MainActor.run { isCalculating = false }
                return
            }
            
            // التحقق من أن latitude في النطاق الصحيح (-90 إلى 90)
            if abs(coord.latitude) > 90 {
                print("⚠️ تحذير: latitude خارج النطاق: \(coord.latitude)°")
                print("   قد تكون الإحداثيات معكوسة، جارٍ التصحيح...")
                // تبديل الإحداثيات إذا كانت معكوسة
                correctedLat = coord.longitude
                correctedLon = coord.latitude
                coordinatesWereSwapped = true
            }
            
            // التحقق من أن longitude في النطاق الصحيح (-180 إلى 180)
            // وتطبيع القيمة إذا كانت خارج النطاق
            if abs(correctedLon) > 180 {
                print("⚠️ تحذير: longitude خارج النطاق: \(correctedLon)°")
                // تطبيع longitude إلى [-180, 180]
                correctedLon = correctedLon.truncatingRemainder(dividingBy: 360)
                if correctedLon > 180 { correctedLon -= 360 }
                if correctedLon < -180 { correctedLon += 360 }
                print("   تم تطبيع longitude إلى: \(correctedLon)°")
            }
            
            // التحقق النهائي بعد التصحيح
            guard abs(correctedLat) <= 90 && abs(correctedLon) <= 180 else {
                print("❌ خطأ: فشل تصحيح الإحداثيات")
                await MainActor.run { isCalculating = false }
                return
            }
            
            let loc = CLLocation(latitude: correctedLat, longitude: correctedLon)
            
            // =====================================================
            // النظام الهجين: API أولاً + Cache + GPS fallback
            // =====================================================
            let result = await container.qibla.fetchQibla(for: loc.coordinate)
            
            await MainActor.run {
                qiblaDirection = result.bearing
                distance = result.distance
                qiblaSource = result.source
                qiblaIsStale = result.isStale
                lastUpdate = Date()
                
                // Logging مفصل للتشخيص
                print("📍 الموقع الأصلي: \(coord.latitude)°N, \(coord.longitude)°E")
                if coordinatesWereSwapped {
                    print("⚠️ تم تصحيح الإحداثيات المعكوسة تلقائياً")
                    print("📍 الموقع المصحح: \(correctedLat)°N, \(correctedLon)°E")
                }
                print("🕋 اتجاه القبلة: \(qiblaDirection)°")
                print("📏 المسافة: \(distance) كم")
                
                // التحقق من الاتجاه المتوقع للرياض
                if abs(correctedLat - 24.8453) < 1.0 && abs(correctedLon - 46.6753) < 1.0 {
                    let expectedDirection = 242.86
                    let difference = abs(qiblaDirection - expectedDirection)
                    if difference > 5 {
                        print("⚠️ تحذير: اتجاه القبلة (\(qiblaDirection)°) يختلف عن المتوقع (\(expectedDirection)°)")
                        print("   الفرق: \(difference)°")
                    }
                }
                
                DebugFileLogger.log(
                    runId: "ui-change",
                    hypothesisId: "Q1",
                    location: "Views.swift:updateQibla",
                    message: "Computed qibla+distance (hybrid)",
                    data: [
                        "originalLat": coord.latitude,
                        "originalLon": coord.longitude,
                        "correctedLat": correctedLat,
                        "correctedLon": correctedLon,
                        "coordinatesSwapped": coordinatesWereSwapped,
                        "qiblaDeg": Int(qiblaDirection.rounded()),
                        "distKm": Int(distance.rounded()),
                        "headingDeg": Int(compass.heading.rounded()),
                        "isPointing": isPointingToQibla,
                        "source": "hybrid-api-cache-local"
                    ]
                )
                DebugFileLogger.log(
                    runId: "qibla-accuracy",
                    hypothesisId: "Q4",
                    location: "Views.swift:updateQibla",
                    message: "Qibla state snapshot",
                    data: [
                        "heading": Int(compass.heading.rounded()),
                        "acc": Int(compass.accuracy.rounded()),
                        "calibNeeded": compass.calibrationNeeded,
                        "pitch": Int(compass.pitch.rounded()),
                        "roll": Int(compass.roll.rounded())
                    ]
                )
            }
            
            await MainActor.run {
                isCalculating = false
            }
        }
    }
    
    private func getLocationName(for location: CLLocation, completion: @escaping (String) -> Void) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "city"
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            if let item = response?.mapItems.first {
                // استخدام name أو معلومات الموقع
                if let name = item.name, !name.isEmpty && name != "city" {
                    completion(name)
                } else {
                    // استخدام الإحداثيات
                    completion(String(format: "%.4f°, %.4f°", location.coordinate.latitude, location.coordinate.longitude))
                }
            } else {
                completion(String(format: "%.4f°, %.4f°", location.coordinate.latitude, location.coordinate.longitude))
            }
        }
    }
}

// MARK: - Compass Direction
struct CompassDirection: View {
    let text: String
    let angle: Double
    let isMain: Bool
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: isMain ? 20 : 14, weight: .bold))
            .foregroundColor(color)
            .offset(y: -115)
            .rotationEffect(.degrees(angle))
            .rotationEffect(.degrees(-angle), anchor: .center)
    }
}

// MARK: - Compass Direction Label (اسم الاتجاه الكامل)
/// View لعرض تسمية الاتجاه على البوصلة
/// يحسب الموضع النسبي للتسمية بناءً على اتجاه الجهاز وزاوية الاتجاه الأساسية
///
/// ## الاستخدام:
/// ```swift
/// CompassDirectionLabel(
///     text: "شمال",
///     baseAngle: 0,        // 0=شمال، 90=شرق، 180=جنوب، 270=غرب
///     deviceHeading: 45,   // اتجاه الجهاز الحالي
///     color: .red,
///     radius: 115
/// )
/// ```
///
/// ## المنطق:
/// - عندما الجهاز موجه للشمال (heading=0): "شمال" يظهر في الأعلى
/// - عندما الجهاز موجه للشرق (heading=90): "شرق" يظهر في الأعلى
/// - التسميات تدور عكس دوران الجهاز للحفاظ على صحة الاتجاهات
struct CompassDirectionLabel: View {
    /// النص المعروض (مثل "شمال"، "شرق")
    let text: String
    /// الزاوية الأساسية في نظام البوصلة (0=شمال، 90=شرق، 180=جنوب، 270=غرب)
    let baseAngle: Double
    /// اتجاه الجهاز الحالي من البوصلة
    let deviceHeading: Double
    /// لون النص
    let color: Color
    /// نصف قطر موضع التسمية من مركز البوصلة
    let radius: CGFloat
    
    // MARK: - Constants
    /// مركز البوصلة (نصف عرض البوصلة 300/2)
    private static let compassCenter: CGFloat = 150
    /// حجم خط التسمية
    private static let labelFontSize: CGFloat = 14
    /// padding أفقي للتسمية
    private static let labelHorizontalPadding: CGFloat = 8
    /// padding عمودي للتسمية
    private static let labelVerticalPadding: CGFloat = 4
    /// شفافية خلفية التسمية
    private static let backgroundOpacity: Double = 0.6
    /// نصف قطر زوايا التسمية
    private static let labelCornerRadius: CGFloat = 8
    /// تحويل من نظام البوصلة إلى نظام الرياضيات (90 درجة)
    private static let compassToMathOffset: Double = 90
    /// دائرة كاملة بالدرجات
    private static let fullCircleDegrees: Double = 360
    
    // MARK: - Computed Properties
    
    /// حساب الزاوية المعدلة مع التطبيع بين 0-360
    /// - baseAngle: زاوية الاتجاه في نظام البوصلة (0=شمال، 90=شرق، 180=جنوب، 270=غرب)
    /// - deviceHeading: اتجاه الجهاز من الشمال (0-360)
    /// - Returns: الزاوية النسبية لعرض التسمية على البوصلة
    ///
    /// ## المنطق الصحيح:
    /// - البوصلة تعرض الاتجاهات الحقيقية في العالم
    /// - عندما الجهاز موجه للشمال (heading=0): "شمال" يظهر في الأعلى (0°)
    /// - عندما الجهاز يدور لليمين (heading=90، موجه للشرق): "شمال" يظهر على اليسار (270°)
    /// - الصيغة: adjustedAngle = baseAngle - deviceHeading
    ///   - شمال (0°) مع heading=0°: adjustedAngle = 0 - 0 = 0° → الأعلى ✓
    ///   - شمال (0°) مع heading=90°: adjustedAngle = 0 - 90 = -90° → 270° → اليسار ✓
    ///   - شرق (90°) مع heading=90°: adjustedAngle = 90 - 90 = 0° → الأعلى ✓
    private var adjustedAngle: Double {
        guard baseAngle.isFinite, deviceHeading.isFinite else {
            return 0
        }
        var angle = baseAngle - deviceHeading
        angle = angle.truncatingRemainder(dividingBy: Self.fullCircleDegrees)
        if angle < 0 {
            angle += Self.fullCircleDegrees
        }
        return angle
    }
    
    /// تحويل الزاوية إلى radians لنظام SwiftUI
    /// - في نظام البوصلة: 0° = شمال (أعلى)، 90° = شرق (يمين)، 180° = جنوب (أسفل)، 270° = غرب (يسار)
    /// - في SwiftUI: نستخدم sin للـ X و cos للـ Y مع تعديل الإشارات
    /// - الصيغة: radians = adjustedAngle * π/180 (بدون تحويل إضافي)
    private var radians: Double {
        adjustedAngle * .pi / 180
    }
    
    /// حساب موضع X على محيط الدائرة
    /// - في نظام البوصلة: 0° = أعلى، 90° = يمين
    /// - sin(0°) = 0 → X = 0 (مركز أفقياً) ✓
    /// - sin(90°) = 1 → X = +radius (يمين) ✓
    /// - sin(180°) = 0 → X = 0 (مركز أفقياً) ✓
    /// - sin(270°) = -1 → X = -radius (يسار) ✓
    private var positionX: CGFloat {
        guard radius.isFinite, radius > 0 else { return 0 }
        return sin(radians) * radius
    }
    
    /// حساب موضع Y على محيط الدائرة
    /// - في SwiftUI: y يزيد للأسفل
    /// - cos(0°) = 1 → Y = -radius (أعلى) ✓
    /// - cos(90°) = 0 → Y = 0 (مركز عمودياً) ✓
    /// - cos(180°) = -1 → Y = +radius (أسفل) ✓
    /// - cos(270°) = 0 → Y = 0 (مركز عمودياً) ✓
    private var positionY: CGFloat {
        guard radius.isFinite, radius > 0 else { return 0 }
        return -cos(radians) * radius
    }
    
    // MARK: - Body
    
    var body: some View {
        Text(text)
            .font(.system(size: Self.labelFontSize, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, Self.labelHorizontalPadding)
            .padding(.vertical, Self.labelVerticalPadding)
            .background(Color.black.opacity(Self.backgroundOpacity))
            .cornerRadius(Self.labelCornerRadius)
            .position(
                x: Self.compassCenter + positionX,
                y: Self.compassCenter + positionY
            )
    }
}

// MARK: - Premium Qibla Arrow (تصميم احترافي)
// سهم القبلة الاحترافي - تصميم ثلاثي الأبعاد مع تأثيرات بصرية
struct PremiumQiblaArrow: View {
    var isPointingToQibla: Bool = false
    
    // الألوان حسب حالة التوجيه
    var primaryColor: Color {
        isPointingToQibla ? Color(hex: "00D26A") : Color(hex: "FFD700")
    }
    
    var secondaryColor: Color {
        isPointingToQibla ? Color(hex: "00A855") : Color(hex: "D4AF37")
    }
    
    var glowColor: Color {
        isPointingToQibla ? Color(hex: "00FF7F") : Color(hex: "FFD700")
    }
    
    var body: some View {
        ZStack {
            // التوهج الخارجي (يظهر عند التوجيه الصحيح)
            if isPointingToQibla {
                // نبضات التوهج
                ForEach(0..<3, id: \.self) { i in
                    ArrowShape()
                        .fill(glowColor.opacity(0.15 - Double(i) * 0.04))
                        .frame(width: 70 + CGFloat(i * 15), height: 130 + CGFloat(i * 20))
                        .offset(y: -60)
                        .blur(radius: CGFloat(i * 4 + 2))
                }
            }
            
            // السهم الرئيسي
            ZStack {
                // الظل
                ArrowShape()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 60, height: 120)
                    .offset(x: 3, y: -57)
                    .blur(radius: 5)
                
                // الجسم الرئيسي للسهم
                ArrowShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                primaryColor,
                                secondaryColor,
                                secondaryColor.opacity(0.8)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 55, height: 115)
                    .offset(y: -60)
                
                // الحافة اليسرى (تأثير 3D)
                ArrowShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 55, height: 115)
                    .offset(y: -60)
                    .mask(
                        HStack {
                            Rectangle()
                                .frame(width: 20)
                            Spacer()
                        }
                    )
                
                // الحافة الخارجية
                ArrowShape()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.8),
                                primaryColor.opacity(0.5),
                                secondaryColor
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 55, height: 115)
                    .offset(y: -60)
                
                // خط الوسط (تفصيل)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                secondaryColor.opacity(0.5)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3, height: 70)
                    .offset(y: -45)
                
                // رمز القبلة في رأس السهم
                if isPointingToQibla {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .offset(y: -95)
                }
            }
            
            // دائرة القاعدة
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [secondaryColor, secondaryColor.opacity(0.5)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 15
                        )
                    )
                    .frame(width: 24, height: 24)
                
                Circle()
                    .stroke(Color.white.opacity(0.5), lineWidth: 2)
                    .frame(width: 24, height: 24)
            }
            .offset(y: 5)
        }
        .animation(.easeInOut(duration: 0.2), value: isPointingToQibla)
    }
}

// شكل السهم المخصص
struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        let arrowHeadHeight = height * 0.45
        let bodyWidth = width * 0.35
        
        // رأس السهم
        path.move(to: CGPoint(x: width / 2, y: 0))
        path.addLine(to: CGPoint(x: width, y: arrowHeadHeight))
        path.addLine(to: CGPoint(x: width / 2 + bodyWidth / 2, y: arrowHeadHeight))
        
        // جسم السهم
        path.addLine(to: CGPoint(x: width / 2 + bodyWidth / 2, y: height))
        path.addLine(to: CGPoint(x: width / 2 - bodyWidth / 2, y: height))
        path.addLine(to: CGPoint(x: width / 2 - bodyWidth / 2, y: arrowHeadHeight))
        
        // إكمال رأس السهم
        path.addLine(to: CGPoint(x: 0, y: arrowHeadHeight))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Beautiful Qibla Compass (بوصلة قبلة جميلة)
/// تصميم جديد ومحسّن للبوصلة مع تأثيرات بصرية جميلة
///
/// ## المميزات:
/// - بوصلة دائرية مع علامات الدرجات (0, 30, 60, 90, ...)
/// - اتجاهات رئيسية بالعربية (ش، ج، شر، غ)
/// - سهم القبلة يشير دائماً نحو مكة
/// - تأثيرات بصرية جميلة (gradient, shadow, glow)
/// - ألوان داكنة (Dark Mode)
///
/// ## الاستخدام:
/// ```swift
/// BeautifulQiblaCompass(
///     arrowRotation: arrowRotation,
///     isPointingToQibla: isPointingToQibla,
///     deviceHeading: compass.heading
/// )
/// ```
struct BeautifulQiblaCompass: View {
    /// زاوية دوران سهم القبلة
    let arrowRotation: Double
    /// هل الجهاز موجه للقبلة
    let isPointingToQibla: Bool
    /// اتجاه الجهاز الحالي
    let deviceHeading: Double
    
    // MARK: - State
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowIntensity: Double = 0.4
    @State private var ringRotation: Double = 0
    
    // MARK: - Constants
    private let compassSize: CGFloat = 320
    private let outerRingRadius: CGFloat = 160
    private let innerRingRadius: CGFloat = 140
    private let centerRadius: CGFloat = 60
    
    // MARK: - Colors
    private var primaryGlowColor: Color {
        isPointingToQibla ? Color(hex: "00D26A") : Color(hex: "D4AF37")
    }
    
    private var secondaryGlowColor: Color {
        isPointingToQibla ? Color(hex: "00FF7F") : Color(hex: "FFD700")
    }
    
    private var ringGradientColors: [Color] {
        isPointingToQibla ? [
            Color(hex: "00D26A").opacity(0.9),
            Color(hex: "00FF7F").opacity(0.6),
            Color(hex: "00D26A").opacity(0.9)
        ] : [
            Color(hex: "D4AF37").opacity(0.8),
            Color(hex: "B8860B").opacity(0.5),
            Color(hex: "D4AF37").opacity(0.8)
        ]
    }
    
    var body: some View {
        ZStack {
            // الخلفية المتوهجة الخارجية
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            primaryGlowColor.opacity(glowIntensity * 0.3),
                            primaryGlowColor.opacity(glowIntensity * 0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: outerRingRadius,
                        endRadius: outerRingRadius + 40
                    )
                )
                .frame(width: compassSize + 80, height: compassSize + 80)
                .blur(radius: 20)
            
            // الحلقة الخارجية المتوهجة مع دوران
            Circle()
                .stroke(
                    AngularGradient(
                        colors: ringGradientColors,
                        center: .center,
                        angle: .degrees(ringRotation)
                    ),
                    lineWidth: 6
                )
                .frame(width: compassSize, height: compassSize)
                .shadow(
                    color: primaryGlowColor.opacity(glowIntensity),
                    radius: isPointingToQibla ? 25 : 15
                )
                .scaleEffect(pulseScale)
            
            // الحلقة الداخلية
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: compassSize - 40, height: compassSize - 40)
            
            // علامات الدرجات (0, 30, 60, 90, ...)
            ForEach(0..<12, id: \.self) { i in
                let degree = i * 30
                CompassDegreeMark(
                    degree: degree,
                    deviceHeading: deviceHeading,
                    isMajor: degree % 90 == 0,
                    radius: outerRingRadius - 10
                )
            }
            
            // علامات الدرجات الصغيرة (كل 10 درجات)
            ForEach(0..<36, id: \.self) { i in
                let degree = i * 10
                if degree % 30 != 0 { // تجنب التكرار مع العلامات الكبيرة
                    CompassSmallMark(
                        degree: degree,
                        deviceHeading: deviceHeading,
                        radius: outerRingRadius - 5
                    )
                }
            }
            
            // الاتجاهات الرئيسية بالعربية (ش، ج، شر، غ)
            ZStack {
                CompassDirectionLabel(
                    text: "ش",
                    baseAngle: 0,
                    deviceHeading: deviceHeading,
                    color: Color(hex: "FF6B6B"),
                    radius: outerRingRadius - 25
                )
                CompassDirectionLabel(
                    text: "شر",
                    baseAngle: 90,
                    deviceHeading: deviceHeading,
                    color: .white,
                    radius: outerRingRadius - 25
                )
                CompassDirectionLabel(
                    text: "ج",
                    baseAngle: 180,
                    deviceHeading: deviceHeading,
                    color: .white,
                    radius: outerRingRadius - 25
                )
                CompassDirectionLabel(
                    text: "غ",
                    baseAngle: 270,
                    deviceHeading: deviceHeading,
                    color: .white,
                    radius: outerRingRadius - 25
                )
            }
            
            // المركز مع التوهج الديناميكي
            ZStack {
                // التوهج الديناميكي
                Circle()
                    .fill(
                        RadialGradient(
                            colors: isPointingToQibla ? [
                                primaryGlowColor.opacity(glowIntensity * 0.8),
                                secondaryGlowColor.opacity(glowIntensity * 0.4),
                                Color.clear
                            ] : [
                                primaryGlowColor.opacity(glowIntensity * 0.5),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: centerRadius + 10
                        )
                    )
                    .frame(width: (centerRadius + 10) * 2, height: (centerRadius + 10) * 2)
                    .blur(radius: 8)
                
                // الدائرة المركزية
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "1B263B"),
                                Color(hex: "0D1B2A"),
                                Color(hex: "1B263B")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: centerRadius * 2, height: centerRadius * 2)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        primaryGlowColor.opacity(0.8),
                                        secondaryGlowColor.opacity(0.4),
                                        primaryGlowColor.opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                    )
                    .shadow(
                        color: primaryGlowColor.opacity(glowIntensity * 0.6),
                        radius: 15
                    )
                
                // أيقونة الكعبة
                Text("🕋")
                    .font(.system(size: 40))
                    .shadow(color: primaryGlowColor.opacity(0.5), radius: 5)
            }
            
            // سهم القبلة المحسّن
            // الترتيب الصحيح: rotationEffect أولاً ثم offset
            // هذا يجعل السهم يدور حول مركز البوصلة وليس حول مركزه الخاص
            BeautifulQiblaArrow(isPointingToQibla: isPointingToQibla)
                .frame(width: 80, height: 140)
                .offset(y: -(outerRingRadius - 30))
                .rotationEffect(.degrees(arrowRotation), anchor: UnitPoint(x: 0.5, y: 0.5 + (outerRingRadius - 30) / 140))
                .animation(.spring(response: 0.15, dampingFraction: 0.75), value: arrowRotation)
        }
        .frame(width: compassSize, height: compassSize)
        .onAppear {
            if isPointingToQibla {
                pulseScale = 1.05
                glowIntensity = 0.7
            }
            // بدء دوران الحلقة
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
        }
        .onChange(of: isPointingToQibla) { oldValue, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 0.6)) {
                    pulseScale = 1.05
                    glowIntensity = 0.7
                }
            } else {
                withAnimation(.easeInOut(duration: 0.6)) {
                    pulseScale = 1.0
                    glowIntensity = 0.4
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("بوصلة القبلة")
        .accessibilityValue(isPointingToQibla ? "موجه للقبلة" : "غير موجه للقبلة")
    }
}

// MARK: - Compass Degree Mark
/// علامة درجة على البوصلة
struct CompassDegreeMark: View {
    let degree: Int
    let deviceHeading: Double
    let isMajor: Bool
    let radius: CGFloat
    
    private var adjustedAngle: Double {
        var angle = Double(degree) - deviceHeading
        angle = angle.truncatingRemainder(dividingBy: 360)
        if angle < 0 { angle += 360 }
        return angle
    }
    
    private var radians: Double {
        (90 - adjustedAngle) * .pi / 180
    }
    
    private var positionX: CGFloat {
        cos(radians) * radius
    }
    
    private var positionY: CGFloat {
        -sin(radians) * radius
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // العلامة
            Rectangle()
                .fill(
                    isMajor ?
                        LinearGradient(
                            colors: [Color(hex: "D4AF37"), Color(hex: "B8860B")],
                            startPoint: .top,
                            endPoint: .bottom
                        ) :
                        LinearGradient(
                            colors: [Color.white.opacity(0.7), Color.white.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                )
                .frame(
                    width: isMajor ? 4 : 2,
                    height: isMajor ? 25 : 15
                )
                .shadow(
                    color: isMajor ? Color(hex: "D4AF37").opacity(0.6) : Color.white.opacity(0.3),
                    radius: isMajor ? 3 : 1
                )
            
            // رقم الدرجة (للعلامات الرئيسية فقط)
            if isMajor {
                Text("\(degree)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .offset(y: 5)
            }
        }
        .offset(x: positionX, y: positionY)
    }
}

// MARK: - Compass Small Mark
/// علامة صغيرة على البوصلة (كل 10 درجات)
struct CompassSmallMark: View {
    let degree: Int
    let deviceHeading: Double
    let radius: CGFloat
    
    private var adjustedAngle: Double {
        var angle = Double(degree) - deviceHeading
        angle = angle.truncatingRemainder(dividingBy: 360)
        if angle < 0 { angle += 360 }
        return angle
    }
    
    private var radians: Double {
        (90 - adjustedAngle) * .pi / 180
    }
    
    private var positionX: CGFloat {
        cos(radians) * radius
    }
    
    private var positionY: CGFloat {
        -sin(radians) * radius
    }
    
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.3))
            .frame(width: 1, height: 8)
            .offset(x: positionX, y: positionY)
    }
}

// MARK: - Beautiful Qibla Arrow
/// سهم القبلة الجميل مع تأثيرات بصرية محسّنة
struct BeautifulQiblaArrow: View {
    let isPointingToQibla: Bool
    
    private var primaryColor: Color {
        isPointingToQibla ? Color(hex: "00D26A") : Color(hex: "FFD700")
    }
    
    private var secondaryColor: Color {
        isPointingToQibla ? Color(hex: "00A855") : Color(hex: "D4AF37")
    }
    
    private var glowColor: Color {
        isPointingToQibla ? Color(hex: "00FF7F") : Color(hex: "FFD700")
    }
    
    var body: some View {
        ZStack {
            // التوهج الخارجي المتعدد الطبقات
            if isPointingToQibla {
                ForEach(0..<4, id: \.self) { i in
                    ArrowShape()
                        .fill(glowColor.opacity(0.2 - Double(i) * 0.04))
                        .frame(
                            width: 80 + CGFloat(i * 12),
                            height: 140 + CGFloat(i * 20)
                        )
                        .offset(y: -70)
                        .blur(radius: CGFloat(i * 3 + 2))
                }
            }
            
            // السهم الرئيسي
            ZStack {
                // الظل
                ArrowShape()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 70, height: 130)
                    .offset(x: 2, y: -62)
                    .blur(radius: 6)
                
                // الجسم الرئيسي مع تدرج لوني
                ArrowShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                primaryColor,
                                secondaryColor,
                                secondaryColor.opacity(0.9),
                                secondaryColor.opacity(0.7)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 65, height: 125)
                    .offset(y: -60)
                    .overlay(
                        // تأثير لمعان
                        ArrowShape()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.6),
                                        Color.white.opacity(0.2),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 65, height: 125)
                            .offset(y: -60)
                            .mask(
                                HStack {
                                    Rectangle()
                                        .frame(width: 25)
                                    Spacer()
                                }
                            )
                    )
                
                // الحافة الخارجية المتوهجة
                ArrowShape()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.9),
                                primaryColor.opacity(0.8),
                                secondaryColor.opacity(0.6),
                                secondaryColor
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width: 65, height: 125)
                    .offset(y: -60)
                    .shadow(
                        color: primaryColor.opacity(0.8),
                        radius: 8
                    )
                
                // خط الوسط التفصيلي
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                secondaryColor.opacity(0.6)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3, height: 75)
                    .offset(y: -50)
                
                // رمز القبلة في رأس السهم
                if isPointingToQibla {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.9),
                                        primaryColor.opacity(0.7)
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 10
                                )
                            )
                            .frame(width: 20, height: 20)
                            .shadow(color: primaryColor.opacity(0.8), radius: 5)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(primaryColor)
                    }
                    .offset(y: -95)
                }
            }
            
            // دائرة القاعدة المحسّنة
            ZStack {
                // التوهج
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                secondaryColor.opacity(0.6),
                                secondaryColor.opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 18
                        )
                    )
                    .frame(width: 36, height: 36)
                    .blur(radius: 4)
                
                // الدائرة الرئيسية
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                secondaryColor,
                                secondaryColor.opacity(0.7),
                                secondaryColor.opacity(0.5)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 15
                        )
                    )
                    .frame(width: 30, height: 30)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.8),
                                        secondaryColor.opacity(0.6)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2.5
                            )
                    )
                    .shadow(color: secondaryColor.opacity(0.8), radius: 8)
            }
            .offset(y: 8)
        }
        .animation(.easeInOut(duration: 0.3), value: isPointingToQibla)
    }
}

// MARK: - Fixed Qibla Arrow (السهم الثابت للأعلى)
// هذا السهم لا يدور أبداً - يشير دائماً للأعلى
// المستخدم يدور الجهاز حتى تتوافق البوصلة مع السهم
struct FixedQiblaArrow: View {
    var isPointingToQibla: Bool = false
    
    // الألوان حسب حالة التوجيه
    var primaryColor: Color {
        isPointingToQibla ? Color(hex: "00D26A") : Color(hex: "FFD700")
    }
    
    var secondaryColor: Color {
        isPointingToQibla ? Color(hex: "00A855") : Color(hex: "D4AF37")
    }
    
    var glowColor: Color {
        isPointingToQibla ? Color(hex: "00FF7F") : Color(hex: "FFD700")
    }
    
    var body: some View {
        ZStack {
            // التوهج الخارجي (يظهر عند التوجيه الصحيح)
            if isPointingToQibla {
                // نبضات التوهج
                ForEach(0..<3, id: \.self) { i in
                    ArrowShape()
                        .fill(glowColor.opacity(0.2 - Double(i) * 0.05))
                        .frame(width: 70 + CGFloat(i * 15), height: 130 + CGFloat(i * 20))
                        .offset(y: -60)
                        .blur(radius: CGFloat(i * 4 + 2))
                }
            }
            
            // السهم الرئيسي
            ZStack {
                // الظل
                ArrowShape()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 60, height: 120)
                    .offset(x: 3, y: -57)
                    .blur(radius: 5)
                
                // الجسم الرئيسي للسهم
                ArrowShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                primaryColor,
                                secondaryColor,
                                secondaryColor.opacity(0.8)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 55, height: 115)
                    .offset(y: -60)
                
                // الحافة اليسرى (تأثير 3D)
                ArrowShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 55, height: 115)
                    .offset(y: -60)
                    .mask(
                        HStack {
                            Rectangle()
                                .frame(width: 20)
                            Spacer()
                        }
                    )
                
                // الحافة الخارجية
                ArrowShape()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.8),
                                primaryColor.opacity(0.5),
                                secondaryColor
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 55, height: 115)
                    .offset(y: -60)
                
                // خط الوسط (تفصيل)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                secondaryColor.opacity(0.5)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3, height: 70)
                    .offset(y: -45)
                
                // رمز عند التوجيه الصحيح
                if isPointingToQibla {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .offset(y: -95)
                }
            }
            
            // دائرة القاعدة
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [secondaryColor, secondaryColor.opacity(0.5)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 15
                        )
                    )
                    .frame(width: 24, height: 24)
                
                Circle()
                    .stroke(Color.white.opacity(0.5), lineWidth: 2)
                    .frame(width: 24, height: 24)
            }
            .offset(y: 5)
        }
        .animation(.easeInOut(duration: 0.3), value: isPointingToQibla)
    }
}

// MARK: - Qibla Arrow القديم (للاحتفاظ بالتوافق)
// سهم القبلة المحسّن - يتغير لونه عندما يشير للقبلة
struct EnhancedQiblaArrow: View {
    var isPointingToQibla: Bool = false
    
    // لون السهم يتغير حسب الاتجاه
    var arrowColor: Color {
        isPointingToQibla ? Color(hex: "43AA8B") : Color(hex: "D4AF37")
    }
    
    var body: some View {
        ZStack {
            // التوهج الخارجي
            ForEach(0..<3, id: \.self) { i in
                Triangle()
                    .fill(arrowColor.opacity(0.1 - Double(i) * 0.03))
                    .frame(width: 60 + CGFloat(i * 10), height: 80 + CGFloat(i * 15))
                    .offset(y: -100)
                    .blur(radius: CGFloat(i * 3))
            }
            
            // السهم الرئيسي
            VStack(spacing: 0) {
                // رأس السهم
                ZStack {
                    // الظل
                    Triangle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 55, height: 70)
                        .offset(x: 2, y: 2)
                        .blur(radius: 3)
                    
                    // السهم - يتغير لونه عندما يشير للقبلة
                    Triangle()
                        .fill(
                            LinearGradient(
                                colors: isPointingToQibla ? [
                                    Color(hex: "43AA8B"),
                                    Color(hex: "2D7A5F"),
                                    Color(hex: "1A5A3F")
                                ] : [
                                    Color(hex: "FFD700"),
                                    Color(hex: "D4AF37"),
                                    Color(hex: "B8860B"),
                                    Color(hex: "8B6914")
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 50, height: 65)
                    
                    // اللمعان
                    Triangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.5), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 25, height: 32)
                        .offset(x: -8, y: -10)
                }
                
                // جسم السهم
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "D4AF37"), Color(hex: "B8860B")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 8, height: 45)
            }
            .offset(y: -95)
        }
    }
}

struct QiblaArrow: View {
    var body: some View {
        ZStack {
            // الإشعاع حول السهم
            ForEach(0..<8, id: \.self) { i in
                Rectangle()
                    .fill(Color(hex: "D4AF37").opacity(0.3))
                    .frame(width: 2, height: 20)
                    .offset(y: -130)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
            
            VStack(spacing: 0) {
                // رأس السهم المزخرف
                ZStack {
                    // الظل الخارجي
                    Triangle()
                        .fill(Color(hex: "D4AF37").opacity(0.3))
                        .frame(width: 60, height: 70)
                        .blur(radius: 5)
                    
                    // السهم الرئيسي
                    Triangle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "FFD700"), Color(hex: "D4AF37"), Color(hex: "B8860B")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 50, height: 60)
                    
                    // لمعة على السهم
                    Triangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 25, height: 30)
                        .offset(x: -8, y: -10)
                }
                
                // جسم السهم
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "D4AF37"), Color(hex: "B8860B")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 8, height: 50)
                
                // رمز الكعبة
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "1A1A1A"))
                        .frame(width: 24, height: 24)
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color(hex: "D4AF37"), lineWidth: 2)
                        .frame(width: 20, height: 20)
                }
            }
            .offset(y: -50)
        }
        .shadow(color: Color(hex: "D4AF37").opacity(0.5), radius: 15)
    }
}

// مثلث مخصص للسهم
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Daily Verse View
struct DailyVerseView: View {
    @State private var verse = DailyVerse.random()
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0D1B2A"), Color(hex: "1B263B")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    // الآية
                    VStack(spacing: 20) {
                        Text("﴿")
                            .font(.system(size: 60))
                            .foregroundColor(Color(hex: "D4AF37"))
                        
                        Text(verse.text)
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(12)
                        
                        Text("﴾")
                            .font(.system(size: 60))
                            .foregroundColor(Color(hex: "D4AF37"))
                    }
                    .padding()
                    
                    // المرجع
                    Text(verse.reference)
                        .font(.title3.bold())
                        .foregroundColor(Color(hex: "D4AF37"))
                    
                    // التفسير
                    VStack(alignment: .leading, spacing: 12) {
                        Text("التأمل:")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(verse.reflection)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .lineSpacing(8)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // زر آية جديدة
                    Button {
                        withAnimation {
                            verse = DailyVerse.random()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("آية أخرى")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "D4AF37"))
                        .foregroundColor(.black)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("آية اليوم")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Daily Verse Model
struct DailyVerse {
    let text: String
    let reference: String
    let reflection: String
    
    static let verses: [DailyVerse] = [
        DailyVerse(
            text: "وَمَن يَتَّقِ ٱللَّهَ يَجْعَل لَّهُۥ مَخْرَجًا وَيَرْزُقْهُ مِنْ حَيْثُ لَا يَحْتَسِبُ",
            reference: "سورة الطلاق - الآية 2-3",
            reflection: "من عظيم لطف الله بعباده أن جعل التقوى سبباً للفرج من كل ضيق، ورزقاً من حيث لا يتوقع الإنسان. فالتقوى مفتاح كل خير."
        ),
        DailyVerse(
            text: "إِنَّ مَعَ ٱلْعُسْرِ يُسْرًا",
            reference: "سورة الشرح - الآية 6",
            reflection: "آية تبعث الأمل في القلوب، فمهما اشتد الضيق فإن الفرج قريب. وتكرار الآية تأكيد على أن يسراً واحداً كافٍ لإزالة كل عسر."
        ),
        DailyVerse(
            text: "وَقَالَ رَبُّكُمُ ٱدْعُونِىٓ أَسْتَجِبْ لَكُمْ",
            reference: "سورة غافر - الآية 60",
            reflection: "الله يأمرنا بالدعاء ويعدنا بالإجابة. فالدعاء عبادة عظيمة وباب مفتوح لا يُغلق أبداً بين العبد وربه."
        ),
        DailyVerse(
            text: "فَٱذْكُرُونِىٓ أَذْكُرْكُمْ وَٱشْكُرُواْ لِى وَلَا تَكْفُرُونِ",
            reference: "سورة البقرة - الآية 152",
            reflection: "الذكر والشكر سبيل للقرب من الله. من ذكر الله ذكره الله، ومن شكره زاده. فليكن الذكر والشكر ديدناً دائماً."
        ),
        DailyVerse(
            text: "وَلَا تَحْزَنْ إِنَّ ٱللَّهَ مَعَنَا",
            reference: "سورة التوبة - الآية 40",
            reflection: "معية الله تكفي لطرد كل حزن وخوف. فمن كان الله معه فمن عليه؟ ومن كان الله عليه فمن معه؟"
        ),
        DailyVerse(
            text: "رَبَّنَآ ءَاتِنَا فِى ٱلدُّنْيَا حَسَنَةً وَفِى ٱلْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ ٱلنَّارِ",
            reference: "سورة البقرة - الآية 201",
            reflection: "دعاء جامع لخيري الدنيا والآخرة. علّمنا النبي ﷺ أن نكثر منه، فهو يجمع كل ما يحتاجه الإنسان."
        ),
        DailyVerse(
            text: "وَإِذَا سَأَلَكَ عِبَادِى عَنِّى فَإِنِّى قَرِيبٌ أُجِيبُ دَعْوَةَ ٱلدَّاعِ إِذَا دَعَانِ",
            reference: "سورة البقرة - الآية 186",
            reflection: "قرب الله من عباده أعظم قرب. لم يقل فقل إني قريب، بل قال فإني قريب مباشرة، دلالة على شدة القرب."
        ),
        DailyVerse(
            text: "وَلَسَوْفَ يُعْطِيكَ رَبُّكَ فَتَرْضَىٰٓ",
            reference: "سورة الضحى - الآية 5",
            reflection: "وعد من الله بالعطاء الذي يُرضي. فثق بالله وأحسن الظن به، فإن عطاءه لا حدود له."
        )
    ]
    
    static func random() -> DailyVerse {
        verses.randomElement() ?? verses[0]
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var vm: SettingsViewModel
    
    var body: some View {
        ZStack {
            Color(hex: "1A1A2E").ignoresSafeArea()
            
        Form {
                Section {
                    Toggle("تفعيل الأذان", isOn: $vm.adhanEnabled)
                    Toggle("تفعيل الإقامة", isOn: $vm.iqamaEnabled)
                } header: {
                    Text("الأذان")
                }
                
                Section {
                    Stepper(value: $vm.preAdhanMinutes, in: 5...30, step: 5) {
                        HStack {
                            Text("قبل الأذان")
                            Spacer()
                            Text("\(vm.preAdhanMinutes) د")
                                .foregroundColor(Color(hex: "D4AF37"))
                        }
                        .environment(\.layoutDirection, .rightToLeft)
                    }
                    
                    Stepper(value: $vm.adhanOffsetMinutes, in: 0...30, step: 5) {
                        HStack {
                            Text("وقت الأذان (إزاحة)")
                            Spacer()
                            Text(vm.adhanOffsetMinutes == 0 ? "الوقت الفعلي" : "+\(vm.adhanOffsetMinutes) د")
                                .foregroundColor(Color(hex: "D4AF37"))
                        }
                        .environment(\.layoutDirection, .rightToLeft)
                    }
                    
                    Stepper(value: $vm.iqamaDelayMinutes, in: 5...30, step: 5) {
                        HStack {
                            Text("وقت الإقامة (بعد الأذان)")
                            Spacer()
                            Text("\(vm.iqamaDelayMinutes) د")
                                .foregroundColor(Color(hex: "D4AF37"))
                        }
                        .environment(\.layoutDirection, .rightToLeft)
                    }
                    
                    Text("ملاحظة: يمكن جعل «وقت الأذان» على «الوقت الفعلي» باختيار 0 دقيقة.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .environment(\.layoutDirection, .rightToLeft)
                } header: {
                    Text("التنبيهات والتذكيرات")
                }
                
                Section {
                    Picker("طريقة حساب الصلاة", selection: $vm.selectedMethod) {
                ForEach(CalculationMethod.allCases, id: \.self) { method in
                            Text(method.arabicName).tag(method)
                        }
                    }
                } header: {
                    Text("طريقة الحساب")
                }
                
                Section {
                    Button("طلب إذن الإشعارات") {
                vm.requestNotificationPermission()
            }
                } header: {
                    Text("الأذونات")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("الإعدادات")
    }
}

// MARK: - Islamic Events View (المناسبات الإسلامية - حسب المذهب الحنبلي)
struct IslamicEventsView: View {
    let events: [(name: String, date: String, hijriDate: String, icon: String)] = [
        ("رأس السنة الهجرية", "7 يوليو 2025", "1 محرم 1447", "calendar"),
        ("يوم عاشوراء", "16 يوليو 2025", "10 محرم 1447", "drop.fill"),
        ("بداية شهر رمضان", "26 فبراير 2026", "1 رمضان 1447", "moon.zzz.fill"),
        ("ليلة القدر (تقديرية)", "22 مارس 2026", "27 رمضان 1447", "sparkles"),
        ("عيد الفطر المبارك", "27 مارس 2026", "1 شوال 1447", "gift.fill"),
        ("يوم عرفة", "3 يونيو 2026", "9 ذو الحجة 1447", "mountain.2.fill"),
        ("عيد الأضحى المبارك", "4 يونيو 2026", "10 ذو الحجة 1447", "gift.fill"),
        ("يوم التروية", "2 يونيو 2026", "8 ذو الحجة 1447", "flag.fill"),
        ("أيام التشريق", "5-7 يونيو 2026", "11-13 ذو الحجة 1447", "sun.max.fill")
    ]
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1A1A2E"), Color(hex: "16213E")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    // عنوان
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 50))
                            .foregroundColor(Color(hex: "F4A261"))
                        Text("المناسبات الإسلامية")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Text("للعام الهجري 1447")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.vertical, 20)
                    
                    // قائمة المناسبات
                    ForEach(events, id: \.name) { event in
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "F4A261").opacity(0.2))
                                    .frame(width: 50, height: 50)
                                Image(systemName: event.icon)
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(hex: "F4A261"))
                            }
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(event.name)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(event.hijriDate)
                                    .font(.subheadline)
                                    .foregroundColor(Color(hex: "D4AF37"))
                                Text(event.date)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding()
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(16)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("المناسبات الإسلامية")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Moon Phase View (مرحلة القمر)
struct MoonPhaseView: View {
    @EnvironmentObject var container: AppContainer
    @State private var selectedPhase: MoonPhase14?
    
    private var hijriDay: Int { container.hijri.hijriDay() }
    
    /// نسبة الإضاءة (تقريب فلكي) حسب عمر القمر (0..1)
    private var illumination: Double {
        // تقريب عمر القمر من اليوم الهجري (1..30) إلى دورة 29.53 يوم
        let age = Double(max(1, min(30, hijriDay)) - 1) / 29.0 * 29.530588
        let phaseAngle = 2.0 * Double.pi * (age / 29.530588)
        // Illumination fraction: (1 - cos(phaseAngle)) / 2
        return max(0.0, min(1.0, (1.0 - cos(phaseAngle)) / 2.0))
    }
    
    private var isWaxing: Bool { hijriDay <= 15 }
    
    /// 14 مرحلة (للعرض) — نختار الأقرب حسب نسبة الإضاءة/اتجاه الزيادة أو النقصان
    private var phases: [MoonPhase14] {
        MoonPhase14.all
    }
    
    private var currentPhaseIndex: Int {
        // تحويل يوم الشهر (1..30) إلى 0..13 بشكل متوازن
        let normalized = Double(hijriDay - 1) / 29.0
        return max(0, min(13, Int((normalized * 13.0).rounded())))
    }
    
    private var currentPhase: MoonPhase14 {
        phases[currentPhaseIndex]
    }
    
    var body: some View {
        ZStack {
            // خلفية ليلية
            LinearGradient(
                colors: [Color(hex: "0D1B2A"), Color(hex: "1B263B"), Color(hex: "415A77")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // نجوم متحركة
            GeometryReader { geo in
                ForEach(0..<30, id: \.self) { _ in
                    Circle()
                        .fill(Color.white.opacity(Double.random(in: 0.3...0.8)))
                        .frame(width: CGFloat.random(in: 1...3))
                        .position(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: CGFloat.random(in: 0...geo.size.height * 0.6)
                        )
                }
            }
            
            ScrollView {
                VStack(spacing: 22) {
                    // القمر الحالي (رسمة دقيقة تقريبية)
                    MoonPhotoView(illumination: illumination, waxing: isWaxing)
                        .frame(width: 200, height: 200)
                        .shadow(color: Color(hex: "F5F5DC").opacity(0.45), radius: 28)
                        .padding(.top, 30)
                    
                    // معلومات المرحلة
                    VStack(spacing: 10) {
                        Text(currentPhase.name)
                            .font(.title.bold())
                            .foregroundColor(.white)
                        
                        Text(container.hijri.hijriString())
                            .font(.headline)
                            .foregroundColor(Color(hex: "D4AF37"))
                        
                        HStack {
                            Text("نسبة الإضاءة")
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            Text("\(Int((illumination * 100.0).rounded()))%")
                                .font(.title2.bold())
                                .foregroundColor(Color(hex: "F4A261"))
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        
                        Text(currentPhase.description)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.horizontal)
                    
                    // عرض جميع المراحل (14)
                    VStack(alignment: .trailing, spacing: 12) {
                        Text("مراحل القمر (14 مرحلة)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .environment(\.layoutDirection, .rightToLeft)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 12) {
                            ForEach(phases) { phase in
                                Button {
                                    selectedPhase = phase
                                    DebugFileLogger.log(runId: "ui-change", hypothesisId: "M1", location: "Views.swift:MoonPhaseView.tap", message: "Selected phase", data: ["id": phase.id, "illumPct": Int((phase.illumination * 100).rounded())])
                                } label: {
                                    MoonPhaseCard(
                                        phase: phase,
                                        isSelected: phase.id == currentPhase.id
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // معلومات شرعية عامة (بدون تفاصيل خلافية)
                    VStack(spacing: 12) {
                        InfoRow(title: "دخول الشهر", value: "يُثبت برؤية الهلال عند أهل العلم", icon: "eye.fill")
                        InfoRow(title: "الأيام البيض", value: "13، 14، 15 من كل شهر هجري", icon: "moon.stars.fill")
                        InfoRow(title: "تنبيه", value: "هذه معلومات تقريبية للمتابعة، والمرجع في المواقيت الشرعية للجهات المختصة", icon: "info.circle.fill")
                    }
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 30)
                }
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("مرحلة القمر")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedPhase) { phase in
            MoonPhaseDetailSheet(phase: phase)
        }
        .onAppear {
            DebugFileLogger.log(runId: "ui-change", hypothesisId: "M1", location: "Views.swift:MoonPhaseView.onAppear", message: "MoonPhaseView appeared", data: ["hijriDay": hijriDay, "illumPct": Int((illumination * 100).rounded())])
        }
    }
}

// MARK: - Moon phase models & views
struct MoonPhase14: Identifiable, Hashable {
    let id: Int
    let name: String
    let illumination: Double   // 0..1
    let waxing: Bool
    let description: String
    let examples: String
    let hadithOrAthar: String
    let notes: String
    
    static let all: [MoonPhase14] = [
        .init(id: 0, name: "محاق", illumination: 0.0, waxing: true, description: "يكون القمر غير مرئي تقريباً في السماء.", examples: "تُلاحظ السماء مظلمة بلا قرص قمري واضح.", hadithOrAthar: "الأصل في دخول الشهر: رؤية الهلال (ثبوت الشهر برؤية الهلال عند أهل العلم).", notes: "لا يُبنى حكم شرعي خاص على نسبة الإضاءة نفسها، وإنما العبرة بثبوت الشهر."),
        .init(id: 1, name: "هلال متزايد (1)", illumination: 0.08, waxing: true, description: "بداية ظهور الهلال بعد المحاق.", examples: "قوس رقيق بعد الغروب في الأفق الغربي.", hadithOrAthar: "«صوموا لرؤيته وأفطروا لرؤيته…» (معناه ثابت في الصحيحين).", notes: "قد يختلف ظهور الهلال حسب الأفق والطقس."),
        .init(id: 2, name: "هلال متزايد (2)", illumination: 0.18, waxing: true, description: "يزداد الجزء المضيء تدريجياً.", examples: "الهلال يصبح أوضح واتساعه يزيد كل ليلة.", hadithOrAthar: "من السنن ربط العبادات بالشهور القمرية (رمضان/الحج).", notes: "النسبة هنا تقريب فلكي للتثقيف."),
        .init(id: 3, name: "هلال متزايد (3)", illumination: 0.32, waxing: true, description: "يظهر الهلال أوضح مع ازدياد الإضاءة.", examples: "يظهر الهلال أعلى في السماء ويمكث أطول.", hadithOrAthar: "لا حديث صحيح يربط هذه المرحلة بذاتها بعبادة مخصوصة.", notes: "التطبيق يعرض معلومات تعليمية عامة."),
        .init(id: 4, name: "التربيع الأول", illumination: 0.50, waxing: true, description: "نصف القمر مضيء تقريباً.", examples: "نصف قرص مضيء واضح.", hadithOrAthar: "لا يُعرف نص صحيح يخص هذه المرحلة بحكم مستقل.", notes: "المعيار الشرعي في الشهور: الرؤية/إكمال العدة."),
        .init(id: 5, name: "أحدب متزايد (1)", illumination: 0.65, waxing: true, description: "أكثر من النصف مضيء ويتجه نحو البدر.", examples: "قرص كبير مضيء مع جزء مظلم صغير.", hadithOrAthar: "يستحب صيام التطوع عموماً، ومنه الأيام البيض.", notes: "الأيام البيض: 13/14/15."),
        .init(id: 6, name: "أحدب متزايد (2)", illumination: 0.80, waxing: true, description: "إضاءة عالية وقرب من اكتمال القمر.", examples: "ليل أكثر إنارة طبيعيًا.", hadithOrAthar: "«صيام ثلاثة أيام من كل شهر…» (ورد في السنة بمعناه).", notes: "لا نثبت آثارًا غير منضبطة عن “تأثيرات” روحية مخصوصة."),
        .init(id: 7, name: "بدر", illumination: 1.0, waxing: true, description: "اكتمال إضاءة القمر تقريباً.", examples: "قرص كامل منير.", hadithOrAthar: "ثبت ذكر فضل قيام الليل عموماً، ولا يُخص البدر بعبادة بحديث صحيح مشهور.", notes: "قد لا يصل فعلياً إلى 100% بصرياً حسب الظروف، لكن نعرضه كاملاً لتمثيل البدر."),
        .init(id: 8, name: "أحدب متناقص (1)", illumination: 0.80, waxing: false, description: "يبدأ الجزء المضيء بالنقصان بعد البدر.", examples: "يبدأ القمر بالنقصان من الجهة المقابلة.", hadithOrAthar: "العبرة بليالي الشهر وأيامه في الحسابات الشرعية (عدة، كفارات… إلخ).", notes: "التناقص لا يؤثر على الأحكام إلا من جهة مرور الأيام."),
        .init(id: 9, name: "أحدب متناقص (2)", illumination: 0.65, waxing: false, description: "تتناقص الإضاءة تدريجياً.", examples: "القرص ما زال كبيراً لكن ليس كاملاً.", hadithOrAthar: "لا نص صحيح يربط هذه المرحلة بغزوة معينة على وجه القطع.", notes: "نبتعد عن ربط تاريخي غير موثق."),
        .init(id: 10, name: "التربيع الأخير", illumination: 0.50, waxing: false, description: "نصف القمر مضيء تقريباً (متناقص).", examples: "نصف قرص مضيء في آخر الشهر.", hadithOrAthar: "الأحكام متعلقة بدخول الشهر وخروجه لا بشكل القرص.", notes: "يختلف موضع ظهور القمر حسب الفصل."),
        .init(id: 11, name: "هلال متناقص (1)", illumination: 0.32, waxing: false, description: "يعود القمر إلى شكل الهلال المتناقص.", examples: "هلال يظهر غالباً قبل الفجر.", hadithOrAthar: "«… فإن غُمّ عليكم فأكملوا العدة…» (معناه في الصحيحين).", notes: "مرحلة قريبة من نهاية الشهر."),
        .init(id: 12, name: "هلال متناقص (2)", illumination: 0.18, waxing: false, description: "هلال نحيل قبل العودة للمحاق.", examples: "هلال رقيق صباحاً.", hadithOrAthar: "لا يصح التوسع في أحكام بلا دليل؛ المرجع للجهات المختصة في التحري.", notes: "قد لا يُرى بسبب الظروف الجوية."),
        .init(id: 13, name: "هلال متناقص (3)", illumination: 0.08, waxing: false, description: "آخر مراحل الظهور قبل المحاق.", examples: "آخر الهلال قبل نهاية الشهر.", hadithOrAthar: "الأصل في العبادات التوقيف؛ لا نخص هذه الليلة بعبادة معينة.", notes: "تنبيه: هذا عرض تعليمي، وليس إعلاناً رسمياً لدخول/خروج الشهر.")
    ]
}

/// قمر “واقعي” قدر الإمكان بدون صور خارجية: طبقة إضاءة + ظل + ملمس (craters).
struct MoonPhotoView: View {
    let illumination: Double
    let waxing: Bool
    
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let r = size / 2
            let shift = (1.0 - illumination) * r
            let xOffset = (waxing ? -1.0 : 1.0) * shift
            
            ZStack {
                // قاعدة القمر (لون رمادي مع تدرج)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "F2F2E8"), Color(hex: "CFCFC6")],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: r
                        )
                    )
                
                // ملمس/فوهات بسيطة (بدون صور)
                Canvas { ctx, sz in
                    let craterColor = Color.black.opacity(0.10)
                    let highlight = Color.white.opacity(0.10)
                    func circle(_ x: CGFloat, _ y: CGFloat, _ d: CGFloat, _ c: Color) {
                        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: d, height: d)), with: .color(c))
                    }
                    circle(sz.width*0.25, sz.height*0.30, sz.width*0.10, craterColor)
                    circle(sz.width*0.55, sz.height*0.22, sz.width*0.06, craterColor)
                    circle(sz.width*0.62, sz.height*0.55, sz.width*0.12, craterColor)
                    circle(sz.width*0.32, sz.height*0.62, sz.width*0.07, craterColor)
                    circle(sz.width*0.42, sz.height*0.40, sz.width*0.04, craterColor)
                    
                    // لمعة خفيفة
                    circle(sz.width*0.18, sz.height*0.22, sz.width*0.12, highlight)
                    circle(sz.width*0.66, sz.height*0.32, sz.width*0.10, highlight)
                }
                .clipShape(Circle())
                .opacity(0.9)
                
                // ظل المرحلة: نغطي القمر ثم نقص الجزء المضيء بقناع مزاح
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.75))
                    Circle()
                        .fill(Color.black)
                        .offset(x: xOffset)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
                .clipShape(Circle())
                
                // هالة خفيفة حول القمر
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            }
            .clipShape(Circle())
        }
    }
}

struct MoonPhaseCard: View {
    let phase: MoonPhase14
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            MoonPhotoView(illumination: phase.illumination, waxing: phase.waxing)
                .frame(width: 52, height: 52)
                .shadow(color: Color.white.opacity(0.1), radius: 6)
            
            Text(phase.name)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(isSelected ? Color(hex: "D4AF37").opacity(0.22) : Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color(hex: "D4AF37") : Color.white.opacity(0.12), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color(hex: "D4AF37"))
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                Text(value)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
            }
            Spacer()
        }
    }
}

// MARK: - Moon Phase Detail Sheet
struct MoonPhaseDetailSheet: View {
    let phase: MoonPhase14
    
    var body: some View {
        VStack(spacing: 16) {
            MoonPhotoView(illumination: phase.illumination, waxing: phase.waxing)
                .frame(width: 180, height: 180)
                .shadow(color: Color.white.opacity(0.18), radius: 18)
                .padding(.top, 12)
            
            Text(phase.name)
                .font(.title.bold())
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            HStack {
                Text("نسبة الإضاءة")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int((phase.illumination * 100).rounded()))%")
                    .font(.headline.bold())
            }
            .environment(\.layoutDirection, .rightToLeft)
            .padding()
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(12)
            
            VStack(alignment: .trailing, spacing: 10) {
                Text("وصف")
                    .font(.headline)
                Text(phase.description)
                    .foregroundColor(.secondary)
                
                Text("أمثلة/معلومة")
                    .font(.headline)
                Text(phase.examples)
                    .foregroundColor(.secondary)
                
                Text("نص شرعي مرتبط")
                    .font(.headline)
                Text(phase.hadithOrAthar)
                    .foregroundColor(.secondary)
                
                Text("ملاحظات")
                    .font(.headline)
                Text(phase.notes)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .environment(\.layoutDirection, .rightToLeft)
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Night Times View (أوقات الليل)
struct NightTimesView: View {
    @EnvironmentObject var container: AppContainer
    
    // حساب أوقات الليل
    var maghribTime: Date {
        container.prayerVM.day?.prayers.first(where: { $0.name == "Maghrib" })?.time ?? Date()
    }
    
    var fajrTime: Date {
        // الفجر: إذا كان وقت الفجر أقل من المغرب، فهو فجر اليوم التالي
        let fajr = container.prayerVM.day?.prayers.first(where: { $0.name == "Fajr" })?.time ?? Date()
        let maghrib = maghribTime
        
        // إذا كان الفجر قبل المغرب في نفس اليوم، أضف يوماً
        if fajr < maghrib {
            return Calendar.current.date(byAdding: .day, value: 1, to: fajr) ?? fajr
        }
        return fajr
    }
    
    var nightDuration: TimeInterval {
        fajrTime.timeIntervalSince(maghribTime)
    }
    
    var midnightTime: Date {
        maghribTime.addingTimeInterval(nightDuration / 2)
    }
    
    var lastThirdTime: Date {
        maghribTime.addingTimeInterval(nightDuration * 2 / 3)
    }
    
    var body: some View {
        ZStack {
            // خلفية ليلية
            LinearGradient(
                colors: [Color(hex: "0D1B2A"), Color(hex: "1B263B")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // عنوان
                    VStack(spacing: 12) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Color(hex: "6C63FF"))
                        Text("أوقات الليل")
                            .font(.title.bold())
                            .foregroundColor(.white)
                        Text("أفضل أوقات العبادة والدعاء")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 20)
                    
                    // بطاقات الأوقات
                    VStack(spacing: 16) {
                        NightTimeCard(
                            title: "المغرب",
                            subtitle: "بداية الليل",
                            time: maghribTime,
                            icon: "sunset.fill",
                            color: Color(hex: "F4A261")
                        )
                        
                        NightTimeCard(
                            title: "منتصف الليل",
                            subtitle: "نصف الليل الشرعي",
                            time: midnightTime,
                            icon: "moon.fill",
                            color: Color(hex: "6C63FF")
                        )
                        
                        NightTimeCard(
                            title: "الثلث الأخير",
                            subtitle: "أفضل وقت للدعاء في ثلث الليل",
                            time: lastThirdTime,
                            icon: "moon.stars.fill",
                            color: Color(hex: "D4AF37"),
                            isHighlighted: true
                        )
                        
                        NightTimeCard(
                            title: "الفجر",
                            subtitle: "نهاية الليل",
                            time: fajrTime,
                            icon: "sunrise.fill",
                            color: Color(hex: "43AA8B")
                        )
                    }
                    .padding(.horizontal)
                    
                    // حديث شريف
                    VStack(spacing: 12) {
                        Text("💎 حديث شريف")
                            .font(.headline)
                            .foregroundColor(Color(hex: "D4AF37"))
                        
                        Text("\"يَنْزِلُ رَبُّنَا تَبَارَكَ وَتَعَالَى كُلَّ لَيْلَةٍ إِلَى السَّمَاءِ الدُّنْيَا حِينَ يَبْقَى ثُلُثُ اللَّيْلِ الآخِرُ، يَقُولُ: مَنْ يَدْعُونِي فَأَسْتَجِيبَ لَهُ، مَنْ يَسْأَلُنِي فَأُعْطِيَهُ، مَنْ يَسْتَغْفِرُنِي فَأَغْفِرَ لَهُ\"")
                            .font(.body)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(8)
                        
                        Text("رواه البخاري ومسلم")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("أوقات الليل")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NightTimeCard: View {
    let title: String
    let subtitle: String
    let time: Date
    let icon: String
    let color: Color
    var isHighlighted: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 56, height: 56)
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Text(time.formattedTime())
                .font(.title2.bold())
                .foregroundColor(isHighlighted ? Color(hex: "D4AF37") : .white)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(isHighlighted ? 0.15 : 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isHighlighted ? Color(hex: "D4AF37").opacity(0.5) : Color.clear, lineWidth: 1)
                )
        )
    }
}

// MARK: - About View (الصدقة الجارية)
struct AboutView: View {
    var body: some View {
        ZStack {
            // خلفية متدرجة جميلة
            LinearGradient(
                colors: [Color(hex: "0F2027"), Color(hex: "203A43"), Color(hex: "2C5364")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    // الشعار
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "D4AF37").opacity(0.2))
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "heart.fill")
                                .font(.system(size: 50))
                                .foregroundColor(Color(hex: "D4AF37"))
                        }
                        
                        Text("مؤذني")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("تطبيق إسلامي شامل")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 30)
                    
                    // بطاقة الصدقة الجارية
                    VStack(spacing: 24) {
                        // العنوان
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(Color(hex: "D4AF37"))
                            Text("صدقة جارية")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                            Image(systemName: "star.fill")
                                .foregroundColor(Color(hex: "D4AF37"))
                        }
                        
                        // النص
                        Text("هذا التطبيق صدقة جارية")
                            .font(.title3)
                            .foregroundColor(.white)
                        
                        // خط فاصل
                        Rectangle()
                            .fill(Color(hex: "D4AF37").opacity(0.3))
                            .frame(height: 1)
                            .padding(.horizontal, 40)
                        
                        // الأسماء
                        VStack(spacing: 20) {
                            // عني
                            DedicationRow(
                                label: "عني",
                                name: "حمد سليمان الشبانه",
                                icon: "person.fill"
                            )
                            
                            // والديّ
                            DedicationRow(
                                label: "والدي",
                                name: "الشيخ سليمان محمد الشبانه",
                                icon: "person.fill"
                            )
                            
                            DedicationRow(
                                label: "أمي العزيزة",
                                name: "شيخة عبدالله العقل",
                                icon: "heart.fill"
                            )
                            
                            // زوجتي
                            DedicationRow(
                                label: "زوجتي العزيزة",
                                name: "سجى يوسف الحبردي",
                                icon: "heart.circle.fill"
                            )
                            
                            // والدا زوجتي
                            DedicationRow(
                                label: "أب زوجتي",
                                name: "يوسف الحبردي",
                                icon: "person.fill"
                            )
                            
                            DedicationRow(
                                label: "أم زوجتي",
                                name: "حنان الناصر",
                                icon: "heart.fill"
                            )
                            
                            // ابنتي
                            DedicationRow(
                                label: "ابنتي",
                                name: "شيخة بنت حمد الشبانه",
                                icon: "heart.fill"
                            )
                        }
                        
                        // خط فاصل
                        Rectangle()
                            .fill(Color(hex: "D4AF37").opacity(0.3))
                            .frame(height: 1)
                            .padding(.horizontal, 40)
                        
                        // الدعاء للأسماء المذكورة
                        VStack(spacing: 12) {
                            Text("اللهم اجعل هذا العمل")
                                .foregroundColor(.white.opacity(0.8))
                            Text("في ميزان حسناتهم جميعاً")
                                .foregroundColor(.white.opacity(0.8))
                            Text("واغفر لهم وارحمهم")
                                .foregroundColor(Color(hex: "D4AF37"))
                                .font(.headline)
                        }
                        .font(.body)
                        
                        // خط فاصل
                        Rectangle()
                            .fill(Color(hex: "D4AF37").opacity(0.3))
                            .frame(height: 1)
                            .padding(.horizontal, 40)
                        
                        // أسماء إضافية للدعاء
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "person.3.fill")
                                    .font(.title2)
                                    .foregroundColor(Color(hex: "D4AF37"))
                                Text("جعله الله في ميزان أعمالهم")
                                    .font(.title3.bold())
                                    .foregroundColor(Color(hex: "D4AF37"))
                            }
                            
                            Text("محمد حمد الشبانه ، مزنه العقل ، عبدالله العقل ، شماء الشبيعان ، عبدالله الحبردي ، منيرة المحمدة ، محمد الناصر ، موضي الفياض")
                                .foregroundColor(.white.opacity(0.9))
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .lineSpacing(6)
                                .padding(.horizontal, 8)
                            
                            Text("رحمهم الله وغفر لهم")
                                .foregroundColor(Color(hex: "D4AF37"))
                                .font(.headline)
                                .padding(.top, 4)
                        }
                        .padding(.vertical, 8)
                        
                        // خط فاصل
                        Rectangle()
                            .fill(Color(hex: "D4AF37").opacity(0.3))
                            .frame(height: 1)
                            .padding(.horizontal, 40)
                        
                        // الوقف الخيري
                        VStack(spacing: 16) {
                            HStack {
                                Image(systemName: "hands.sparkles.fill")
                                    .font(.title2)
                                    .foregroundColor(Color(hex: "4CAF50"))
                                Text("وقف خيري")
                                    .font(.title3.bold())
                                    .foregroundColor(Color(hex: "4CAF50"))
                            }
                            
                            Text("هذا العمل وقف خيري عن جميع المسلمين")
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                            
                            Text("الأحياء منهم والأموات")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.subheadline)
                        }
                        .padding(.vertical, 8)
                        
                        // خط فاصل
                        Rectangle()
                            .fill(Color(hex: "D4AF37").opacity(0.3))
                            .frame(height: 1)
                            .padding(.horizontal, 40)
                        
                        // الدعاء الشامل لجميع المسلمين
                        VStack(spacing: 14) {
                            Text("🤲")
                                .font(.largeTitle)
                            
                            Text("اللهم اغفر للمسلمين والمسلمات")
                                .foregroundColor(.white)
                                .font(.headline)
                            
                            Text("والمؤمنين والمؤمنات")
                                .foregroundColor(.white.opacity(0.9))
                            
                            Text("الأحياء منهم والأموات")
                                .foregroundColor(.white.opacity(0.9))
                            
                            Text("إنك سميع قريب مجيب الدعوات")
                                .foregroundColor(Color(hex: "D4AF37"))
                                .font(.headline)
                            
                            Text("اللهم ارحم موتانا وموتى المسلمين")
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.top, 8)
                            
                            Text("وأدخلهم فسيح جناتك")
                                .foregroundColor(.white.opacity(0.9))
                            
                            Text("واجعل ما قدموه في موازين حسناتهم")
                                .foregroundColor(.white.opacity(0.9))
                            
                            Text("يا أرحم الراحمين")
                                .foregroundColor(Color(hex: "D4AF37"))
                                .font(.headline)
                                .padding(.top, 4)
                        }
                        .font(.body)
                        .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color(hex: "D4AF37").opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    
                    // معلومات التطبيق
                    VStack(spacing: 16) {
                        InfoRow(title: "الإصدار", value: "1.0.0", icon: "apps.iphone")
                        InfoRow(title: "مبني بـ", value: "SwiftUI", icon: "swift")
                        InfoRow(title: "عمل لوجه الله سبحانه وتعالى", value: "", icon: "heart.text.square")
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // التواصل والاقتراحات
                    VStack(spacing: 16) {
                        Text("باب التطوير متاح")
                            .font(.headline)
                            .foregroundColor(Color(hex: "D4AF37"))
                        
                        Text("باب الاقتراحات والاستفسارات متاح")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                        
                        Text("للتعاون والتطوع لوجه الله أرجو التواصل معي")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                        
                        Divider()
                            .background(Color.white.opacity(0.3))
                        
                        Text("للتواصل")
                            .font(.headline)
                            .foregroundColor(Color(hex: "4CAF50"))
                        
                        HStack(spacing: 8) {
                            Image(systemName: "phone.fill")
                                .foregroundColor(Color(hex: "D4AF37"))
                            Text("جوال & واتس: 0535024454")
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .font(.subheadline)
                        
                        HStack(spacing: 8) {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(Color(hex: "D4AF37"))
                            Text("ايميل: o.p7@msn.com")
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .font(.subheadline)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // آية
                    VStack(spacing: 12) {
                        Text("﴿ مَّن ذَا الَّذِي يُقْرِضُ اللَّهَ قَرْضًا حَسَنًا فَيُضَاعِفَهُ لَهُ أَضْعَافًا كَثِيرَةً ﴾")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(8)
                        
                        Text("سورة البقرة - 245")
                            .font(.caption)
                            .foregroundColor(Color(hex: "D4AF37"))
                    }
                    .padding()
                    
                    Spacer(minLength: 50)
                }
            }
        }
        .navigationTitle("نبذة عن التطبيق")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Dedication Row
struct DedicationRow: View {
    let label: String
    let name: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "D4AF37"))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                if !name.isEmpty {
                    Text(name)
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
}


// MARK: - Developer Test View (وضع تجريبي للمطور)
struct DeveloperTestView: View {
    @EnvironmentObject var container: AppContainer
    @State private var isPlayingAdhan = false
    @State private var isPlayingIqama = false
    @State private var testNotificationSent = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1A1A2E"), Color(hex: "16213E")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // العنوان
                    VStack(spacing: 12) {
                        Image(systemName: "hammer.fill")
                            .font(.system(size: 50))
                            .foregroundColor(Color(hex: "FF6B6B"))
                        Text("وضع المطور")
                            .font(.title.bold())
                            .foregroundColor(.white)
                        Text("اختبر الأصوات والإشعارات")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 20)
                    
                    // قسم الأصوات
                    VStack(spacing: 16) {
                        Text("🔊 تجربة الأصوات")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // زر تشغيل الأذان
                        Button {
                            if isPlayingAdhan {
                                container.notifications.stopSound()
                                isPlayingAdhan = false
                            } else {
                                container.notifications.playAdhanForTesting()
                                isPlayingAdhan = true
                                isPlayingIqama = false
                            }
                        } label: {
                            HStack {
                                Image(systemName: isPlayingAdhan ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.title)
                                Text(isPlayingAdhan ? "إيقاف الأذان" : "تشغيل الأذان")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "speaker.wave.3.fill")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(isPlayingAdhan ? Color.red.opacity(0.3) : Color(hex: "D4AF37").opacity(0.3))
                            .cornerRadius(12)
                        }
                        
                        // زر تشغيل الإقامة
                        Button {
                            if isPlayingIqama {
                                container.notifications.stopSound()
                                isPlayingIqama = false
                            } else {
                                container.notifications.playIqamaForTesting()
                                isPlayingIqama = true
                                isPlayingAdhan = false
                            }
                        } label: {
                            HStack {
                                Image(systemName: isPlayingIqama ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.title)
                                Text(isPlayingIqama ? "إيقاف الإقامة" : "تشغيل الإقامة")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "speaker.wave.2.fill")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(isPlayingIqama ? Color.red.opacity(0.3) : Color(hex: "43AA8B").opacity(0.3))
                            .cornerRadius(12)
                        }
                        
                        // زر إيقاف الكل
                        Button {
                            container.notifications.stopSound()
                            isPlayingAdhan = false
                            isPlayingIqama = false
                        } label: {
                            HStack {
                                Image(systemName: "stop.fill")
                                Text("إيقاف جميع الأصوات")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.5))
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // قسم الإشعارات
                    VStack(spacing: 16) {
                        Text("🔔 تجربة الإشعارات")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // إشعار قبل الأذان
                        Button {
                            container.notifications.sendTestNotification(type: .preAdhan)
                            testNotificationSent = true
                        } label: {
                            HStack {
                                Image(systemName: "bell.badge.fill")
                                Text("إشعار قبل الأذان (10 دقائق)")
                                Spacer()
                                Image(systemName: "arrow.right.circle")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color(hex: "F4A261").opacity(0.3))
                            .cornerRadius(12)
                        }
                        
                        // إشعار الأذان
                        Button {
                            container.notifications.sendTestNotification(type: .adhan)
                            testNotificationSent = true
                        } label: {
                            HStack {
                                Image(systemName: "bell.fill")
                                Text("إشعار وقت الأذان")
                                Spacer()
                                Image(systemName: "arrow.right.circle")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color(hex: "D4AF37").opacity(0.3))
                            .cornerRadius(12)
                        }
                        
                        // إشعار الإقامة
                        Button {
                            container.notifications.sendTestNotification(type: .iqama)
                            testNotificationSent = true
                        } label: {
                            HStack {
                                Image(systemName: "bell.and.waves.left.and.right.fill")
                                Text("إشعار الإقامة")
                                Spacer()
                                Image(systemName: "arrow.right.circle")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color(hex: "43AA8B").opacity(0.3))
                            .cornerRadius(12)
                        }
                        
                        if testNotificationSent {
                            Text("✅ تم إرسال الإشعار - تحقق من مركز الإشعارات")
                                .font(.caption)
                                .foregroundColor(Color(hex: "90BE6D"))
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // ملاحظات
                    VStack(spacing: 8) {
                        Text("💡 ملاحظات")
                            .font(.headline)
                            .foregroundColor(Color(hex: "D4AF37"))
                        
                        Text("• تأكد من وجود ملفات الصوت (adhan.caf, iqama.caf) في الموارد")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text("• الإشعارات تحتاج إذن المستخدم للعمل")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text("• في حالة عدم وجود الملفات، سيتم تشغيل صوت النظام")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 50)
                }
            }
        }
        .navigationTitle("وضع المطور")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            container.notifications.stopSound()
        }
    }
}

// MARK: - Prayer Stats View (إحصائيات الصلاة)
struct PrayerStatsView: View {
    @EnvironmentObject var container: AppContainer
    
    let prayers = ["الفجر", "الظهر", "العصر", "المغرب", "العشاء"]
    
    // حساب اليوم الحالي من الشهر
    var currentDayOfMonth: Int {
        Calendar.current.component(.day, from: Date())
    }
    
    // حساب عدد أيام الشهر الحالي
    var daysInCurrentMonth: Int {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: Date())
        return range?.count ?? 30
    }
    
    // حساب عدد الصلوات المفترضة حتى الآن (5 صلوات × عدد الأيام التي مرت)
    var totalExpectedPrayers: Int {
        return currentDayOfMonth * 5
    }
    
    // حساب عدد الصلوات لكل صلاة (= عدد الأيام التي مرت)
    var prayersPerType: Int {
        return currentDayOfMonth
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1A1A2E"), Color(hex: "16213E")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // ملاحظة توضيحية
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(Color(hex: "4ECDC4"))
                        Text("الإحصائيات تُحسب تلقائياً من بداية الشهر")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    // معلومات الشهر
                    VStack(spacing: 8) {
                        Text("اليوم \(currentDayOfMonth) من الشهر")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text("إجمالي الصلوات المفترضة: \(totalExpectedPrayers)")
                            .font(.caption)
                            .foregroundColor(Color(hex: "4ECDC4"))
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // الإجمالي
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 50))
                            .foregroundColor(Color(hex: "4ECDC4"))
                        
                        Text("\(totalExpectedPrayers)")
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("صلاة حتى الآن هذا الشهر")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 10)
                    
                    // الإحصائيات التفصيلية (تلقائية)
                    VStack(spacing: 16) {
                        ForEach(prayers, id: \.self) { prayer in
                            AutoPrayerStatRow(
                                prayer: prayer,
                                completed: prayersPerType,
                                total: daysInCurrentMonth
                            )
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // نصيحة
                    VStack(spacing: 12) {
                        Text("💡 نصيحة")
                            .font(.headline)
                            .foregroundColor(Color(hex: "D4AF37"))
                        
                        Text("\"إِنَّ الصَّلَاةَ كَانَتْ عَلَى الْمُؤْمِنِينَ كِتَابًا مَّوْقُوتًا\"")
                            .font(.body)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("سورة النساء - 103")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // معلومات إضافية
                    VStack(spacing: 8) {
                        Text("📊 كيف تُحسب الإحصائيات؟")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        
                        Text("يتم حساب عدد الصلوات تلقائياً بناءً على عدد الأيام التي مرت من الشهر الحالي. كل يوم يمر يُضاف 5 صلوات للإجمالي.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                    
                    Spacer(minLength: 50)
                }
            }
        }
        .navigationTitle("إحصائيات الصلاة")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// صف إحصائيات الصلاة التلقائي (بدون أزرار)
struct AutoPrayerStatRow: View {
    let prayer: String
    let completed: Int
    let total: Int
    
    var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(prayer)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(completed)/\(total)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "4ECDC4"), Color(hex: "44A08D")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - حاسبة العذر الشرعي للمرأة
struct ExcuseCalculatorView: View {
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var showResult = false
    @State private var missedPrayers = 0
    @State private var missedFasts = 0
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "880E4F"), Color(hex: "4A148C")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // العنوان والتوضيح
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 50))
                            .foregroundColor(Color(hex: "F48FB1"))
                        
                        Text("حاسبة العذر الشرعي")
                            .font(.title.bold())
                            .foregroundColor(.white)
                        
                        Text("لحساب الصلوات والصيام الفائتة خلال فترة العذر الشرعي للمرأة")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    
                    // تاريخ البداية
                    VStack(alignment: .leading, spacing: 8) {
                        Text("تاريخ بداية العذر")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        DatePicker("", selection: $startDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .accentColor(Color(hex: "F48FB1"))
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                    }
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // تاريخ النهاية
                    VStack(alignment: .leading, spacing: 8) {
                        Text("تاريخ نهاية العذر (أو اليوم الحالي)")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        DatePicker("", selection: $endDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .accentColor(Color(hex: "F48FB1"))
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                    }
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // زر الحساب
                    Button {
                        calculateMissed()
                        showResult = true
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                    } label: {
                        HStack {
                            Image(systemName: "calculator")
                            Text("احسب الفائت")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "E91E63"), Color(hex: "9C27B0")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                    }
                    .padding(.horizontal)
                    
                    // النتيجة
                    if showResult {
                        VStack(spacing: 20) {
                            Text("📊 النتيجة")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                            
                            // عدد الأيام
                            let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
                            
                            HStack(spacing: 30) {
                                VStack(spacing: 8) {
                                    Text("\(max(days + 1, 0))")
                                        .font(.system(size: 40, weight: .bold, design: .rounded))
                                        .foregroundColor(Color(hex: "F48FB1"))
                                    Text("يوم")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                
                                VStack(spacing: 8) {
                                    Text("\(missedPrayers)")
                                        .font(.system(size: 40, weight: .bold, design: .rounded))
                                        .foregroundColor(Color(hex: "CE93D8"))
                                    Text("صلاة فائتة")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                
                                VStack(spacing: 8) {
                                    Text("\(missedFasts)")
                                        .font(.system(size: 40, weight: .bold, design: .rounded))
                                        .foregroundColor(Color(hex: "B39DDB"))
                                    Text("يوم صيام")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            
                            // ملاحظة مهمة
                            VStack(spacing: 8) {
                                Text("⚠️ ملاحظة مهمة")
                                    .font(.headline)
                                    .foregroundColor(Color(hex: "D4AF37"))
                                
                                Text("الصلوات الفائتة بسبب العذر الشرعي لا تُقضى، أما الصيام فيجب قضاؤه بعد رمضان")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding()
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(16)
                        .padding(.horizontal)
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    // معلومات شرعية
                    VStack(spacing: 12) {
                        Text("📖 حكم شرعي")
                            .font(.headline)
                            .foregroundColor(Color(hex: "D4AF37"))
                        
                        Text("قالت عائشة رضي الله عنها: \"كان يصيبنا ذلك فنؤمر بقضاء الصوم ولا نؤمر بقضاء الصلاة\"")
                            .font(.body)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("رواه مسلم")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 50)
                }
            }
        }
        .navigationTitle("حاسبة العذر الشرعي")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.layoutDirection, .rightToLeft)
    }
    
    private func calculateMissed() {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        let totalDays = max(days + 1, 0)
        
        // 5 صلوات في اليوم
        missedPrayers = totalDays * 5
        
        // أيام الصيام (إذا كان في رمضان)
        missedFasts = totalDays
    }
}

// الكود القديم للإحصائيات اليدوية (للمرجع)
struct PrayerStatsViewManual: View {
    // حفظ الإحصائيات في UserDefaults
    @AppStorage("prayer_stats_data") private var statsData: Data = Data()
    @AppStorage("prayer_stats_start_date") private var startDateString: String = ""
    @State private var prayersCompleted: [String: Int] = [:]
    @State private var startDate: Date = Date()
    
    let prayers = ["الفجر", "الظهر", "العصر", "المغرب", "العشاء"]
    
    var totalPrayers: Int {
        prayersCompleted.values.reduce(0, +)
    }
    
    var daysInCurrentMonth: Int {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: Date())
        return range?.count ?? 30
    }
    
    var daysSinceStart: Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: startDate, to: Date()).day ?? 0
    }
    
    var body: some View {
        Text("Manual Stats View - Not Used")
    }
    
    private func loadStats() {
        if let decoded = try? JSONDecoder().decode([String: Int].self, from: statsData) {
            prayersCompleted = decoded
        } else {
            // إنشاء إحصائيات جديدة
            for prayer in prayers {
                prayersCompleted[prayer] = 0
            }
        }
        
        // تحميل تاريخ البداية
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: startDateString) {
            startDate = date
        } else {
            startDate = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
            startDateString = formatter.string(from: startDate)
        }
    }
    
    private func saveStats() {
        if let encoded = try? JSONEncoder().encode(prayersCompleted) {
            statsData = encoded
        }
    }
    
    private func resetStats() {
        for prayer in prayers {
            prayersCompleted[prayer] = 0
        }
        startDate = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
        startDateString = ISO8601DateFormatter().string(from: startDate)
        saveStats()
    }
    
    private func checkMonthReset() {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())
        let startMonth = calendar.component(.month, from: startDate)
        
        if currentMonth != startMonth {
            resetStats()
        }
    }
}

struct PrayerStatRow: View {
    let prayer: String
    let completed: Int
    let total: Int
    var onIncrement: (() -> Void)? = nil
    var onDecrement: (() -> Void)? = nil
    
    var percentage: Double {
        Double(completed) / Double(total)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // أزرار التعديل
                if let decrement = onDecrement {
                    Button(action: decrement) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red.opacity(0.7))
                    }
                }
                
                if let increment = onIncrement {
                    Button(action: increment) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Color(hex: "4ECDC4"))
                    }
                }
                
                Text(prayer)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(completed)/\(total)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "4ECDC4"), Color(hex: "43AA8B")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * percentage, height: 12)
                }
            }
            .frame(height: 12)
        }
    }
}

// MARK: - Dua of Day View (دعاء اليوم)
struct DuaOfDayView: View {
    @State private var currentDua = DailyDua.random()
    
    var body: some View {
        ZStack {
            // خلفية جميلة
            LinearGradient(
                colors: [Color(hex: "0F2027"), Color(hex: "203A43"), Color(hex: "2C5364")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    // العنوان
                    VStack(spacing: 12) {
                        Image(systemName: "hands.sparkles.fill")
                            .font(.system(size: 50))
                            .foregroundColor(Color(hex: "95E1D3"))
                        Text("دعاء اليوم")
                            .font(.title.bold())
                            .foregroundColor(.white)
                    }
                    .padding(.top, 30)
                    
                    // الدعاء
                    VStack(spacing: 20) {
                        Text(currentDua.arabic)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(12)
                        
                        Divider()
                            .background(Color(hex: "D4AF37").opacity(0.5))
                        
                        Text(currentDua.meaning)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                        
                        HStack {
                            Image(systemName: "book.fill")
                                .foregroundColor(Color(hex: "D4AF37"))
                            Text(currentDua.reference)
                                .font(.caption)
                                .foregroundColor(Color(hex: "D4AF37"))
                        }
                        
                        if let benefit = currentDua.benefit {
                            Text("✨ \(benefit)")
                                .font(.subheadline)
                                .foregroundColor(Color(hex: "95E1D3"))
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                    .padding(24)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    // زر دعاء جديد
                    Button {
                        withAnimation {
                            currentDua = DailyDua.random()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("دعاء آخر")
                        }
                        .font(.headline)
                        .foregroundColor(.black)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(hex: "D4AF37"))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 50)
                }
            }
        }
        .navigationTitle("دعاء اليوم")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DailyDua {
    let arabic: String
    let meaning: String
    let reference: String
    let benefit: String?
    
    static let duas: [DailyDua] = [
        DailyDua(
            arabic: "اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَافِيَةَ فِي الدُّنْيَا وَالْآخِرَةِ",
            meaning: "اللهم إني أسألك العافية في الدنيا والآخرة",
            reference: "ابن ماجه",
            benefit: "ما سُئل شيء أفضل من العافية"
        ),
        DailyDua(
            arabic: "رَبِّ اشْرَحْ لِي صَدْرِي وَيَسِّرْ لِي أَمْرِي",
            meaning: "رب اشرح لي صدري ويسر لي أمري",
            reference: "سورة طه",
            benefit: "دعاء موسى عليه السلام"
        ),
        DailyDua(
            arabic: "اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ",
            meaning: "اللهم إني أعوذ بك من الهم والحزن",
            reference: "البخاري",
            benefit: "من أدعية النبي ﷺ الجامعة"
        ),
        DailyDua(
            arabic: "يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ",
            meaning: "يا حي يا قيوم برحمتك أستغيث",
            reference: "الترمذي",
            benefit: "دعاء الاستغاثة بالله"
        ),
        DailyDua(
            arabic: "اللَّهُمَّ أَصْلِحْ لِي دِينِي الَّذِي هُوَ عِصْمَةُ أَمْرِي",
            meaning: "اللهم أصلح لي ديني الذي هو عصمة أمري",
            reference: "مسلم",
            benefit: "دعاء جامع لخيري الدنيا والآخرة"
        ),
        DailyDua(
            arabic: "رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ",
            meaning: "ربنا آتنا في الدنيا حسنة وفي الآخرة حسنة وقنا عذاب النار",
            reference: "سورة البقرة",
            benefit: "أكثر دعاء النبي ﷺ"
        ),
        DailyDua(
            arabic: "اللَّهُمَّ إِنِّي أَسْأَلُكَ الْهُدَى وَالتُّقَى وَالْعَفَافَ وَالْغِنَى",
            meaning: "اللهم إني أسألك الهدى والتقى والعفاف والغنى",
            reference: "مسلم",
            benefit: nil
        ),
        DailyDua(
            arabic: "لَا إِلَهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ",
            meaning: "لا إله إلا أنت سبحانك إني كنت من الظالمين",
            reference: "سورة الأنبياء",
            benefit: "دعاء يونس عليه السلام - ما دعا به مسلم إلا استجاب الله له"
        )
    ]
    
    static func random() -> DailyDua {
        duas.randomElement() ?? duas[0]
    }
}

// MARK: - Audio Reciters View (القراء الصوتيين)
struct AudioRecitersView: View {
    @EnvironmentObject var container: AppContainer
    @State private var searchText = ""
    @State private var selectedReciter: MP3Reciter?
    @State private var showingPlayer = false
    
    var filteredReciters: [MP3Reciter] {
        if searchText.isEmpty {
            return container.mp3Quran.reciters
        }
        return container.mp3Quran.searchReciters(query: searchText)
    }
    
    var body: some View {
        ZStack {
            Color(hex: "0D1B2A").ignoresSafeArea()
            
            if container.mp3Quran.isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("جاري تحميل القراء...")
                        .foregroundColor(.white)
                }
            } else if let error = container.mp3Quran.error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)
                    Text("خطأ في تحميل القراء")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Button("إعادة المحاولة") {
                        Task { await container.mp3Quran.loadInitialData() }
                    }
                    .buttonStyle(GoldButtonStyle())
                }
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // شريط البحث
                        HStack {
                            TextField("ابحث عن قارئ...", text: $searchText)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.trailing)
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        // عدد القراء
                        HStack {
                            Spacer()
                            Text("عدد القراء: \(filteredReciters.count)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.horizontal)
                        
                        // قائمة القراء
                        ForEach(filteredReciters) { reciter in
                            ReciterCard(reciter: reciter) {
                                selectedReciter = reciter
                                showingPlayer = true
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("تلاوات القراء")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.layoutDirection, .rightToLeft)
        .sheet(isPresented: $showingPlayer) {
            if let reciter = selectedReciter {
                ReciterPlayerView(reciter: reciter)
                    .environmentObject(container)
            }
        }
    }
}

// MARK: - Reciter Card
struct ReciterCard: View {
    let reciter: MP3Reciter
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // سهم التنقل (يظهر على اليمين في RTL)
                Image(systemName: "chevron.left")
                    .foregroundColor(.white.opacity(0.5))
                
                Spacer()
                
                // معلومات القارئ (محاذاة لليمين)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(reciter.name)
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    
                    if let moshaf = reciter.moshaf.first {
                        Text(moshaf.name)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.trailing)
                        
                        HStack(spacing: 4) {
                            Text("\(moshaf.surahTotal) سورة")
                                .font(.caption2)
                            Image(systemName: "music.note.list")
                                .font(.caption2)
                        }
                        .foregroundColor(Color(hex: "D4AF37"))
                    }
                }
                
                // أيقونة القارئ (على اليمين في RTL)
                ZStack {
                    Circle()
                        .fill(Color(hex: "D4AF37").opacity(0.2))
                        .frame(width: 56, height: 56)
                    Text(reciter.letter)
                        .font(.title2.bold())
                        .foregroundColor(Color(hex: "D4AF37"))
                }
            }
            .padding()
            .background(Color.white.opacity(0.08))
            .cornerRadius(16)
            .padding(.horizontal)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - Reciter Player View
struct ReciterPlayerView: View {
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) var dismiss
    let reciter: MP3Reciter
    
    @State private var selectedSurah: MP3Surah?
    @State private var isPlaying = false
    @State private var searchText = ""
    
    var filteredSurahs: [MP3Surah] {
        let available = container.mp3Quran.surahList.filter { surah in
            container.mp3Quran.isSurahAvailable(reciter: reciter, surahNumber: surah.id)
        }
        
        if searchText.isEmpty {
            return available
        }
        return available.filter { $0.name.contains(searchText) }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0D1B2A").ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // معلومات القارئ
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "D4AF37"), Color(hex: "B8860B")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            Text(reciter.letter)
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        Text(reciter.name)
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        
                        if let moshaf = reciter.moshaf.first {
                            Text(moshaf.name)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.05))
                    .environment(\.layoutDirection, .rightToLeft)
                    
                    // شريط البحث
                    HStack {
                        TextField("ابحث عن سورة...", text: $searchText)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.trailing)
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .padding()
                    
                    // قائمة السور
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredSurahs) { surah in
                                SurahAudioCard(
                                    surah: surah,
                                    isSelected: selectedSurah?.id == surah.id,
                                    isPlaying: isPlaying && selectedSurah?.id == surah.id
                                ) {
                                    playSurah(surah)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("اختر سورة")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.layoutDirection, .rightToLeft)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إغلاق") {
                        stopPlaying()
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "D4AF37"))
                }
            }
        }
    }
    
    private func playSurah(_ surah: MP3Surah) {
        selectedSurah = surah
        
        if let url = container.mp3Quran.getAudioURL(reciter: reciter, surahNumber: surah.id) {
            container.audio.playStream(url: url)
            isPlaying = true
        }
    }
    
    private func stopPlaying() {
        container.audio.stop()
        isPlaying = false
    }
}

// MARK: - Surah Audio Card
struct SurahAudioCard: View {
    let surah: MP3Surah
    let isSelected: Bool
    let isPlaying: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // زر التشغيل (يظهر على اليسار في RTL)
                ZStack {
                    Circle()
                        .fill(isSelected ? Color(hex: "D4AF37") : Color.white.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    if isPlaying {
                        // أيقونة التشغيل المتحركة
                        HStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(isSelected ? Color.black : Color.white)
                                    .frame(width: 3, height: 12 + CGFloat(i) * 4)
                            }
                        }
                    } else {
                        Image(systemName: "play.fill")
                            .foregroundColor(isSelected ? .black : .white)
                    }
                }
                
                Spacer()
                
                // اسم السورة (محاذاة لليمين)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(surah.name)
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.trailing)
                    
                    HStack(spacing: 8) {
                        Text(surah.revelationType)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "D4AF37").opacity(0.2))
                            .cornerRadius(4)
                            .foregroundColor(Color(hex: "D4AF37"))
                    }
                }
                
                // رقم السورة (يظهر على اليمين في RTL)
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color(hex: "D4AF37") : Color.white.opacity(0.1))
                        .frame(width: 40, height: 40)
                    Text("\(surah.id)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isSelected ? .black : .white)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(hex: "D4AF37").opacity(0.1) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color(hex: "D4AF37") : Color.clear, lineWidth: 1)
                    )
            )
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - Quran Radio View (إذاعة القرآن)
struct QuranRadioView: View {
    @EnvironmentObject var container: AppContainer
    @State private var radios: [MP3Radio] = []
    @State private var isLoading = true
    @State private var currentRadio: MP3Radio?
    @State private var isPlaying = false
    
    var body: some View {
        ZStack {
            Color(hex: "0D1B2A").ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(radios) { radio in
                            RadioCard(
                                radio: radio,
                                isPlaying: isPlaying && currentRadio?.id == radio.id
                            ) {
                                playRadio(radio)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("المكتبة الإسلامية الصوتية الشاملة")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadRadios()
        }
    }
    
    private func loadRadios() async {
        do {
            radios = try await container.mp3Quran.fetchRadios()
        } catch {
            print("❌ خطأ في تحميل الإذاعات: \(error)")
        }
        isLoading = false
    }
    
    private func playRadio(_ radio: MP3Radio) {
        if currentRadio?.id == radio.id && isPlaying {
            container.audio.stop()
            isPlaying = false
        } else {
            if let url = URL(string: radio.url) {
                container.audio.playStream(url: url)
                currentRadio = radio
                isPlaying = true
            }
        }
    }
}

// MARK: - Radio Card
struct RadioCard: View {
    let radio: MP3Radio
    let isPlaying: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // أيقونة الإذاعة
                ZStack {
                    Circle()
                        .fill(
                            isPlaying ?
                            LinearGradient(colors: [Color(hex: "D4AF37"), Color(hex: "B8860B")], startPoint: .top, endPoint: .bottom) :
                            LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: 56, height: 56)
                    
                    if isPlaying {
                        // موجات صوتية متحركة
                        Image(systemName: "waveform")
                            .font(.title2)
                            .foregroundColor(.black)
                    } else {
                        Image(systemName: "radio.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                
                // اسم الإذاعة
                Text(radio.name)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.trailing)
                
                Spacer()
                
                // زر التشغيل
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.title2)
                    .foregroundColor(isPlaying ? Color(hex: "D4AF37") : .white.opacity(0.5))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isPlaying ? Color(hex: "D4AF37") : Color.clear, lineWidth: 2)
                    )
            )
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - Custom Button Styles
struct GreenButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color(hex: "D4AF37"))
            .foregroundColor(.black)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

struct GoldButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color(hex: "D4AF37"))
            .foregroundColor(.black)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Haptic Feedback Manager
/// مدير الاهتزازات للبوصلة - يوفر feedback عند الوصول للقبلة
final class HapticFeedbackManager {
    static let shared = HapticFeedbackManager()
    
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let successNotification = UINotificationFeedbackGenerator()
    private let warningNotification = UINotificationFeedbackGenerator()
    
    private var lastQiblaState: Bool = false
    private var lastAccuracyState: AccuracyLevel = .unknown
    
    private init() {
        // تحضير الـ generators للأداء الأفضل
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        successNotification.prepare()
        warningNotification.prepare()
    }
    
    /// اهتزاز عند الوصول للقبلة
    func qiblaReached() {
        successNotification.notificationOccurred(.success)
        mediumImpact.impactOccurred()
    }
    
    /// اهتزاز عند الاقتراب من القبلة
    func qiblaApproaching() {
        lightImpact.impactOccurred()
    }
    
    /// اهتزاز عند تحذير الدقة
    func accuracyWarning() {
        warningNotification.notificationOccurred(.warning)
    }
    
    /// تحديث الحالة مع feedback تلقائي
    func updateState(isPointingToQibla: Bool, accuracy: Double) {
        let accuracyLevel = AccuracyLevel.from(accuracy: accuracy)
        
        // اهتزاز عند الوصول للقبلة لأول مرة
        if isPointingToQibla && !lastQiblaState {
            qiblaReached()
        }
        
        // اهتزاز عند تغيير حالة الدقة
        if accuracyLevel != lastAccuracyState {
            if accuracyLevel == .poor || accuracyLevel == .unreliable {
                accuracyWarning()
            }
            lastAccuracyState = accuracyLevel
        }
        
        lastQiblaState = isPointingToQibla
    }
}

// MARK: - Accuracy Level Enum
enum AccuracyLevel {
    case excellent  // < 5°
    case good       // 5-10°
    case fair       // 10-15°
    case poor       // 15-25°
    case unreliable // > 25° or < 0
    case unknown    // accuracy < 0
    
    static func from(accuracy: Double) -> AccuracyLevel {
        if accuracy < 0 {
            return .unknown
        } else if accuracy <= 5 {
            return .excellent
        } else if accuracy <= 10 {
            return .good
        } else if accuracy <= 15 {
            return .fair
        } else if accuracy <= 25 {
            return .poor
        } else {
            return .unreliable
        }
    }
    
    var color: Color {
        switch self {
        case .excellent: return Color(hex: "00D26A")
        case .good: return Color(hex: "43AA8B")
        case .fair: return Color(hex: "FFD700")
        case .poor: return Color(hex: "FF6B6B")
        case .unreliable: return Color(hex: "FF0000")
        case .unknown: return Color.white.opacity(0.5)
        }
    }
    
    var label: String {
        switch self {
        case .excellent: return "ممتازة"
        case .good: return "جيدة"
        case .fair: return "مقبولة"
        case .poor: return "ضعيفة"
        case .unreliable: return "غير موثوقة"
        case .unknown: return "غير معروفة"
        }
    }
}

// MARK: - Accuracy Indicator Component
/// مؤشر مستوى دقة البوصلة
struct AccuracyIndicator: View {
    let accuracy: Double
    let level: AccuracyLevel
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: level.icon)
                    .foregroundColor(level.color)
                    .font(.caption)
                
                Text("دقة البوصلة")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                Text(level.label)
                    .font(.caption.bold())
                    .foregroundColor(level.color)
            }
            
            // شريط التقدم
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // الخلفية
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)
                    
                    // التقدم
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [level.color, level.color.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 6)
            
            if accuracy > 0 {
                Text("±\(accuracy, specifier: "%.0f")°")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
    }
    
    private var progress: Double {
        switch level {
        case .excellent: return 1.0
        case .good: return 0.8
        case .fair: return 0.6
        case .poor: return 0.4
        case .unreliable: return 0.2
        case .unknown: return 0.0
        }
    }
}

extension AccuracyLevel {
    var icon: String {
        switch self {
        case .excellent: return "checkmark.circle.fill"
        case .good: return "checkmark.circle"
        case .fair: return "exclamationmark.circle"
        case .poor: return "exclamationmark.triangle.fill"
        case .unreliable: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}

// MARK: - Simple Accuracy Indicator (مبسط)
/// مؤشر دقة البوصلة المبسط - يعرض الرقم فقط بدون شريط تقدم أو تقييم
struct SimpleAccuracyIndicator: View {
    let accuracy: Double
    
    var body: some View {
        HStack {
            Image(systemName: "location.north.circle")
                .foregroundColor(QiblaTheme.accent)
                .font(.caption)
            
            Text("دقة البوصلة")
                .font(.caption)
                .foregroundColor(QiblaTheme.textSecondary)
            
            Spacer()
            
            if accuracy > 0 {
                Text("±\(accuracy, specifier: "%.0f")°")
                    .font(.caption.bold())
                    .foregroundColor(QiblaTheme.textPrimary)
            } else {
                Text("جاري القياس...")
                    .font(.caption)
                    .foregroundColor(QiblaTheme.textSecondary)
            }
        }
        .padding(12)
        .background(QiblaTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(QiblaTheme.stroke, lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

// MARK: - Magnetic Interference Indicator
/// مؤشر التشويش المغناطيسي
struct MagneticInterferenceIndicator: View {
    let hasInterference: Bool
    let interferenceLevel: InterferenceLevel
    
    enum InterferenceLevel {
        case none
        case low
        case medium
        case high
        
        var color: Color {
            switch self {
            case .none: return Color(hex: "00D26A")
            case .low: return Color(hex: "FFD700")
            case .medium: return Color(hex: "FF6B6B")
            case .high: return Color(hex: "FF0000")
            }
        }
        
        var label: String {
            switch self {
            case .none: return "لا يوجد"
            case .low: return "منخفض"
            case .medium: return "متوسط"
            case .high: return "عالي"
            }
        }
        
        var icon: String {
            switch self {
            case .none: return "antenna.radiowaves.left.and.right"
            case .low: return "antenna.radiowaves.left.and.right"
            case .medium: return "exclamationmark.triangle.fill"
            case .high: return "exclamationmark.octagon.fill"
            }
        }
    }
    
    var body: some View {
        if hasInterference {
            HStack(spacing: 8) {
                Image(systemName: interferenceLevel.icon)
                    .foregroundColor(interferenceLevel.color)
                    .font(.caption)
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("تشويش مغناطيسي")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.trailing)
                    
                    Text(interferenceLevel.label)
                        .font(.caption2)
                        .foregroundColor(interferenceLevel.color)
                        .multilineTextAlignment(.trailing)
                }
                
                Spacer()
            }
            .padding(12)
            .background(interferenceLevel.color.opacity(0.15))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(interferenceLevel.color.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    /// خوارزمية محسنة لكشف التشويش المغناطيسي
    ///
    /// ## التحسينات:
    /// 1. **تحليل متعدد العوامل**: لا يعتمد فقط على accuracy
    /// 2. **تمييز أفضل**: يفصل بين عدم المعايرة والتشويش الفعلي
    /// 3. **قيم عتبة محسنة**: بناءً على معايير Apple و CoreLocation
    /// 4. **Hysteresis**: تجنب التذبذب بين المستويات
    ///
    /// ## معايير التقييم:
    /// - **accuracy < 0**: غير معاير أو خطأ في القياس → high
    /// - **accuracy > 45**: دقة منخفضة جداً → high
    /// - **accuracy > 30**: دقة متوسطة → medium
    /// - **accuracy > 20**: دقة مقبولة مع تحذير → low
    /// - **calibrationNeeded**: قد يكون عدم معايرة وليس تشويش → medium (بدلاً من high)
    ///
    /// ## ملاحظات:
    /// - القيم بناءً على معايير Apple: accuracy < 0 = uncalibrated, > 20 = poor
    /// - calibrationNeeded قد يعني فقط حاجة للمعايرة وليس تشويش فعلي
    /// - القيم المحسنة توفر تجربة مستخدم أفضل مع تقليل الإنذارات الكاذبة
    static func detectInterference(accuracy: Double, calibrationNeeded: Bool) -> (hasInterference: Bool, level: InterferenceLevel) {
        // حالة خاصة: accuracy < 0 يعني عدم معايرة أو خطأ في القياس
        // هذه حالة حرجة تتطلب معالجة فورية
        if accuracy < 0 {
            return (true, .high)
        }
        
        // حالة حرجة: دقة منخفضة جداً (> 45 درجة)
        // هذه القيمة تشير إلى تشويش مغناطيسي قوي أو بيئة مشوشة جداً
        if accuracy > 45 {
            return (true, .high)
        }
        
        // حالة متوسطة: دقة منخفضة (30-45 درجة)
        // قد يكون تشويش متوسط أو بيئة مشوشة جزئياً
        if accuracy > 30 {
            return (true, .medium)
        }
        
        // حالة منخفضة: دقة مقبولة لكن ليست مثالية (20-30 درجة)
        // تحذير بسيط للمستخدم
        if accuracy > 20 {
            return (true, .low)
        }
        
        // حالة calibrationNeeded: قد تكون فقط حاجة للمعايرة وليس تشويش فعلي
        // نعاملها كحالة متوسطة (medium) بدلاً من high لتجنب الإنذارات الكاذبة
        // لأن عدم المعايرة يمكن حلها بسهولة عبر المعايرة
        if calibrationNeeded {
            // إذا كانت الدقة جيدة (< 20) لكن calibrationNeeded = true
            // فهذا يعني فقط حاجة للمعايرة وليس تشويش
            if accuracy <= 20 {
                return (true, .low) // تحذير بسيط
            } else {
                // إذا كانت الدقة سيئة أيضاً، نعاملها كحالة متوسطة
                return (true, .medium)
            }
        }
        
        // لا يوجد تشويش: دقة جيدة (< 20 درجة) وعدم حاجة للمعايرة
        return (false, .none)
    }
    
    /// نسخة متقدمة من خوارزمية الكشف (للاستخدام المستقبلي)
    /// تدعم عوامل إضافية مثل heading variance و magnetic field magnitude
    ///
    /// - Parameters:
    ///   - accuracy: دقة القراءة من CoreLocation (بالدرجات)
    ///   - calibrationNeeded: هل تحتاج معايرة
    ///   - headingVariance: تباين الاتجاه (اختياري) - قيم عالية تشير لتشويش
    ///   - magneticMagnitude: قوة المجال المغناطيسي (اختياري) - μT
    ///   - anomalyDetected: هل تم كشف شذوذ من MagneticAnomalyDetector (اختياري)
    ///   - confidence: مستوى الثقة من MagneticAnomalyDetector (0-1) (اختياري)
    ///
    /// - Returns: حالة التشويش ومستواه
    static func detectInterferenceAdvanced(
        accuracy: Double,
        calibrationNeeded: Bool,
        headingVariance: Double? = nil,
        magneticMagnitude: Double? = nil,
        anomalyDetected: Bool? = nil,
        confidence: Double? = nil
    ) -> (hasInterference: Bool, level: InterferenceLevel) {
        var interferenceScore: Double = 0.0
        
        // 1. عامل Accuracy (الوزن: 40%)
        if accuracy < 0 {
            interferenceScore += 4.0 // حالة حرجة
        } else if accuracy > 45 {
            interferenceScore += 3.5
        } else if accuracy > 30 {
            interferenceScore += 2.5
        } else if accuracy > 20 {
            interferenceScore += 1.0
        }
        
        // 2. عامل CalibrationNeeded (الوزن: 20%)
        if calibrationNeeded {
            // إذا كانت الدقة جيدة، فهذا يعني فقط حاجة للمعايرة
            if accuracy > 0 && accuracy <= 20 {
                interferenceScore += 0.5
            } else {
                interferenceScore += 1.5
            }
        }
        
        // 3. عامل Heading Variance (الوزن: 20%) - إذا كان متاحاً
        if let variance = headingVariance {
            // تباين عالي (> 15 درجة) يشير لتشويش
            if variance > 25 {
                interferenceScore += 2.0
            } else if variance > 15 {
                interferenceScore += 1.0
            } else if variance > 10 {
                interferenceScore += 0.5
            }
        }
        
        // 4. عامل Magnetic Magnitude (الوزن: 10%) - إذا كان متاحاً
        if let magnitude = magneticMagnitude {
            // المجال الطبيعي: 20-60 μT
            if magnitude < 10 || magnitude > 100 {
                interferenceScore += 1.5 // خارج النطاق الطبيعي
            } else if magnitude < 15 || magnitude > 70 {
                interferenceScore += 0.5 // قريب من الحدود
            }
        }
        
        // 5. عامل Anomaly Detector (الوزن: 10%) - إذا كان متاحاً
        if let anomaly = anomalyDetected, anomaly {
            interferenceScore += 1.0
        }
        
        // 6. عامل Confidence (يقلل من النتيجة إذا كانت الثقة عالية)
        if let conf = confidence {
            // إذا كانت الثقة منخفضة (< 0.5)، نزيد النتيجة
            if conf < 0.3 {
                interferenceScore += 0.5
            } else if conf < 0.5 {
                interferenceScore += 0.25
            }
        }
        
        // تحديد المستوى بناءً على النتيجة الإجمالية
        if interferenceScore >= 3.5 {
            return (true, .high)
        } else if interferenceScore >= 2.0 {
            return (true, .medium)
        } else if interferenceScore >= 0.5 {
            return (true, .low)
        } else {
            return (false, .none)
        }
    }
}

// MARK: - Enhanced Calibration Indicator
/// مؤشر حالة المعايرة المحسن
struct EnhancedCalibrationIndicator: View {
    let calibrationNeeded: Bool
    let onCalibrate: () -> Void
    
    @State private var isAnimating = false
    
    var body: some View {
        if calibrationNeeded {
            Button(action: onCalibrate) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.2))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "scope")
                            .foregroundColor(.orange)
                            .font(.title3)
                            .rotationEffect(.degrees(isAnimating ? 360 : 0))
                            .animation(
                                Animation.linear(duration: 2)
                                    .repeatForever(autoreverses: false),
                                value: isAnimating
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("معايرة البوصلة مطلوبة")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        
                        Text("حرّك الجهاز بحركة رقم 8 لتحسين الدقة")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.left")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
                .padding(16)
                .background(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.2),
                            Color.orange.opacity(0.1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.4), lineWidth: 2)
                )
            }
            .onAppear {
                isAnimating = true
            }
            .onDisappear {
                isAnimating = false
            }
        }
    }
}

// MARK: - Enhanced Compass View (تصميم جديد ومحسن)
/// بوصلة القبلة - تصميم بسيط وواضح
/// 
/// المبدأ الأساسي:
/// - السهم ثابت دائماً في الأعلى (يشير للأمام)
/// - البوصلة تدور حتى يصبح اتجاه القبلة في الأعلى
/// - عندما يكون السهم أخضر = أنت موجه للقبلة
struct EnhancedCompassView: View {
    let arrowRotation: Double      // زاوية دوران البوصلة (qiblaDirection - deviceHeading)
    let isPointingToQibla: Bool    // هل الجهاز موجه للقبلة
    let deviceHeading: Double      // اتجاه الجهاز الحالي
    private let lockThreshold: Double = 7      // نافذة تثبيت
    
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowIntensity: Double = 0.3
    
    private let compassSize: CGFloat = 300
    private let innerRingSize: CGFloat = 260
    
    var body: some View {
        ZStack {
            // 1. الحلقة الخارجية (ثابتة)
            Circle()
                .stroke(
                    isPointingToQibla ? Color(hex: "00D26A") : Color(hex: "D4AF37"),
                    lineWidth: 4
                )
                .frame(width: compassSize, height: compassSize)
                .shadow(
                    color: isPointingToQibla ? Color(hex: "00D26A").opacity(0.5) : Color(hex: "D4AF37").opacity(0.3),
                    radius: isPointingToQibla ? 15 : 8
                )
                .scaleEffect(pulseScale)
            
            // 2. البوصلة الداخلية (تدور لتشير للقبلة)
            ZStack {
                // الحلقة الداخلية
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    .frame(width: innerRingSize, height: innerRingSize)
                
                // علامات الدرجات
                ForEach(0..<36, id: \.self) { i in
                    let degree = i * 10
                    Rectangle()
                        .fill(degree % 90 == 0 ? Color(hex: "D4AF37") : Color.white.opacity(0.3))
                        .frame(width: degree % 90 == 0 ? 3 : 1, height: degree % 90 == 0 ? 15 : 8)
                        .offset(y: -innerRingSize / 2 + 10)
                        .rotationEffect(.degrees(Double(degree)))
                }
                
                // الاتجاهات الأربعة
                CompassDirectionText(text: "N", angle: 0, radius: innerRingSize / 2 - 35, isNorth: true)
                CompassDirectionText(text: "E", angle: 90, radius: innerRingSize / 2 - 35, isNorth: false)
                CompassDirectionText(text: "S", angle: 180, radius: innerRingSize / 2 - 35, isNorth: false)
                CompassDirectionText(text: "W", angle: 270, radius: innerRingSize / 2 - 35, isNorth: false)
            }
            .rotationEffect(.degrees(-displayedArrowRotation))
            .animation(compassAnimation, value: displayedArrowRotation)
            
            // 3. المركز (الكعبة)
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                isPointingToQibla ? Color(hex: "00D26A").opacity(0.3) : Color(hex: "D4AF37").opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Circle()
                    .fill(Color(hex: "0D1B2A"))
                    .frame(width: 60, height: 60)
                
                Circle()
                    .stroke(
                        isPointingToQibla ? Color(hex: "00D26A") : Color(hex: "D4AF37"),
                        lineWidth: 2
                    )
                    .frame(width: 60, height: 60)
                
                Text("🕋")
                    .font(.system(size: 30))
            }
            
            // 4. السهم الثابت في الأعلى (يشير للأمام دائماً)
            VStack(spacing: 0) {
                // رأس السهم
                Image(systemName: "arrowtriangle.up.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(isPointingToQibla ? Color(hex: "00D26A") : Color(hex: "FFD700"))
                    .shadow(color: isPointingToQibla ? Color(hex: "00D26A").opacity(0.8) : Color(hex: "FFD700").opacity(0.5), radius: 10)
                
                // جسم السهم
                Rectangle()
                    .fill(isPointingToQibla ? Color(hex: "00D26A") : Color(hex: "FFD700"))
                    .frame(width: 6, height: 50)
                    .shadow(color: isPointingToQibla ? Color(hex: "00D26A").opacity(0.5) : Color(hex: "FFD700").opacity(0.3), radius: 5)
            }
            .offset(y: -80)
        }
        .frame(width: compassSize + 20, height: compassSize + 20)
        .onAppear {
            if isPointingToQibla {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseScale = 1.05
                }
            }
        }
        .onChange(of: isPointingToQibla) { oldValue, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseScale = 1.05
                }
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    pulseScale = 1.0
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("بوصلة القبلة")
        .accessibilityValue(isPointingToQibla ? "موجه للقبلة" : "غير موجه للقبلة")
    }
    
    // MARK: - Helpers
    private var displayedArrowRotation: Double {
        let normalized = normalizeAngle(arrowRotation)
        let diff = shortestDelta(toZero: normalized)
        if abs(diff) <= lockThreshold { return 0 }
        return normalized
    }
    
    private var compassAnimation: Animation? {
        let diff = shortestDelta(toZero: normalizeAngle(arrowRotation))
        return abs(diff) <= lockThreshold ? nil : .spring(response: 0.25, dampingFraction: 0.7)
    }
    
    private func normalizeAngle(_ angle: Double) -> Double {
        var a = angle.truncatingRemainder(dividingBy: 360)
        if a < 0 { a += 360 }
        return a
    }
    
    private func shortestDelta(toZero angle: Double) -> Double {
        var delta = angle
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return delta
    }
}

// MARK: - Source Badge
private struct SourceBadge: View {
    let source: QiblaService.Source
    let isStale: Bool
    
    private var text: String {
        switch source {
        case .api: return "المصدر: API القبلة"
        case .cache: return isStale ? "المصدر: كاش قديم" : "المصدر: كاش"
        case .gpsFallback: return "المصدر: GPS (بديل)"
        case .localCalculation: return "المصدر: حساب محلي دقيق"
        }
    }
    
    private var color: Color {
        switch source {
        case .api: return QiblaTheme.accentStrong
        case .cache: return isStale ? .orange : QiblaTheme.accent
        case .gpsFallback: return .orange
        case .localCalculation: return QiblaTheme.accentStrong
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(text)
                .font(.caption.bold())
                .foregroundColor(QiblaTheme.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(QiblaTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(QiblaTheme.stroke, lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

// MARK: - Compass Direction Text
private struct CompassDirectionText: View {
    let text: String
    let angle: Double
    let radius: CGFloat
    let isNorth: Bool
    
    var body: some View {
        Text(text)
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundColor(isNorth ? Color(hex: "FF6B6B") : .white.opacity(0.9))
            .offset(y: -radius)
            .rotationEffect(.degrees(angle))
            .rotationEffect(.degrees(-angle), anchor: .center)
    }
}

// MARK: - Compass Tick (علامة الدرجات) - للتوافق
private struct CompassTick: View {
    let degree: Int
    
    var body: some View {
        Rectangle()
            .fill(tickColor)
            .frame(width: tickWidth, height: tickHeight)
    }
    
    private var tickColor: Color {
        if degree % 90 == 0 {
            return Color(hex: "D4AF37")
        } else if degree % 45 == 0 {
            return Color.white.opacity(0.6)
        } else if degree % 15 == 0 {
            return Color.white.opacity(0.3)
        } else {
            return Color.white.opacity(0.15)
        }
    }
    
    private var tickWidth: CGFloat {
        if degree % 90 == 0 { return 3 }
        else if degree % 45 == 0 { return 2 }
        else { return 1 }
    }
    
    private var tickHeight: CGFloat {
        if degree % 90 == 0 { return 20 }
        else if degree % 45 == 0 { return 15 }
        else if degree % 15 == 0 { return 10 }
        else { return 5 }
    }
}

// MARK: - Fixed Direction Label (اتجاه ثابت) - للتوافق
private struct FixedDirectionLabel: View {
    let text: String
    let angle: Double
    let radius: CGFloat
    let isNorth: Bool
    
    var body: some View {
        Text(text)
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundColor(isNorth ? Color(hex: "FF6B6B") : .white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.7))
            )
            .offset(y: -radius)
            .rotationEffect(.degrees(angle))
            .rotationEffect(.degrees(-angle), anchor: .center)
    }
}

// MARK: - Qibla Arrow View (سهم القبلة) - للتوافق
private struct QiblaArrowView: View {
    let isPointingToQibla: Bool
    
    private let arrowLength: CGFloat = 100
    private let arrowWidth: CGFloat = 24
    
    var body: some View {
        VStack(spacing: 0) {
            // رأس السهم
            Triangle()
                .fill(
                    LinearGradient(
                        colors: isPointingToQibla ? [
                            Color(hex: "00D26A"),
                            Color(hex: "00FF7F")
                        ] : [
                            Color(hex: "FFD700"),
                            Color(hex: "FFA500")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: arrowWidth + 16, height: 30)
                .shadow(color: isPointingToQibla ? Color(hex: "00D26A").opacity(0.6) : Color(hex: "FFD700").opacity(0.6), radius: 8)
            
            // جسم السهم
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: isPointingToQibla ? [
                            Color(hex: "00D26A").opacity(0.9),
                            Color(hex: "00D26A").opacity(0.6)
                        ] : [
                            Color(hex: "FFD700").opacity(0.9),
                            Color(hex: "FFA500").opacity(0.6)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 8, height: arrowLength - 30)
                .shadow(color: isPointingToQibla ? Color(hex: "00D26A").opacity(0.4) : Color(hex: "FFD700").opacity(0.4), radius: 4)
        }
        .offset(y: -arrowLength / 2 - 35)
    }
}


// MARK: - Enhanced Instructions View
/// تعليمات محسنة للمستخدم
struct EnhancedInstructionsView: View {
    let isPointingToQibla: Bool
    let isDeviceReady: Bool
    let accuracyLevel: AccuracyLevel
    
    var body: some View {
        VStack(spacing: 12) {
            // الحالة الرئيسية
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            isPointingToQibla ?
                                Color(hex: "00D26A").opacity(0.2) :
                                Color(hex: "D4AF37").opacity(0.2)
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: isPointingToQibla ? "checkmark.circle.fill" : "arrow.up.circle.fill")
                        .foregroundColor(isPointingToQibla ? Color(hex: "00D26A") : Color(hex: "D4AF37"))
                        .font(.title2)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(isPointingToQibla ? "✓ أنت متجه للقبلة" : "حرّك جهازك حتى يشير السهم إلى القبلة")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    
                    if !isPointingToQibla {
                        Text("اتبع السهم الذهبي للوصول للاتجاه الصحيح")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Spacer()
            }
            
            // تعليمات إضافية
            if !isPointingToQibla {
                VStack(alignment: .leading, spacing: 8) {
                    InstructionRow(
                        icon: "arrow.up",
                        text: "السهم الذهبي يتحرك مع تغير اتجاه الجهاز",
                        color: Color(hex: "D4AF37")
                    )
                    
                    InstructionRow(
                        icon: "checkmark.circle",
                        text: "عند التوجيه الصحيح سيتحول السهم إلى اللون الأخضر",
                        color: Color(hex: "00D26A")
                    )
                    
                    if !isDeviceReady {
                        InstructionRow(
                            icon: "iphone",
                            text: "للحصول على قراءة دقيقة، ضع الجهاز بشكل مسطح",
                            color: .orange
                        )
                    }
                    
                    if accuracyLevel == .poor || accuracyLevel == .unreliable {
                        InstructionRow(
                            icon: "exclamationmark.triangle",
                            text: "الدقة منخفضة - ابتعد عن المعادن والأجهزة الإلكترونية",
                            color: .red
                        )
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            isPointingToQibla ?
                LinearGradient(
                    colors: [Color(hex: "00D26A").opacity(0.3), Color(hex: "00A855").opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ) :
                LinearGradient(
                    colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isPointingToQibla ? Color(hex: "00D26A").opacity(0.5) : Color.clear,
                    lineWidth: 2
                )
        )
        .animation(.easeInOut(duration: 0.3), value: isPointingToQibla)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(isPointingToQibla ? "موجه للقبلة" : "تعليمات التوجيه")
    }
}

// MARK: - Instruction Row Component
struct InstructionRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
                .frame(width: 20)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
        }
    }
}
