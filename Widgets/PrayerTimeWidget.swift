import WidgetKit
import SwiftUI

struct PrayerEntry: TimelineEntry {
    let date: Date
    let nextPrayer: Prayer?
}

struct PrayerProvider: TimelineProvider {
    func placeholder(in context: Context) -> PrayerEntry { .init(date: Date(), nextPrayer: nil) }
    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        completion(.init(date: Date(), nextPrayer: nil))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        // Production: read from shared app group cache of PrayerDay and compute next prayer.
        let entry = PrayerEntry(date: Date(), nextPrayer: nil)
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(1800))))
    }
}

struct PrayerWidgetView: View {
    var entry: PrayerProvider.Entry
    var body: some View {
        VStack(alignment: .leading) {
            Text("Next Prayer").font(.headline)
            if let p = entry.nextPrayer {
                Text(p.arabicName).font(.title3)
                Text(p.time.formattedTime()).font(.caption)
            } else {
                Text("Loading…").font(.caption)
            }
        }
        .padding()
    }
}

struct PrayerWidget: Widget {
    let kind: String = "PrayerWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerProvider()) { entry in
            PrayerWidgetView(entry: entry)
        }
        .configurationDisplayName("Prayer Time")
        .description("Shows the next prayer time")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct Widgets: WidgetBundle {
    var body: some Widget {
        PrayerWidget()
    }
}

