//
//  PrayerTimeWidgetControl.swift
//  PrayerTimeWidget
//
//  Created by Hamad Alshabanah on 06/12/2025.
//

import AppIntents
import SwiftUI
import WidgetKit

struct PrayerTimeWidgetControl: ControlWidget {
    static let kind: String = "com.YourMangaApp.Moatheny.PrayerTimeWidget"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            provider: Provider()
        ) { value in
            ControlWidgetToggle(
                "تشغيل",
                isOn: value.isRunning,
                action: StartTimerIntent(value.name)
            ) { isRunning in
                Label(isRunning ? "مفعّل" : "متوقف", systemImage: "timer")
            }
        }
        .displayName("أداة التحكم")
        .description("تحكم بسيط (تجريبي) ضمن الودجت.")
    }
}

extension PrayerTimeWidgetControl {
    struct Value {
        var isRunning: Bool
        var name: String
    }

    struct Provider: AppIntentControlValueProvider {
        func previewValue(configuration: TimerConfiguration) -> Value {
            PrayerTimeWidgetControl.Value(isRunning: false, name: configuration.timerName)
        }

        func currentValue(configuration: TimerConfiguration) async throws -> Value {
            let isRunning = true // Check if the timer is running
            return PrayerTimeWidgetControl.Value(isRunning: isRunning, name: configuration.timerName)
        }
    }
}

struct TimerConfiguration: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "إعداد الاسم"

    @Parameter(title: "الاسم", default: "مؤذني")
    var timerName: String
}

struct StartTimerIntent: SetValueIntent {
    static let title: LocalizedStringResource = "تبديل الحالة"

    @Parameter(title: "الاسم")
    var name: String

    @Parameter(title: "الحالة")
    var value: Bool

    init() {}

    init(_ name: String) {
        self.name = name
    }

    func perform() async throws -> some IntentResult {
        // Start the timer…
        return .result()
    }
}
