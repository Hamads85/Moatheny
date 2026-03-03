//
//  Widgets_PrayerTimeWidget_swift_LiveActivity.swift
//  Widgets/PrayerTimeWidget.swift.
//
//  Created by Hamad Alshabanah on 06/12/2025.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct Widgets_PrayerTimeWidget_swift_Attributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct Widgets_PrayerTimeWidget_swift_LiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: Widgets_PrayerTimeWidget_swift_Attributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension Widgets_PrayerTimeWidget_swift_Attributes {
    fileprivate static var preview: Widgets_PrayerTimeWidget_swift_Attributes {
        Widgets_PrayerTimeWidget_swift_Attributes(name: "World")
    }
}

extension Widgets_PrayerTimeWidget_swift_Attributes.ContentState {
    fileprivate static var smiley: Widgets_PrayerTimeWidget_swift_Attributes.ContentState {
        Widgets_PrayerTimeWidget_swift_Attributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: Widgets_PrayerTimeWidget_swift_Attributes.ContentState {
         Widgets_PrayerTimeWidget_swift_Attributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: Widgets_PrayerTimeWidget_swift_Attributes.preview) {
   Widgets_PrayerTimeWidget_swift_LiveActivity()
} contentStates: {
    Widgets_PrayerTimeWidget_swift_Attributes.ContentState.smiley
    Widgets_PrayerTimeWidget_swift_Attributes.ContentState.starEyes
}
