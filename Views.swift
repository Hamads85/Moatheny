import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            PrayerTimesView()
                .tabItem { Label("Prayer", systemImage: "clock") }
            QuranView()
                .tabItem { Label("Quran", systemImage: "book") }
            AzkarView()
                .tabItem { Label("Azkar", systemImage: "hands.sparkles") }
            MoreView()
                .tabItem { Label("More", systemImage: "ellipsis") }
        }
    }
}

struct PrayerTimesView: View {
    @EnvironmentObject var vm: PrayerTimesViewModel
    @EnvironmentObject var container: AppContainer

    var body: some View {
        NavigationView {
            Group {
                if let day = vm.day {
                    List(day.prayers) { prayer in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(prayer.name).font(.headline)
                                Text(prayer.arabicName).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(prayer.time.formattedTime())
                        }
                    }
                } else if vm.isLoading {
                    ProgressView("Loading…")
                } else if let err = vm.error {
                    Text(err).foregroundColor(.red)
                } else {
                    Text("No data yet").foregroundColor(.secondary)
                }
            }
            .navigationTitle("Prayer Times")
            .toolbar {
                Button {
                    Task { await vm.refresh() }
                } label: { Image(systemName: "arrow.clockwise") }
            }
            .task { await vm.refresh() }
        }
    }
}

struct QuranView: View {
    @EnvironmentObject var vm: QuranViewModel

    var body: some View {
        NavigationView {
            List(vm.surahs) { surah in
                NavigationLink(destination: SurahDetailView(surah: surah)) {
                    VStack(alignment: .leading) {
                        Text("\(surah.id). \(surah.englishName)")
                        Text(surah.name).font(.headline)
                        Text("\(surah.numberOfAyahs) ayahs").font(.footnote).foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Quran")
            .task { await vm.load() }
        }
    }
}

struct SurahDetailView: View {
    let surah: Surah
    var body: some View {
        List(surah.ayahs) { ayah in
            VStack(alignment: .leading, spacing: 8) {
                Text("\(ayah.numberInSurah). \(ayah.text)")
                if let first = ayah.translations?.first {
                    Text(first.text).font(.footnote).foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(surah.englishName)
    }
}

struct AzkarView: View {
    @EnvironmentObject var vm: AzkarViewModel
    var body: some View {
        NavigationView {
            List(AzkarCategory.allCases, id: \.self) { cat in
                Section(cat.rawValue) {
                    ForEach(vm.azkarByCategory[cat] ?? []) { zikr in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(zikr.arabicText)
                            Text(zikr.translation).font(.footnote)
                            Text("Repeat: \(zikr.repetitionCount)").font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Azkar")
            .task { await vm.load() }
        }
    }
}

struct MoreView: View {
    var body: some View {
        List {
            NavigationLink("Tasbih Counter", destination: TasbihView())
            NavigationLink("Qibla", destination: QiblaView())
            NavigationLink("Settings", destination: SettingsView())
        }
        .navigationTitle("More")
    }
}

struct TasbihView: View {
    @State private var count = 0
    var body: some View {
        VStack(spacing: 20) {
            Text("Tasbih").font(.largeTitle)
            Text("\(count)").font(.system(size: 48, weight: .bold))
            HStack {
                Button("Reset") { count = 0 }
                Button("Add") { count += 1 }
            }
            .buttonStyle(.borderedProminent)
        }.padding()
    }
}

struct QiblaView: View {
    @EnvironmentObject var container: AppContainer
    @State private var heading: Double = 0
    var body: some View {
        VStack {
            Text("Qibla Direction")
            Text("\(heading, specifier: "%.0f")°").font(.largeTitle)
        }
        .onAppear {
            if let loc = container.location.currentLocation {
                heading = container.qibla.bearing(from: loc.coordinate)
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var vm: SettingsViewModel
    var body: some View {
        Form {
            Toggle("Enable Adhan", isOn: $vm.adhanEnabled)
            Picker("Calc Method", selection: $vm.selectedMethod) {
                ForEach(CalculationMethod.allCases, id: \.self) { method in
                    Text(String(describing: method)).tag(method)
                }
            }
            Button("Request Notification Permission") {
                vm.requestNotificationPermission()
            }
        }
        .navigationTitle("Settings")
    }
}

