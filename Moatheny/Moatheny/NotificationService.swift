import Foundation
import UserNotifications
import AVFoundation
import Combine
import AudioToolbox
import UIKit

/// Manages Adhan and Azkar reminders.
final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var isAdhanEnabled = true
    @Published var isIqamaEnabled = true
    /// قبل الأذان (بالدقائق)
    @Published var preAdhanMinutes: Int = 10 { didSet { persistSettings() } }
    
    /// إزاحة تنبيه الأذان (0 = وقت الأذان تماماً) — اختياري
    @Published var adhanOffsetMinutes: Int = 0 { didSet { persistSettings() } }
    
    /// تأخير الإقامة بعد الأذان (بالدقائق)
    @Published var iqamaDelayMinutes: Int = 15 { didSet { persistSettings() } }
    @Published var notificationStatus: String = ""
    @Published var isDailyDuaEnabled = true
    @Published var isIshaReminderEnabled = true // تذكير العشاء قبل منتصف الليل
    @Published var isWuduReminderEnabled = true // تذكير الوضوء قبل الصلاة
    
    private var audioPlayer: AVAudioPlayer?
    
    // أدعية يومية متنوعة
    static let dailyDuas: [(title: String, dua: String)] = [
        ("دعاء الصباح", "اللَّهُمَّ بِكَ أَصْبَحْنَا، وَبِكَ أَمْسَيْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ النُّشُورُ"),
        ("دعاء الحفظ", "اللَّهُمَّ احْفَظْنِي مِنْ بَيْنِ يَدَيَّ وَمِنْ خَلْفِي وَعَنْ يَمِينِي وَعَنْ شِمَالِي وَمِنْ فَوْقِي"),
        ("دعاء الرزق", "اللَّهُمَّ إِنِّي أَسْأَلُكَ عِلْمًا نَافِعًا، وَرِزْقًا طَيِّبًا، وَعَمَلًا مُتَقَبَّلًا"),
        ("دعاء الهداية", "اللَّهُمَّ اهْدِنِي وَسَدِّدْنِي، اللَّهُمَّ إِنِّي أَسْأَلُكَ الْهُدَى وَالتُّقَى"),
        ("دعاء الشكر", "اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ"),
        ("دعاء العافية", "اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَافِيَةَ فِي الدُّنْيَا وَالْآخِرَةِ"),
        ("دعاء التوكل", "حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ"),
        ("دعاء الاستغفار", "أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ الَّذِي لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ وَأَتُوبُ إِلَيْهِ"),
        ("دعاء الثبات", "اللَّهُمَّ يَا مُقَلِّبَ الْقُلُوبِ ثَبِّتْ قَلْبِي عَلَى دِينِكَ"),
        ("دعاء الستر", "اللَّهُمَّ اسْتُرْ عَوْرَاتِي، وَآمِنْ رَوْعَاتِي"),
        ("دعاء الصلاح", "رَبَّنَا هَبْ لَنَا مِنْ أَزْوَاجِنَا وَذُرِّيَّاتِنَا قُرَّةَ أَعْيُنٍ"),
        ("دعاء الخير", "اللَّهُمَّ إِنِّي أَسْأَلُكَ مِنْ خَيْرِ مَا سَأَلَكَ مِنْهُ نَبِيُّكَ مُحَمَّدٌ"),
        ("دعاء الجنة", "اللَّهُمَّ إِنِّي أَسْأَلُكَ الْجَنَّةَ وَمَا قَرَّبَ إِلَيْهَا مِنْ قَوْلٍ أَوْ عَمَلٍ"),
        ("دعاء النور", "اللَّهُمَّ اجْعَلْ فِي قَلْبِي نُورًا، وَفِي بَصَرِي نُورًا، وَفِي سَمْعِي نُورًا"),
        ("دعاء الفرج", "اللَّهُمَّ لَا سَهْلَ إِلَّا مَا جَعَلْتَهُ سَهْلًا، وَأَنْتَ تَجْعَلُ الْحَزْنَ إِذَا شِئْتَ سَهْلًا"),
        ("دعاء البركة", "اللَّهُمَّ بَارِكْ لَنَا فِي أَسْمَاعِنَا وَأَبْصَارِنَا وَقُلُوبِنَا وَأَزْوَاجِنَا وَذُرِّيَّاتِنَا"),
        ("دعاء الخاتمة", "اللَّهُمَّ اخْتِمْ لَنَا بِخَيْرٍ، وَاجْعَلْ آخِرَ كَلَامِنَا لَا إِلَهَ إِلَّا اللَّهُ"),
        ("دعاء التوبة", "اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ خَلَقْتَنِي وَأَنَا عَبْدُكَ"),
        ("دعاء الكرب", "لَا إِلَهَ إِلَّا اللَّهُ الْعَظِيمُ الْحَلِيمُ، لَا إِلَهَ إِلَّا اللَّهُ رَبُّ الْعَرْشِ الْعَظِيمِ"),
        ("دعاء الصبر", "اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَالْعَجْزِ وَالْكَسَلِ"),
        ("دعاء القوة", "اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْجُبْنِ، وَأَعُوذُ بِكَ مِنَ الْبُخْلِ"),
        ("دعاء الصحة", "اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي"),
        ("دعاء المغفرة", "رَبِّ اغْفِرْ لِي خَطِيئَتِي وَجَهْلِي وَإِسْرَافِي فِي أَمْرِي"),
        ("دعاء الرحمة", "اللَّهُمَّ ارْحَمْنِي بِتَرْكِ الْمَعَاصِي أَبَدًا مَا أَبْقَيْتَنِي"),
        ("دعاء السعادة", "اللَّهُمَّ اجْعَلْنِي أَخْشَاكَ حَتَّى كَأَنِّي أَرَاكَ"),
        ("دعاء الحماية", "بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ"),
        ("دعاء العلم", "رَبِّ زِدْنِي عِلْمًا"),
        ("دعاء اليقين", "اللَّهُمَّ اقْسِمْ لَنَا مِنْ خَشْيَتِكَ مَا يَحُولُ بَيْنَنَا وَبَيْنَ مَعَاصِيكَ"),
        ("دعاء الإخلاص", "اللَّهُمَّ اجْعَلْ عَمَلِي كُلَّهُ صَالِحًا، وَاجْعَلْهُ لِوَجْهِكَ خَالِصًا"),
        ("دعاء القبول", "رَبَّنَا تَقَبَّلْ مِنَّا إِنَّكَ أَنْتَ السَّمِيعُ الْعَلِيمُ")
    ]
    
    override init() {
        super.init()
        loadPersistedSettings()
        // تعيين delegate للتعامل مع الإشعارات في المقدمة
        UNUserNotificationCenter.current().delegate = self
        // تسجيل فئات الإشعارات مع الأصوات المخصصة
        registerNotificationCategories()
    }
    
    // MARK: - Persistence
    
    private let settingsDefaults = UserDefaults.standard
    private let keyPreAdhan = "NotificationService.preAdhanMinutes"
    private let keyAdhanOffset = "NotificationService.adhanOffsetMinutes"
    private let keyIqamaDelay = "NotificationService.iqamaDelayMinutes"
    
    private func loadPersistedSettings() {
        let pre = settingsDefaults.object(forKey: keyPreAdhan) as? Int
        let offset = settingsDefaults.object(forKey: keyAdhanOffset) as? Int
        let iqama = settingsDefaults.object(forKey: keyIqamaDelay) as? Int
        
        if let pre { preAdhanMinutes = pre }
        if let offset { adhanOffsetMinutes = offset }
        if let iqama { iqamaDelayMinutes = iqama }
    }
    
    private func persistSettings() {
        settingsDefaults.set(preAdhanMinutes, forKey: keyPreAdhan)
        settingsDefaults.set(adhanOffsetMinutes, forKey: keyAdhanOffset)
        settingsDefaults.set(iqamaDelayMinutes, forKey: keyIqamaDelay)
    }
    
    // MARK: - تسجيل فئات الإشعارات
    
    private func registerNotificationCategories() {
        let adhanCategory = UNNotificationCategory(
            identifier: "PRAYER_ADHAN",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        let iqamaCategory = UNNotificationCategory(
            identifier: "PRAYER_IQAMA",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        let preCategory = UNNotificationCategory(
            identifier: "PRAYER_PRE",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        let sunriseCategory = UNNotificationCategory(
            identifier: "SUNRISE_DUA",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        let dailyDuaCategory = UNNotificationCategory(
            identifier: "DAILY_DUA",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        let ishaReminderCategory = UNNotificationCategory(
            identifier: "ISHA_REMINDER",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        let wuduReminderCategory = UNNotificationCategory(
            identifier: "WUDU_REMINDER",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([
            adhanCategory, iqamaCategory, preCategory, sunriseCategory, dailyDuaCategory,
            ishaReminderCategory, wuduReminderCategory
        ])
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // عرض الإشعارات حتى لو التطبيق في المقدمة
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let categoryId = notification.request.content.categoryIdentifier
        
        // تشغيل الصوت المخصص عند الإشعار في المقدمة
        if categoryId == "PRAYER_ADHAN" {
            playSound(named: "adhan")
        } else if categoryId == "PRAYER_IQAMA" {
            playSound(named: "iqama")
        }
        
        // عرض الإشعار مع صوت وبانر حتى لو التطبيق مفتوح
        completionHandler([.banner, .sound, .badge, .list])
    }
    
    // معالجة الضغط على الإشعار
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // يمكن إضافة منطق هنا لفتح صفحة معينة
        completionHandler()
    }
    
    func requestPermissions() {
        // Critical Alerts تحتاج entitlement خاص من Apple؛ لا نطلبها لتجنب مشاكل الأذونات/الرفض.
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                if granted {
                    self?.notificationStatus = "✅ تم منح إذن الإشعارات"
                    print("✅ تم منح إذن الإشعارات")
                } else if let error = error {
                    self?.notificationStatus = "❌ خطأ: \(error.localizedDescription)"
                    print("❌ خطأ في إذن الإشعارات: \(error.localizedDescription)")
                } else {
                    self?.notificationStatus = "⚠️ لم يتم منح الإذن"
                    print("⚠️ لم يتم منح إذن الإشعارات")
                }
            }
        }
    }
    
    /// التحقق من حالة الإذن
    func checkPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized:
                    self?.notificationStatus = "✅ الإشعارات مفعّلة"
                case .denied:
                    self?.notificationStatus = "❌ الإشعارات مرفوضة - فعّلها من الإعدادات"
                case .notDetermined:
                    self?.notificationStatus = "⚠️ لم يتم طلب الإذن بعد"
                case .provisional:
                    self?.notificationStatus = "⚡ إشعارات مؤقتة"
                case .ephemeral:
                    self?.notificationStatus = "📱 إشعارات App Clip"
                @unknown default:
                    self?.notificationStatus = "❓ حالة غير معروفة"
                }
            }
        }
    }

    /// جدولة إشعارات الأذان - إشعاران: قبل 10 دقائق + وقت الأذان
    func scheduleAdhan(for prayer: Prayer) {
        let center = UNUserNotificationCenter.current()
        
        // إلغاء الإشعارات السابقة لهذه الصلاة
        center.removePendingNotificationRequests(withIdentifiers: [
            "prayer-pre-\(prayer.id)",
            "prayer-\(prayer.id)",
            "prayer-iqama-\(prayer.id)"
        ])
        
        guard isAdhanEnabled else { return }
        // ⚠️ التحقق إذا كانت الشروق - لا يوجد لها أذان
        let isSunrise = prayer.name.lowercased() == "sunrise"
        
        if isSunrise {
            // إشعار الشروق: تنبيه مع دعاء صباحي فقط (بدون أذان)
            scheduleSunriseNotification(for: prayer)
            return
        }
        
        // ⚠️ ملاحظة مهمة:
        // أوقات الصلاة تتغير يومياً، لذلك لا نستخدم repeats=true على (ساعة/دقيقة) لأنه سيجعل الإشعار يكرر وقتاً ثابتاً كل يوم.
        // نعتمد على triggers غير متكررة، وإعادة الجدولة عند تحديث اليوم.
        
        let dayKey = dayKey(for: prayer.time)
        
        // 1️⃣ إشعار قبل الأذان
        if let preTime = Calendar.current.date(byAdding: .minute, value: -preAdhanMinutes, to: prayer.time) {
            let preContent = UNMutableNotificationContent()
            preContent.title = "⏰ يقترب وقت \(prayer.arabicName)"
            preContent.body = "باقي \(preAdhanMinutes) دقائق على أذان \(prayer.arabicName)"
            preContent.sound = .default
            preContent.interruptionLevel = .timeSensitive
            preContent.categoryIdentifier = "PRAYER_PRE"
            
            let preComps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: preTime)
            let preTrigger = UNCalendarNotificationTrigger(dateMatching: preComps, repeats: false)
            let preRequest = UNNotificationRequest(identifier: "prayer-pre-\(prayer.id)-\(dayKey)", content: preContent, trigger: preTrigger)
            center.add(preRequest) { error in
                if let error = error {
                    print("❌ خطأ في جدولة إشعار قبل الأذان: \(error)")
                }
            }
        }
        
        // 2️⃣ إشعار وقت الأذان مع صوت الأذان
        let adhanContent = UNMutableNotificationContent()
        adhanContent.title = "🕌 حان وقت \(prayer.arabicName)"
        adhanContent.body = "الله أكبر الله أكبر، أشهد أن لا إله إلا الله"
        // استخدام صوت الأذان - محاولة mp3 أولاً ثم caf
        if Bundle.main.url(forResource: "adhan", withExtension: "mp3") != nil {
            adhanContent.sound = UNNotificationSound(named: UNNotificationSoundName("adhan.mp3"))
        } else if Bundle.main.url(forResource: "adhan", withExtension: "caf") != nil {
            adhanContent.sound = UNNotificationSound(named: UNNotificationSoundName("adhan.caf"))
        } else {
            adhanContent.sound = .default
        }
        adhanContent.interruptionLevel = .timeSensitive
        adhanContent.categoryIdentifier = "PRAYER_ADHAN"
        
        let adhanTime = Calendar.current.date(byAdding: .minute, value: adhanOffsetMinutes, to: prayer.time) ?? prayer.time
        let adhanComps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: adhanTime)
        let adhanTrigger = UNCalendarNotificationTrigger(dateMatching: adhanComps, repeats: false)
        let adhanRequest = UNNotificationRequest(identifier: "prayer-\(prayer.id)-\(dayKey)", content: adhanContent, trigger: adhanTrigger)
        center.add(adhanRequest) { error in
            if let error = error {
                print("❌ خطأ في جدولة إشعار الأذان: \(error)")
            }
        }
        
        // 3️⃣ إشعار الإقامة بعد الأذان (اختياري)
        if isIqamaEnabled, let iqamaTime = Calendar.current.date(byAdding: .minute, value: iqamaDelayMinutes, to: prayer.time) {
            let iqamaContent = UNMutableNotificationContent()
            iqamaContent.title = "🕋 قد قامت الصلاة - \(prayer.arabicName)"
            iqamaContent.body = "حيّ على الصلاة، حيّ على الفلاح"
            // استخدام صوت الإقامة - محاولة mp3 أولاً ثم caf
            if Bundle.main.url(forResource: "iqama", withExtension: "mp3") != nil {
                iqamaContent.sound = UNNotificationSound(named: UNNotificationSoundName("iqama.mp3"))
            } else if Bundle.main.url(forResource: "iqama", withExtension: "caf") != nil {
                iqamaContent.sound = UNNotificationSound(named: UNNotificationSoundName("iqama.caf"))
            } else {
                iqamaContent.sound = .default
            }
            iqamaContent.interruptionLevel = .timeSensitive
            iqamaContent.categoryIdentifier = "PRAYER_IQAMA"
            
            let iqamaComps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: iqamaTime)
            let iqamaTrigger = UNCalendarNotificationTrigger(dateMatching: iqamaComps, repeats: false)
            let iqamaRequest = UNNotificationRequest(identifier: "prayer-iqama-\(prayer.id)-\(dayKey)", content: iqamaContent, trigger: iqamaTrigger)
            center.add(iqamaRequest) { error in
                if let error = error {
                    print("❌ خطأ في جدولة إشعار الإقامة: \(error)")
                }
            }
        }
    }
    
    /// إشعار الشروق - تنبيه مع دعاء صباحي فقط (بدون أذان)
    private func scheduleSunriseNotification(for prayer: Prayer) {
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = "🌅 وقت الشروق"
        
        // اختيار دعاء صباحي عشوائي
        let morningDuas = [
            "اللَّهُمَّ بِكَ أَصْبَحْنَا، وَبِكَ أَمْسَيْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ",
            "أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ رَبِّ الْعَالَمِينَ",
            "اللَّهُمَّ إِنِّي أَسْأَلُكَ خَيْرَ هَذَا الْيَوْمِ وَخَيْرَ مَا فِيهِ",
            "اللَّهُمَّ مَا أَصْبَحَ بِي مِنْ نِعْمَةٍ فَمِنْكَ وَحْدَكَ لَا شَرِيكَ لَكَ"
        ]
        
        let randomDua = morningDuas.randomElement() ?? morningDuas[0]
        content.body = randomDua
        content.sound = .default // صوت تنبيه عادي
        content.interruptionLevel = .active
        content.categoryIdentifier = "SUNRISE_DUA"
        
        let dayKey = dayKey(for: prayer.time)
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: prayer.time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: "prayer-\(prayer.id)-\(dayKey)", content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("❌ خطأ في جدولة إشعار الشروق: \(error)")
            }
        }
    }
    
    /// جدولة جميع صلوات اليوم
    func scheduleAllPrayers(_ prayers: [Prayer]) {
        for prayer in prayers {
            scheduleAdhan(for: prayer)
            
            // تذكير الوضوء قبل كل صلاة بـ 5 دقائق
            if isWuduReminderEnabled {
                scheduleWuduReminder(for: prayer)
            }
        }
        
        // تذكير العشاء قبل منتصف الليل
        if isIshaReminderEnabled {
            if let ishaPrayer = prayers.first(where: { $0.name.lowercased() == "isha" }) {
                scheduleIshaReminder(for: ishaPrayer)
            }
        }
    }
    
    /// تذكير الوضوء قبل الصلاة بـ 5 دقائق
    private func scheduleWuduReminder(for prayer: Prayer) {
        let center = UNUserNotificationCenter.current()
        
        // تجاهل الشروق
        let isSunrise = prayer.name.lowercased() == "sunrise"
        if isSunrise { return }
        
        // إلغاء التذكير السابق
        let dayKey = dayKey(for: prayer.time)
        
        // تذكير قبل 5 دقائق من الأذان
        if let wuduTime = Calendar.current.date(byAdding: .minute, value: -5, to: prayer.time) {
            let content = UNMutableNotificationContent()
            content.title = "💧 تذكير الوضوء"
            content.body = "اقترب وقت صلاة \(prayer.arabicName)، تذكّر الوضوء والاستعداد للصلاة 🔕 وتحويل الجوال للصامت"
            content.sound = .default
            content.interruptionLevel = .active
            content.categoryIdentifier = "WUDU_REMINDER"
            
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: wuduTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: "wudu-\(prayer.id)-\(dayKey)", content: content, trigger: trigger)
            
            center.add(request) { error in
                if let error = error {
                    print("❌ خطأ في جدولة تذكير الوضوء: \(error)")
                }
            }
        }
    }
    
    /// تذكير صلاة العشاء قبل منتصف الليل
    private func scheduleIshaReminder(for ishaPrayer: Prayer) {
        let center = UNUserNotificationCenter.current()
        
        // تذكير غير متكرر (لليوم فقط) — يعاد جدولته عند تحديث اليوم
        let dayKey = dayKey(for: ishaPrayer.time)
        var reminderComps = Calendar.current.dateComponents([.year, .month, .day], from: ishaPrayer.time)
        reminderComps.hour = 23
        reminderComps.minute = 30
        
        let content = UNMutableNotificationContent()
        content.title = "⚠️ تذكير صلاة العشاء"
        content.body = "ينتهي وقت صلاة العشاء عند منتصف الليل، بادر بالصلاة إن لم تصلِّ"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = "ISHA_REMINDER"
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: reminderComps, repeats: false)
        let request = UNNotificationRequest(identifier: "isha-midnight-reminder-\(dayKey)", content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("❌ خطأ في جدولة تذكير العشاء: \(error)")
            }
        }
    }
    
    /// جدولة دعاء يومي مختلف كل يوم
    func scheduleDailyDua(hour: Int = 8, minute: Int = 0) {
        guard isDailyDuaEnabled else { return }
        
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily-dua"])
        
        // اختيار دعاء بناءً على اليوم في السنة
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let duaIndex = dayOfYear % NotificationService.dailyDuas.count
        let dua = NotificationService.dailyDuas[duaIndex]
        
        let content = UNMutableNotificationContent()
        content.title = "🤲 \(dua.title)"
        content.body = dua.dua
        content.sound = .default
        content.interruptionLevel = .active
        content.categoryIdentifier = "DAILY_DUA"
        
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-dua", content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("❌ خطأ في جدولة الدعاء اليومي: \(error)")
            }
        }
    }

    func scheduleAzkarReminder(hour: Int, minute: Int, category: AzkarCategory) {
        let content = UNMutableNotificationContent()
        content.title = category == .morning ? "☀️ أذكار الصباح" : "🌙 أذكار المساء"
        content.body = category == .morning ? "ابدأ يومك بذكر الله" : "اختم يومك بذكر الله"
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: "azkar-\(category.rawValue)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Helpers
    
    private func dayKey(for date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyyMMdd"
        return f.string(from: date)
    }
    
    /// إلغاء إشعارات الصلاة فقط (بدون المساس بأذكار/دعاء يومي).
    func cancelPrayerNotificationsOnly() {
        let prefixes = ["prayer-pre-", "prayer-", "prayer-iqama-", "wudu-", "isha-midnight-reminder-"]
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter { id in prefixes.contains(where: { id.hasPrefix($0) }) }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }
    
    /// إلغاء جميع الإشعارات
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    /// عرض الإشعارات المجدولة
    func getPendingNotifications(completion: @escaping ([UNNotificationRequest]) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            completion(requests)
        }
    }
    
    // MARK: - وضع التجربة للمطور
    
    /// تشغيل صوت الأذان للتجربة
    func playAdhanForTesting() {
        playSound(named: "adhan")
    }
    
    /// تشغيل صوت الإقامة للتجربة
    func playIqamaForTesting() {
        playSound(named: "iqama")
    }
    
    /// إيقاف الصوت
    func stopSound() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    func playSound(named name: String) {
        // محاولة تحميل الصوت من الموارد
        if let url = Bundle.main.url(forResource: name, withExtension: "mp3") ??
                     Bundle.main.url(forResource: name, withExtension: "caf") ??
                     Bundle.main.url(forResource: name, withExtension: "m4a") {
            do {
                // إعداد جلسة الصوت للتشغيل في الخلفية
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
                try AVAudioSession.sharedInstance().setActive(true)
                
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
                print("✅ تم تشغيل الصوت: \(name)")
            } catch {
                print("❌ خطأ في تشغيل الصوت: \(error.localizedDescription)")
                // تشغيل صوت النظام كبديل
                AudioServicesPlaySystemSound(1007)
            }
        } else {
            print("⚠️ ملف الصوت غير موجود: \(name)")
            // تشغيل صوت النظام كبديل
            AudioServicesPlaySystemSound(1007) // صوت تنبيه
        }
    }
    
    /// إرسال إشعار تجريبي فوري - بالعربي بالكامل
    func sendTestNotification(type: TestNotificationType) {
        // التحقق من الإذن أولاً
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            guard settings.authorizationStatus == .authorized else {
                DispatchQueue.main.async {
                    self?.notificationStatus = "❌ يجب تفعيل الإشعارات من الإعدادات أولاً"
                }
                return
            }
            
            let content = UNMutableNotificationContent()
            
            switch type {
            case .preAdhan:
                content.title = "⏰ يقترب وقت الفجر"
                content.body = "باقي ١٠ دقائق على أذان الفجر - استعد للصلاة"
                content.sound = .default
                content.categoryIdentifier = "PRAYER_PRE"
            case .adhan:
                content.title = "🕌 حان وقت الفجر"
                content.body = "الله أكبر الله أكبر، أشهد أن لا إله إلا الله، أشهد أن محمداً رسول الله"
                // سيتم تشغيل الصوت من delegate
                if Bundle.main.url(forResource: "adhan", withExtension: "mp3") != nil {
                    content.sound = UNNotificationSound(named: UNNotificationSoundName("adhan.mp3"))
                } else {
                    content.sound = .default
                }
                content.categoryIdentifier = "PRAYER_ADHAN"
            case .iqama:
                content.title = "🕋 قد قامت الصلاة"
                content.body = "حيّ على الصلاة، حيّ على الفلاح، قد قامت الصلاة"
                if Bundle.main.url(forResource: "iqama", withExtension: "mp3") != nil {
                    content.sound = UNNotificationSound(named: UNNotificationSoundName("iqama.mp3"))
                } else {
                    content.sound = .default
                }
                content.categoryIdentifier = "PRAYER_IQAMA"
            }
            
            content.interruptionLevel = .timeSensitive
            content.badge = 1
            
            // إرسال بعد ثانيتين
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
            let request = UNNotificationRequest(
                identifier: "test-\(type.rawValue)-\(Date().timeIntervalSince1970)",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { [weak self] error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.notificationStatus = "❌ فشل إرسال الإشعار: \(error.localizedDescription)"
                    } else {
                        self?.notificationStatus = "✅ تم إرسال الإشعار - تحقق من مركز الإشعارات"
                        
                        // تشغيل الصوت مباشرة للتجربة
                        if type == .adhan {
                            self?.playSound(named: "adhan")
                        } else if type == .iqama {
                            self?.playSound(named: "iqama")
                        }
                    }
                }
            }
        }
    }
    
    enum TestNotificationType: String {
        case preAdhan = "pre-adhan"
        case adhan = "adhan"
        case iqama = "iqama"
    }
}
