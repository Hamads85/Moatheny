//
//  PrayerTimeWidgetBundle.swift
//  PrayerTimeWidget
//
//  Created by Hamad Alshabanah on 06/12/2025.
//

import WidgetKit
import SwiftUI

@main
struct PrayerTimeWidgetBundle: WidgetBundle {
    var body: some Widget {
        PrayerTimeWidget()
        PrayerTimeWidgetControl()
        PrayerTimeWidgetLiveActivity()
    }
}
