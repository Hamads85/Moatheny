import Foundation

/// Provides azkar data, caching, reminders, and scraping fallback.
final class AzkarService {
    private let api: APIClient
    private let cache: LocalCache
    private let notifications: NotificationService
    private let scraper: WebScraper

    init(api: APIClient, cache: LocalCache, notifications: NotificationService, scraper: WebScraper) {
        self.api = api
        self.cache = cache
        self.notifications = notifications
        self.scraper = scraper
    }

    func loadAzkar() async throws -> [Zikr] {
        // أولاً: تحميل البيانات المحلية الأساسية لضمان وجود أذكار
        let basicAzkar = createBasicAzkar()
        
        // ثانياً: محاولة تحميل من الكاش
        if let cached: [Zikr] = try? cache.load([Zikr].self, named: "azkar.json"), !cached.isEmpty {
            return cached
        }
        
        // ثالثاً: محاولة التحميل من الإنترنت (مع timeout قصير)
        do {
            let azkar = try await withTimeout(seconds: 5) {
                try await self.api.fetchAzkar()
            }
            if !azkar.isEmpty {
            try? cache.store(azkar, named: "azkar.json")
            return azkar
            }
        } catch {
            // تجاهل الأخطاء واستخدم البيانات المحلية
            print("فشل تحميل الأذكار من الإنترنت: \(error.localizedDescription)")
        }
        
        // استخدام البيانات المحلية
        try? cache.store(basicAzkar, named: "azkar.json")
        return basicAzkar
    }
    
    private func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw AppError.network("انتهت مهلة الاتصال")
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    // أذكار أساسية كنسخة احتياطية - مجموعة شاملة ومحسّنة ومُوسّعة
    private func createBasicAzkar() -> [Zikr] {
        [
            // ═══════════════════════════════════════════════════════════
            // أذكار الصباح (20 ذكر)
            // ═══════════════════════════════════════════════════════════
            Zikr(id: 1, category: .morning, arabicText: "أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ", transliteration: nil, translation: "بدأنا يومنا وبدأ الملك لله، والحمد لله", reference: "مسلم", repetitionCount: 1, benefit: "من قالها حُفظ حتى يمسي", audioURL: nil),
            Zikr(id: 2, category: .morning, arabicText: "اللَّهُمَّ بِكَ أَصْبَحْنَا، وَبِكَ أَمْسَيْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ النُّشُورُ", transliteration: nil, translation: "اللهم بك أصبحنا وبك أمسينا", reference: "الترمذي", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 3, category: .morning, arabicText: "أَصْبَحْنَا عَلَى فِطْرَةِ الْإِسْلَامِ، وَعَلَى كَلِمَةِ الْإِخْلَاصِ، وَعَلَى دِينِ نَبِيِّنَا مُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ، وَعَلَى مِلَّةِ أَبِينَا إِبْرَاهِيمَ حَنِيفًا مُسْلِمًا وَمَا كَانَ مِنَ الْمُشْرِكِينَ", transliteration: nil, translation: "أصبحنا على فطرة الإسلام", reference: "أحمد", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 4, category: .morning, arabicText: "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ", transliteration: nil, translation: "سبحان الله وبحمده", reference: "البخاري", repetitionCount: 100, benefit: "حُطت خطاياه وإن كانت مثل زبد البحر", audioURL: nil),
            Zikr(id: 5, category: .morning, arabicText: "لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ", transliteration: nil, translation: "لا إله إلا الله وحده لا شريك له", reference: "البخاري ومسلم", repetitionCount: 10, benefit: "كانت له عدل عشر رقاب، وكُتب له مائة حسنة، ومُحيت عنه مائة سيئة", audioURL: nil),
            Zikr(id: 6, category: .morning, arabicText: "اللَّهُمَّ إِنِّي أَسْأَلُكَ عِلْمًا نَافِعًا، وَرِزْقًا طَيِّبًا، وَعَمَلًا مُتَقَبَّلًا", transliteration: nil, translation: "اللهم إني أسألك علمًا نافعًا", reference: "ابن ماجه", repetitionCount: 1, benefit: "دعاء جامع لخير الدنيا والآخرة", audioURL: nil),
            Zikr(id: 7, category: .morning, arabicText: "اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي، لَا إِلَهَ إِلَّا أَنْتَ", transliteration: nil, translation: "اللهم عافني في بدني", reference: "أبو داود", repetitionCount: 3, benefit: "دعاء الحفظ والعافية", audioURL: nil),
            Zikr(id: 8, category: .morning, arabicText: "بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ", transliteration: nil, translation: "بسم الله الذي لا يضر مع اسمه شيء", reference: "الترمذي", repetitionCount: 3, benefit: "لم يضره شيء ذلك اليوم", audioURL: nil),
            Zikr(id: 9, category: .morning, arabicText: "رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ نَبِيًّا", transliteration: nil, translation: "رضيت بالله ربًا", reference: "أحمد", repetitionCount: 3, benefit: "كان حقًا على الله أن يُرضيه يوم القيامة", audioURL: nil),
            Zikr(id: 10, category: .morning, arabicText: "يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ، أَصْلِحْ لِي شَأْنِي كُلَّهُ، وَلَا تَكِلْنِي إِلَى نَفْسِي طَرْفَةَ عَيْنٍ", transliteration: nil, translation: "يا حي يا قيوم برحمتك أستغيث", reference: "الحاكم", repetitionCount: 1, benefit: "دعاء الاستغاثة بالله", audioURL: nil),
            Zikr(id: 201, category: .morning, arabicText: "اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ", transliteration: nil, translation: "سيد الاستغفار", reference: "البخاري", repetitionCount: 1, benefit: "من قالها موقنًا بها فمات من يومه دخل الجنة", audioURL: nil),
            Zikr(id: 202, category: .morning, arabicText: "اللَّهُمَّ مَا أَصْبَحَ بِي مِنْ نِعْمَةٍ أَوْ بِأَحَدٍ مِنْ خَلْقِكَ فَمِنْكَ وَحْدَكَ لَا شَرِيكَ لَكَ، فَلَكَ الْحَمْدُ وَلَكَ الشُّكْرُ", transliteration: nil, translation: "اللهم ما أصبح بي من نعمة", reference: "أبو داود", repetitionCount: 1, benefit: "أدى شكر يومه", audioURL: nil),
            Zikr(id: 203, category: .morning, arabicText: "حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ", transliteration: nil, translation: "حسبي الله لا إله إلا هو", reference: "أبو داود", repetitionCount: 7, benefit: "كفاه الله ما أهمه من أمر الدنيا والآخرة", audioURL: nil),
            Zikr(id: 204, category: .morning, arabicText: "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ عَدَدَ خَلْقِهِ، وَرِضَا نَفْسِهِ، وَزِنَةَ عَرْشِهِ، وَمِدَادَ كَلِمَاتِهِ", transliteration: nil, translation: "سبحان الله وبحمده عدد خلقه", reference: "مسلم", repetitionCount: 3, benefit: "تعدل أضعاف ما قاله من التسبيح", audioURL: nil),
            Zikr(id: 205, category: .morning, arabicText: "اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَالْعَجْزِ وَالْكَسَلِ، وَالْبُخْلِ وَالْجُبْنِ، وَضَلَعِ الدَّيْنِ وَغَلَبَةِ الرِّجَالِ", transliteration: nil, translation: "اللهم إني أعوذ بك من الهم والحزن", reference: "البخاري", repetitionCount: 1, benefit: "استعاذة من ثمانية أمور", audioURL: nil),
            Zikr(id: 206, category: .morning, arabicText: "اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ", transliteration: nil, translation: "الصلاة على النبي ﷺ", reference: "الترمذي", repetitionCount: 10, benefit: "من صلى علي صلاة صلى الله عليه بها عشرًا", audioURL: nil),
            Zikr(id: 207, category: .morning, arabicText: "أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ", transliteration: nil, translation: "أستغفر الله وأتوب إليه", reference: "البخاري ومسلم", repetitionCount: 100, benefit: "من لازم الاستغفار جعل الله له من كل هم فرجًا", audioURL: nil),
            Zikr(id: 208, category: .morning, arabicText: "قُلْ هُوَ اللَّهُ أَحَدٌ، اللَّهُ الصَّمَدُ، لَمْ يَلِدْ وَلَمْ يُولَدْ، وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ", transliteration: nil, translation: "سورة الإخلاص", reference: "أبو داود والترمذي", repetitionCount: 3, benefit: "تعدل ثلث القرآن", audioURL: nil),
            Zikr(id: 209, category: .morning, arabicText: "قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ، مِن شَرِّ مَا خَلَقَ، وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ، وَمِن شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ، وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ", transliteration: nil, translation: "سورة الفلق", reference: "أبو داود والترمذي", repetitionCount: 3, benefit: "تكفيه من كل شيء", audioURL: nil),
            Zikr(id: 210, category: .morning, arabicText: "قُلْ أَعُوذُ بِرَبِّ النَّاسِ، مَلِكِ النَّاسِ، إِلَٰهِ النَّاسِ، مِن شَرِّ الْوَسْوَاسِ الْخَنَّاسِ، الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ، مِنَ الْجِنَّةِ وَالنَّاسِ", transliteration: nil, translation: "سورة الناس", reference: "أبو داود والترمذي", repetitionCount: 3, benefit: "تكفيه من كل شيء", audioURL: nil),
            
            // ═══════════════════════════════════════════════════════════
            // أذكار المساء (18 ذكر)
            // ═══════════════════════════════════════════════════════════
            Zikr(id: 11, category: .evening, arabicText: "أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ", transliteration: nil, translation: "أمسينا وأمسى الملك لله", reference: "مسلم", repetitionCount: 1, benefit: "من قالها حُفظ حتى يصبح", audioURL: nil),
            Zikr(id: 12, category: .evening, arabicText: "اللَّهُمَّ بِكَ أَمْسَيْنَا، وَبِكَ أَصْبَحْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ الْمَصِيرُ", transliteration: nil, translation: "اللهم بك أمسينا وبك أصبحنا", reference: "الترمذي", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 13, category: .evening, arabicText: "أَمْسَيْنَا عَلَى فِطْرَةِ الْإِسْلَامِ، وَعَلَى كَلِمَةِ الْإِخْلَاصِ، وَعَلَى دِينِ نَبِيِّنَا مُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ", transliteration: nil, translation: "أمسينا على فطرة الإسلام", reference: "أحمد", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 14, category: .evening, arabicText: "اللَّهُمَّ مَا أَمْسَى بِي مِنْ نِعْمَةٍ أَوْ بِأَحَدٍ مِنْ خَلْقِكَ فَمِنْكَ وَحْدَكَ لَا شَرِيكَ لَكَ، فَلَكَ الْحَمْدُ وَلَكَ الشُّكْرُ", transliteration: nil, translation: "اللهم ما أمسى بي من نعمة", reference: "أبو داود", repetitionCount: 1, benefit: "أدى شكر يومه", audioURL: nil),
            Zikr(id: 15, category: .evening, arabicText: "اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْكُفْرِ وَالْفَقْرِ، وَأَعُوذُ بِكَ مِنْ عَذَابِ الْقَبْرِ، لَا إِلَهَ إِلَّا أَنْتَ", transliteration: nil, translation: "اللهم إني أعوذ بك من الكفر والفقر", reference: "أبو داود", repetitionCount: 3, benefit: nil, audioURL: nil),
            Zikr(id: 16, category: .evening, arabicText: "أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ", transliteration: nil, translation: "أعوذ بكلمات الله التامات", reference: "مسلم", repetitionCount: 3, benefit: "لم يضره شيء تلك الليلة", audioURL: nil),
            Zikr(id: 211, category: .evening, arabicText: "اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ", transliteration: nil, translation: "سيد الاستغفار", reference: "البخاري", repetitionCount: 1, benefit: "من قالها موقنًا بها فمات من ليلته دخل الجنة", audioURL: nil),
            Zikr(id: 212, category: .evening, arabicText: "حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ", transliteration: nil, translation: "حسبي الله لا إله إلا هو", reference: "أبو داود", repetitionCount: 7, benefit: "كفاه الله ما أهمه", audioURL: nil),
            Zikr(id: 213, category: .evening, arabicText: "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ", transliteration: nil, translation: "سبحان الله وبحمده", reference: "البخاري ومسلم", repetitionCount: 100, benefit: "حُطت خطاياه وإن كانت مثل زبد البحر", audioURL: nil),
            Zikr(id: 214, category: .evening, arabicText: "لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ", transliteration: nil, translation: "لا إله إلا الله وحده", reference: "البخاري ومسلم", repetitionCount: 10, benefit: "كانت له عدل عشر رقاب", audioURL: nil),
            Zikr(id: 215, category: .evening, arabicText: "يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ، أَصْلِحْ لِي شَأْنِي كُلَّهُ، وَلَا تَكِلْنِي إِلَى نَفْسِي طَرْفَةَ عَيْنٍ", transliteration: nil, translation: "يا حي يا قيوم برحمتك أستغيث", reference: "الحاكم", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 216, category: .evening, arabicText: "اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ", transliteration: nil, translation: "الصلاة على النبي ﷺ", reference: "الترمذي", repetitionCount: 10, benefit: "من صلى علي صلاة صلى الله عليه بها عشرًا", audioURL: nil),
            Zikr(id: 217, category: .evening, arabicText: "أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ", transliteration: nil, translation: "أستغفر الله وأتوب إليه", reference: "البخاري ومسلم", repetitionCount: 100, benefit: "من لازم الاستغفار جعل الله له من كل هم فرجًا", audioURL: nil),
            Zikr(id: 218, category: .evening, arabicText: "قُلْ هُوَ اللَّهُ أَحَدٌ، اللَّهُ الصَّمَدُ، لَمْ يَلِدْ وَلَمْ يُولَدْ، وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ", transliteration: nil, translation: "سورة الإخلاص", reference: "أبو داود والترمذي", repetitionCount: 3, benefit: "تعدل ثلث القرآن", audioURL: nil),
            Zikr(id: 219, category: .evening, arabicText: "قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ، مِن شَرِّ مَا خَلَقَ، وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ، وَمِن شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ، وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ", transliteration: nil, translation: "سورة الفلق", reference: "أبو داود والترمذي", repetitionCount: 3, benefit: "تكفيه من كل شيء", audioURL: nil),
            Zikr(id: 220, category: .evening, arabicText: "قُلْ أَعُوذُ بِرَبِّ النَّاسِ، مَلِكِ النَّاسِ، إِلَٰهِ النَّاسِ، مِن شَرِّ الْوَسْوَاسِ الْخَنَّاسِ، الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ، مِنَ الْجِنَّةِ وَالنَّاسِ", transliteration: nil, translation: "سورة الناس", reference: "أبو داود والترمذي", repetitionCount: 3, benefit: "تكفيه من كل شيء", audioURL: nil),
            Zikr(id: 221, category: .evening, arabicText: "اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ ٱلْحَيُّ ٱلْقَيُّومُ ۚ لَا تَأْخُذُهُۥ سِنَةٌ وَلَا نَوْمٌ ۚ لَّهُۥ مَا فِى ٱلسَّمَٰوَٰتِ وَمَا فِى ٱلْأَرْضِ ۗ مَن ذَا ٱلَّذِى يَشْفَعُ عِندَهُۥٓ إِلَّا بِإِذْنِهِۦ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَىْءٍ مِّنْ عِلْمِهِۦٓ إِلَّا بِمَا شَآءَ ۚ وَسِعَ كُرْسِيُّهُ ٱلسَّمَٰوَٰتِ وَٱلْأَرْضَ ۖ وَلَا يَـُٔودُهُۥ حِفْظُهُمَا ۚ وَهُوَ ٱلْعَلِىُّ ٱلْعَظِيمُ", transliteration: nil, translation: "آية الكرسي", reference: "البخاري", repetitionCount: 1, benefit: "لم يزل عليه حافظ من الله ولا يقربه شيطان حتى يصبح", audioURL: nil),
            Zikr(id: 222, category: .evening, arabicText: "رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ نَبِيًّا", transliteration: nil, translation: "رضيت بالله ربًا", reference: "أحمد", repetitionCount: 3, benefit: "كان حقًا على الله أن يُرضيه يوم القيامة", audioURL: nil),
            
            // ═══════════════════════════════════════════════════════════
            // أذكار بعد الصلاة (15 ذكر)
            // ═══════════════════════════════════════════════════════════
            Zikr(id: 21, category: .afterPrayer, arabicText: "أَسْتَغْفِرُ اللَّهَ، أَسْتَغْفِرُ اللَّهَ، أَسْتَغْفِرُ اللَّهَ", transliteration: nil, translation: "أستغفر الله ثلاثًا", reference: "مسلم", repetitionCount: 3, benefit: nil, audioURL: nil),
            Zikr(id: 22, category: .afterPrayer, arabicText: "اللَّهُمَّ أَنْتَ السَّلَامُ وَمِنْكَ السَّلَامُ، تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ", transliteration: nil, translation: "اللهم أنت السلام ومنك السلام", reference: "مسلم", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 23, category: .afterPrayer, arabicText: "سُبْحَانَ اللَّهِ", transliteration: nil, translation: "سبحان الله", reference: "متفق عليه", repetitionCount: 33, benefit: nil, audioURL: nil),
            Zikr(id: 24, category: .afterPrayer, arabicText: "الْحَمْدُ لِلَّهِ", transliteration: nil, translation: "الحمد لله", reference: "متفق عليه", repetitionCount: 33, benefit: nil, audioURL: nil),
            Zikr(id: 25, category: .afterPrayer, arabicText: "اللَّهُ أَكْبَرُ", transliteration: nil, translation: "الله أكبر", reference: "متفق عليه", repetitionCount: 34, benefit: nil, audioURL: nil),
            Zikr(id: 26, category: .afterPrayer, arabicText: "لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ", transliteration: nil, translation: "لا إله إلا الله وحده لا شريك له", reference: "متفق عليه", repetitionCount: 1, benefit: "تُحطّ خطاياه ولو كانت مثل زبد البحر", audioURL: nil),
            Zikr(id: 27, category: .afterPrayer, arabicText: "لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ", transliteration: nil, translation: "لا حول ولا قوة إلا بالله", reference: "البخاري ومسلم", repetitionCount: 1, benefit: "كنز من كنوز الجنة", audioURL: nil),
            Zikr(id: 28, category: .afterPrayer, arabicText: "اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ", transliteration: nil, translation: "اللهم أعني على ذكرك وشكرك", reference: "أبو داود", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 301, category: .afterPrayer, arabicText: "لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، يُحْيِي وَيُمِيتُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ", transliteration: nil, translation: "بعد صلاتي الفجر والمغرب", reference: "الترمذي", repetitionCount: 10, benefit: "كُتب له عشر حسنات ومُحي عنه عشر سيئات", audioURL: nil),
            Zikr(id: 302, category: .afterPrayer, arabicText: "اللَّهُمَّ إِنِّي أَسْأَلُكَ الْجَنَّةَ وَأَعُوذُ بِكَ مِنَ النَّارِ", transliteration: nil, translation: "اللهم إني أسألك الجنة", reference: "أبو داود", repetitionCount: 3, benefit: "من سأل الله الجنة ثلاث مرات قالت الجنة: اللهم أدخله الجنة", audioURL: nil),
            Zikr(id: 303, category: .afterPrayer, arabicText: "اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْجُبْنِ، وَأَعُوذُ بِكَ مِنَ الْبُخْلِ، وَأَعُوذُ بِكَ مِنْ أَنْ أُرَدَّ إِلَى أَرْذَلِ الْعُمُرِ، وَأَعُوذُ بِكَ مِنْ فِتْنَةِ الدُّنْيَا وَعَذَابِ الْقَبْرِ", transliteration: nil, translation: "اللهم إني أعوذ بك من الجبن", reference: "البخاري", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 304, category: .afterPrayer, arabicText: "اللَّهُمَّ اغْفِرْ لِي ذَنْبِي وَوَسِّعْ لِي فِي دَارِي وَبَارِكْ لِي فِي رِزْقِي", transliteration: nil, translation: "اللهم اغفر لي ذنبي ووسع لي في داري", reference: "الترمذي", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 305, category: .afterPrayer, arabicText: "اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ ٱلْحَيُّ ٱلْقَيُّومُ ۚ لَا تَأْخُذُهُۥ سِنَةٌ وَلَا نَوْمٌ", transliteration: nil, translation: "آية الكرسي بعد كل صلاة", reference: "النسائي", repetitionCount: 1, benefit: "لم يمنعه من دخول الجنة إلا أن يموت", audioURL: nil),
            Zikr(id: 306, category: .afterPrayer, arabicText: "سُبْحَانَ اللَّهِ وَالْحَمْدُ لِلَّهِ وَاللَّهُ أَكْبَرُ", transliteration: nil, translation: "التسبيح بعد الصلاة", reference: "مسلم", repetitionCount: 33, benefit: "من سبّح دبر كل صلاة ثلاثًا وثلاثين وحمد ثلاثًا وثلاثين وكبّر ثلاثًا وثلاثين", audioURL: nil),
            Zikr(id: 307, category: .afterPrayer, arabicText: "اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ", transliteration: nil, translation: "الصلاة على النبي ﷺ", reference: "متفق عليه", repetitionCount: 10, benefit: "من صلى علي صلاة صلى الله عليه بها عشرًا", audioURL: nil),
            
            // ═══════════════════════════════════════════════════════════
            // أذكار النوم (12 ذكر)
            // ═══════════════════════════════════════════════════════════
            Zikr(id: 31, category: .sleep, arabicText: "بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا", transliteration: nil, translation: "باسمك اللهم أموت وأحيا", reference: "البخاري", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 32, category: .sleep, arabicText: "اللَّهُمَّ قِنِي عَذَابَكَ يَوْمَ تَبْعَثُ عِبَادَكَ", transliteration: nil, translation: "اللهم قني عذابك يوم تبعث عبادك", reference: "أبو داود", repetitionCount: 3, benefit: nil, audioURL: nil),
            Zikr(id: 33, category: .sleep, arabicText: "بِاسْمِكَ رَبِّي وَضَعْتُ جَنْبِي، وَبِكَ أَرْفَعُهُ، فَإِنْ أَمْسَكْتَ نَفْسِي فَارْحَمْهَا، وَإِنْ أَرْسَلْتَهَا فَاحْفَظْهَا بِمَا تَحْفَظُ بِهِ عِبَادَكَ الصَّالِحِينَ", transliteration: nil, translation: "باسمك ربي وضعت جنبي", reference: "البخاري ومسلم", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 34, category: .sleep, arabicText: "اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ ٱلْحَيُّ ٱلْقَيُّومُ ۚ لَا تَأْخُذُهُۥ سِنَةٌ وَلَا نَوْمٌ ۚ لَّهُۥ مَا فِى ٱلسَّمَٰوَٰتِ وَمَا فِى ٱلْأَرْضِ ۗ مَن ذَا ٱلَّذِى يَشْفَعُ عِندَهُۥٓ إِلَّا بِإِذْنِهِۦ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَىْءٍ مِّنْ عِلْمِهِۦٓ إِلَّا بِمَا شَآءَ ۚ وَسِعَ كُرْسِيُّهُ ٱلسَّمَٰوَٰتِ وَٱلْأَرْضَ ۖ وَلَا يَـُٔودُهُۥ حِفْظُهُمَا ۚ وَهُوَ ٱلْعَلِىُّ ٱلْعَظِيمُ", transliteration: nil, translation: "آية الكرسي", reference: "البخاري", repetitionCount: 1, benefit: "لم يزل عليه حافظ من الله ولا يقربه شيطان حتى يصبح", audioURL: nil),
            Zikr(id: 35, category: .sleep, arabicText: "قُلْ هُوَ اللَّهُ أَحَدٌ، وقُلْ أَعُوذُ بِرَبِّ الْفَلَقِ، وقُلْ أَعُوذُ بِرَبِّ النَّاسِ", transliteration: nil, translation: "المعوذات (الإخلاص والفلق والناس)", reference: "الترمذي", repetitionCount: 3, benefit: "تكفيه من كل شيء", audioURL: nil),
            Zikr(id: 36, category: .sleep, arabicText: "اللَّهُمَّ أَسْلَمْتُ نَفْسِي إِلَيْكَ، وَفَوَّضْتُ أَمْرِي إِلَيْكَ، وَوَجَّهْتُ وَجْهِي إِلَيْكَ، وَأَلْجَأْتُ ظَهْرِي إِلَيْكَ، رَغْبَةً وَرَهْبَةً إِلَيْكَ، لَا مَلْجَأَ وَلَا مَنْجَا مِنْكَ إِلَّا إِلَيْكَ، آمَنْتُ بِكِتَابِكَ الَّذِي أَنْزَلْتَ، وَبِنَبِيِّكَ الَّذِي أَرْسَلْتَ", transliteration: nil, translation: "اللهم أسلمت نفسي إليك", reference: "البخاري ومسلم", repetitionCount: 1, benefit: "من مات على ذلك مات على الفطرة", audioURL: nil),
            Zikr(id: 311, category: .sleep, arabicText: "الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنَا وَسَقَانَا وَكَفَانَا وَآوَانَا، فَكَمْ مِمَّنْ لَا كَافِيَ لَهُ وَلَا مُؤْوِيَ", transliteration: nil, translation: "الحمد لله الذي أطعمنا وسقانا", reference: "مسلم", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 312, category: .sleep, arabicText: "اللَّهُمَّ عَالِمَ الْغَيْبِ وَالشَّهَادَةِ فَاطِرَ السَّمَاوَاتِ وَالْأَرْضِ، رَبَّ كُلِّ شَيْءٍ وَمَلِيكَهُ، أَشْهَدُ أَنْ لَا إِلَهَ إِلَّا أَنْتَ، أَعُوذُ بِكَ مِنْ شَرِّ نَفْسِي، وَمِنْ شَرِّ الشَّيْطَانِ وَشِرْكِهِ", transliteration: nil, translation: "اللهم عالم الغيب والشهادة", reference: "الترمذي", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 313, category: .sleep, arabicText: "سُبْحَانَ اللَّهِ", transliteration: nil, translation: "سبحان الله (33 مرة)", reference: "متفق عليه", repetitionCount: 33, benefit: "تسبيحات فاطمة رضي الله عنها قبل النوم", audioURL: nil),
            Zikr(id: 314, category: .sleep, arabicText: "الْحَمْدُ لِلَّهِ", transliteration: nil, translation: "الحمد لله (33 مرة)", reference: "متفق عليه", repetitionCount: 33, benefit: "تسبيحات فاطمة رضي الله عنها قبل النوم", audioURL: nil),
            Zikr(id: 315, category: .sleep, arabicText: "اللَّهُ أَكْبَرُ", transliteration: nil, translation: "الله أكبر (34 مرة)", reference: "متفق عليه", repetitionCount: 34, benefit: "تسبيحات فاطمة رضي الله عنها قبل النوم", audioURL: nil),
            Zikr(id: 316, category: .sleep, arabicText: "اللَّهُمَّ رَبَّ السَّمَاوَاتِ السَّبْعِ وَرَبَّ الْعَرْشِ الْعَظِيمِ، رَبَّنَا وَرَبَّ كُلِّ شَيْءٍ، فَالِقَ الْحَبِّ وَالنَّوَى، مُنْزِلَ التَّوْرَاةِ وَالْإِنْجِيلِ وَالْقُرْآنِ، أَعُوذُ بِكَ مِنْ شَرِّ كُلِّ ذِي شَرٍّ أَنْتَ آخِذٌ بِنَاصِيَتِهِ", transliteration: nil, translation: "اللهم رب السماوات السبع", reference: "الترمذي", repetitionCount: 1, benefit: nil, audioURL: nil),
            
            // ═══════════════════════════════════════════════════════════
            // أذكار الاستيقاظ (8 ذكر)
            // ═══════════════════════════════════════════════════════════
            Zikr(id: 41, category: .wakeUp, arabicText: "الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا، وَإِلَيْهِ النُّشُورُ", transliteration: nil, translation: "الحمد لله الذي أحيانا بعد ما أماتنا", reference: "البخاري", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 42, category: .wakeUp, arabicText: "لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ. سُبْحَانَ اللَّهِ، وَالْحَمْدُ لِلَّهِ، وَلَا إِلَهَ إِلَّا اللَّهُ، وَاللَّهُ أَكْبَرُ، وَلَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ", transliteration: nil, translation: "من قالها عند استيقاظه", reference: "البخاري", repetitionCount: 1, benefit: "غُفر له أو استُجيب له، فإن توضأ وصلى قُبلت صلاته", audioURL: nil),
            Zikr(id: 321, category: .wakeUp, arabicText: "الْحَمْدُ لِلَّهِ الَّذِي عَافَانِي فِي جَسَدِي، وَرَدَّ عَلَيَّ رُوحِي، وَأَذِنَ لِي بِذِكْرِهِ", transliteration: nil, translation: "الحمد لله الذي عافاني في جسدي", reference: "الترمذي", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 322, category: .wakeUp, arabicText: "اللَّهُمَّ إِنِّي أَصْبَحْتُ أُشْهِدُكَ وَأُشْهِدُ حَمَلَةَ عَرْشِكَ وَمَلَائِكَتَكَ وَجَمِيعَ خَلْقِكَ أَنَّكَ أَنْتَ اللَّهُ لَا إِلَهَ إِلَّا أَنْتَ، وَأَنَّ مُحَمَّدًا عَبْدُكَ وَرَسُولُكَ", transliteration: nil, translation: "اللهم إني أصبحت أشهدك", reference: "أبو داود", repetitionCount: 4, benefit: "من قالها أعتقه الله من النار", audioURL: nil),
            Zikr(id: 323, category: .wakeUp, arabicText: "رَبِّ أَعُوذُ بِكَ مِنْ هَمَزَاتِ الشَّيَاطِينِ وَأَعُوذُ بِكَ رَبِّ أَنْ يَحْضُرُونِ", transliteration: nil, translation: "رب أعوذ بك من همزات الشياطين", reference: "المؤمنون:97-98", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 324, category: .wakeUp, arabicText: "اللَّهُمَّ بِكَ أَصْبَحْنَا، وَبِكَ أَمْسَيْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ النُّشُورُ", transliteration: nil, translation: "اللهم بك أصبحنا", reference: "الترمذي", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 325, category: .wakeUp, arabicText: "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ", transliteration: nil, translation: "سبحان الله وبحمده عند الاستيقاظ", reference: "مسلم", repetitionCount: 100, benefit: "حُطت خطاياه وإن كانت مثل زبد البحر", audioURL: nil),
            Zikr(id: 326, category: .wakeUp, arabicText: "أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ رَبِّ الْعَالَمِينَ", transliteration: nil, translation: "أصبحنا وأصبح الملك لله", reference: "أبو داود", repetitionCount: 1, benefit: nil, audioURL: nil),
            
            // ═══════════════════════════════════════════════════════════
            // أذكار الطعام (10 ذكر)
            // ═══════════════════════════════════════════════════════════
            Zikr(id: 51, category: .food, arabicText: "بِسْمِ اللَّهِ", transliteration: nil, translation: "بسم الله (قبل الطعام)", reference: "الترمذي", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 52, category: .food, arabicText: "الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنَا وَسَقَانَا وَجَعَلَنَا مُسْلِمِينَ", transliteration: nil, translation: "الحمد لله الذي أطعمنا (بعد الطعام)", reference: "الترمذي", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 53, category: .food, arabicText: "الْحَمْدُ لِلَّهِ حَمْدًا كَثِيرًا طَيِّبًا مُبَارَكًا فِيهِ، غَيْرَ مَكْفِيٍّ وَلَا مُوَدَّعٍ، وَلَا مُسْتَغْنًى عَنْهُ رَبَّنَا", transliteration: nil, translation: "الحمد لله حمدًا كثيرًا طيبًا", reference: "البخاري", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 54, category: .food, arabicText: "اللَّهُمَّ بَارِكْ لَنَا فِيهِ وَأَطْعِمْنَا خَيْرًا مِنْهُ", transliteration: nil, translation: "اللهم بارك لنا فيه (عند شرب اللبن)", reference: "الترمذي", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 331, category: .food, arabicText: "بِسْمِ اللَّهِ فِي أَوَّلِهِ وَآخِرِهِ", transliteration: nil, translation: "بسم الله في أوله وآخره (إذا نسي)", reference: "أبو داود والترمذي", repetitionCount: 1, benefit: "إذا نسي أن يذكر اسم الله في أول طعامه", audioURL: nil),
            Zikr(id: 332, category: .food, arabicText: "الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنِي هَذَا وَرَزَقَنِيهِ مِنْ غَيْرِ حَوْلٍ مِنِّي وَلَا قُوَّةٍ", transliteration: nil, translation: "الحمد لله الذي أطعمني هذا", reference: "الترمذي", repetitionCount: 1, benefit: "غُفر له ما تقدم من ذنبه", audioURL: nil),
            Zikr(id: 333, category: .food, arabicText: "اللَّهُمَّ بَارِكْ لَنَا فِيهِ وَزِدْنَا مِنْهُ", transliteration: nil, translation: "اللهم بارك لنا فيه وزدنا منه", reference: "الترمذي", repetitionCount: 1, benefit: "عند شرب اللبن", audioURL: nil),
            Zikr(id: 334, category: .food, arabicText: "اللَّهُمَّ أَطْعِمْ مَنْ أَطْعَمَنِي وَاسْقِ مَنْ سَقَانِي", transliteration: nil, translation: "اللهم أطعم من أطعمني", reference: "مسلم", repetitionCount: 1, benefit: "دعاء للمضيف", audioURL: nil),
            Zikr(id: 335, category: .food, arabicText: "اللَّهُمَّ اغْفِرْ لَهُمْ وَارْحَمْهُمْ وَبَارِكْ لَهُمْ فِيمَا رَزَقْتَهُمْ", transliteration: nil, translation: "اللهم اغفر لهم وارحمهم", reference: "مسلم", repetitionCount: 1, benefit: "دعاء لأهل البيت عند الأكل عندهم", audioURL: nil),
            Zikr(id: 336, category: .food, arabicText: "الْحَمْدُ لِلَّهِ الَّذِي كَفَانَا وَأَرْوَانَا، غَيْرَ مَكْفِيٍّ وَلَا مَكْفُورٍ", transliteration: nil, translation: "الحمد لله الذي كفانا وأروانا", reference: "البخاري", repetitionCount: 1, benefit: nil, audioURL: nil),
            
            // ═══════════════════════════════════════════════════════════
            // أذكار السفر (10 ذكر)
            // ═══════════════════════════════════════════════════════════
            Zikr(id: 61, category: .travel, arabicText: "سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَٰذَا وَمَا كُنَّا لَهُ مُقْرِنِينَ، وَإِنَّا إِلَى رَبِّنَا لَمُنْقَلِبُونَ", transliteration: nil, translation: "سبحان الذي سخر لنا هذا", reference: "الترمذي", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 62, category: .travel, arabicText: "اللَّهُمَّ إِنَّا نَسْأَلُكَ فِي سَفَرِنَا هَٰذَا الْبِرَّ وَالتَّقْوَىٰ، وَمِنَ الْعَمَلِ مَا تَرْضَى. اللَّهُمَّ هَوِّنْ عَلَيْنَا سَفَرَنَا هَٰذَا وَاطْوِ عَنَّا بُعْدَهُ", transliteration: nil, translation: "اللهم إنا نسألك في سفرنا هذا البر والتقوى", reference: "مسلم", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 63, category: .travel, arabicText: "اللَّهُمَّ أَنْتَ الصَّاحِبُ فِي السَّفَرِ، وَالْخَلِيفَةُ فِي الْأَهْلِ. اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنْ وَعْثَاءِ السَّفَرِ، وَكَآبَةِ الْمَنْظَرِ، وَسُوءِ الْمُنْقَلَبِ فِي الْمَالِ وَالْأَهْلِ", transliteration: nil, translation: "اللهم أنت الصاحب في السفر", reference: "مسلم", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 64, category: .travel, arabicText: "آيِبُونَ تَائِبُونَ عَابِدُونَ لِرَبِّنَا حَامِدُونَ", transliteration: nil, translation: "آيبون تائبون عابدون (عند الرجوع من السفر)", reference: "مسلم", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 341, category: .travel, arabicText: "اللَّهُ أَكْبَرُ، اللَّهُ أَكْبَرُ، اللَّهُ أَكْبَرُ", transliteration: nil, translation: "التكبير عند الصعود", reference: "البخاري", repetitionCount: 3, benefit: "عند صعود المرتفعات", audioURL: nil),
            Zikr(id: 342, category: .travel, arabicText: "سُبْحَانَ اللَّهِ", transliteration: nil, translation: "التسبيح عند الهبوط", reference: "البخاري", repetitionCount: 3, benefit: "عند هبوط الأودية والمنخفضات", audioURL: nil),
            Zikr(id: 343, category: .travel, arabicText: "أَسْتَوْدِعُكُمُ اللَّهَ الَّذِي لَا تَضِيعُ وَدَائِعُهُ", transliteration: nil, translation: "أستودعكم الله (عند توديع المسافر)", reference: "أحمد", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 344, category: .travel, arabicText: "أَسْتَوْدِعُ اللَّهَ دِينَكَ وَأَمَانَتَكَ وَخَوَاتِيمَ عَمَلِكَ", transliteration: nil, translation: "أستودع الله دينك (للمسافر)", reference: "الترمذي", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 345, category: .travel, arabicText: "اللَّهُمَّ اطْوِ لَنَا الْأَرْضَ وَهَوِّنْ عَلَيْنَا السَّفَرَ", transliteration: nil, translation: "اللهم اطو لنا الأرض", reference: "الترمذي", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 346, category: .travel, arabicText: "أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ", transliteration: nil, translation: "أعوذ بكلمات الله التامات (عند النزول منزلاً)", reference: "مسلم", repetitionCount: 1, benefit: "لم يضره شيء حتى يرتحل من منزله ذلك", audioURL: nil),
            
            // أذكار المسجد
            Zikr(id: 71, category: .mosque, arabicText: "أَعُوذُ بِاللَّهِ الْعَظِيمِ، وَبِوَجْهِهِ الْكَرِيمِ، وَسُلْطَانِهِ الْقَدِيمِ، مِنَ الشَّيْطَانِ الرَّجِيمِ. بِسْمِ اللَّهِ، وَالصَّلَاةُ وَالسَّلَامُ عَلَى رَسُولِ اللَّهِ، اللَّهُمَّ افْتَحْ لِي أَبْوَابَ رَحْمَتِكَ", transliteration: nil, translation: "دعاء الدخول للمسجد", reference: "أبو داود", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 72, category: .mosque, arabicText: "بِسْمِ اللَّهِ، وَالصَّلَاةُ وَالسَّلَامُ عَلَى رَسُولِ اللَّهِ، اللَّهُمَّ إِنِّي أَسْأَلُكَ مِنْ فَضْلِكَ", transliteration: nil, translation: "دعاء الخروج من المسجد", reference: "مسلم", repetitionCount: 1, benefit: nil, audioURL: nil),
            
            // أذكار الوضوء
            Zikr(id: 81, category: .ablution, arabicText: "بِسْمِ اللَّهِ", transliteration: nil, translation: "بسم الله (قبل الوضوء)", reference: "الترمذي", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 82, category: .ablution, arabicText: "أَشْهَدُ أَنْ لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، وَأَشْهَدُ أَنَّ مُحَمَّدًا عَبْدُهُ وَرَسُولُهُ", transliteration: nil, translation: "الشهادة (بعد الوضوء)", reference: "مسلم", repetitionCount: 1, benefit: "فُتحت له أبواب الجنة الثمانية يدخل من أيها شاء", audioURL: nil),
            Zikr(id: 83, category: .ablution, arabicText: "اللَّهُمَّ اجْعَلْنِي مِنَ التَّوَّابِينَ، وَاجْعَلْنِي مِنَ الْمُتَطَهِّرِينَ", transliteration: nil, translation: "اللهم اجعلني من التوابين", reference: "الترمذي", repetitionCount: 1, benefit: nil, audioURL: nil),
            
            // أدعية قرآنية
            Zikr(id: 91, category: .quranicDuas, arabicText: "رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ", transliteration: nil, translation: "ربنا آتنا في الدنيا حسنة", reference: "البقرة:201", repetitionCount: 1, benefit: "أكثر دعاء النبي ﷺ", audioURL: nil),
            Zikr(id: 92, category: .quranicDuas, arabicText: "رَبَّنَا لَا تُزِغْ قُلُوبَنَا بَعْدَ إِذْ هَدَيْتَنَا وَهَبْ لَنَا مِن لَّدُنكَ رَحْمَةً ۚ إِنَّكَ أَنتَ الْوَهَّابُ", transliteration: nil, translation: "ربنا لا تزغ قلوبنا", reference: "آل عمران:8", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 93, category: .quranicDuas, arabicText: "رَبِّ اشْرَحْ لِي صَدْرِي، وَيَسِّرْ لِي أَمْرِي، وَاحْلُلْ عُقْدَةً مِّن لِّسَانِي، يَفْقَهُوا قَوْلِي", transliteration: nil, translation: "رب اشرح لي صدري (دعاء موسى عليه السلام)", reference: "طه:25-28", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 94, category: .quranicDuas, arabicText: "رَبِّ أَوْزِعْنِي أَنْ أَشْكُرَ نِعْمَتَكَ الَّتِي أَنْعَمْتَ عَلَيَّ وَعَلَىٰ وَالِدَيَّ وَأَنْ أَعْمَلَ صَالِحًا تَرْضَاهُ وَأَدْخِلْنِي بِرَحْمَتِكَ فِي عِبَادِكَ الصَّالِحِينَ", transliteration: nil, translation: "رب أوزعني أن أشكر نعمتك", reference: "النمل:19", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 95, category: .quranicDuas, arabicText: "رَبِّ زِدْنِي عِلْمًا", transliteration: nil, translation: "رب زدني علمًا", reference: "طه:114", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 96, category: .quranicDuas, arabicText: "رَبَّنَا اغْفِرْ لَنَا ذُنُوبَنَا وَإِسْرَافَنَا فِي أَمْرِنَا وَثَبِّتْ أَقْدَامَنَا وَانصُرْنَا عَلَى الْقَوْمِ الْكَافِرِينَ", transliteration: nil, translation: "ربنا اغفر لنا ذنوبنا", reference: "آل عمران:147", repetitionCount: 1, benefit: nil, audioURL: nil),
            
            // أدعية نبوية
            Zikr(id: 101, category: .propheticDuas, arabicText: "اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَافِيَةَ فِي الدُّنْيَا وَالْآخِرَةِ", transliteration: nil, translation: "اللهم إني أسألك العافية", reference: "ابن ماجه", repetitionCount: 1, benefit: "ما سُئل شيء أفضل من العافية", audioURL: nil),
            Zikr(id: 102, category: .propheticDuas, arabicText: "اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَالْعَجْزِ وَالْكَسَلِ، وَالْبُخْلِ وَالْجُبْنِ، وَضَلَعِ الدَّيْنِ وَغَلَبَةِ الرِّجَالِ", transliteration: nil, translation: "اللهم إني أعوذ بك من الهم والحزن", reference: "البخاري", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 103, category: .propheticDuas, arabicText: "اللَّهُمَّ إِنِّي أَسْأَلُكَ الْهُدَى وَالتُّقَى وَالْعَفَافَ وَالْغِنَى", transliteration: nil, translation: "اللهم إني أسألك الهدى والتقى", reference: "مسلم", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 104, category: .propheticDuas, arabicText: "اللَّهُمَّ أَصْلِحْ لِي دِينِي الَّذِي هُوَ عِصْمَةُ أَمْرِي، وَأَصْلِحْ لِي دُنْيَايَ الَّتِي فِيهَا مَعَاشِي، وَأَصْلِحْ لِي آخِرَتِي الَّتِي فِيهَا مَعَادِي، وَاجْعَلِ الْحَيَاةَ زِيَادَةً لِي فِي كُلِّ خَيْرٍ، وَاجْعَلِ الْمَوْتَ رَاحَةً لِي مِنْ كُلِّ شَرٍّ", transliteration: nil, translation: "اللهم أصلح لي ديني", reference: "مسلم", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 105, category: .propheticDuas, arabicText: "اللَّهُمَّ اغْفِرْ لِي خَطِيئَتِي وَجَهْلِي، وَإِسْرَافِي فِي أَمْرِي، وَمَا أَنْتَ أَعْلَمُ بِهِ مِنِّي", transliteration: nil, translation: "اللهم اغفر لي خطيئتي وجهلي", reference: "البخاري ومسلم", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 106, category: .propheticDuas, arabicText: "يَا مُقَلِّبَ الْقُلُوبِ ثَبِّتْ قَلْبِي عَلَى دِينِكَ", transliteration: nil, translation: "يا مقلب القلوب ثبت قلبي على دينك", reference: "الترمذي", repetitionCount: 1, benefit: "أكثر دعاء النبي ﷺ", audioURL: nil),
            
            // الرقية الشرعية
            Zikr(id: 111, category: .ruqyah, arabicText: "بِسْمِ اللَّهِ أَرْقِيكَ، مِنْ كُلِّ شَيْءٍ يُؤْذِيكَ، مِنْ شَرِّ كُلِّ نَفْسٍ أَوْ عَيْنِ حَاسِدٍ، اللَّهُ يَشْفِيكَ، بِسْمِ اللَّهِ أَرْقِيكَ", transliteration: nil, translation: "بسم الله أرقيك", reference: "مسلم", repetitionCount: 3, benefit: nil, audioURL: nil),
            Zikr(id: 112, category: .ruqyah, arabicText: "قُلْ هُوَ اللَّهُ أَحَدٌ، اللَّهُ الصَّمَدُ، لَمْ يَلِدْ وَلَمْ يُولَدْ، وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ", transliteration: nil, translation: "سورة الإخلاص", reference: "القرآن", repetitionCount: 3, benefit: nil, audioURL: nil),
            Zikr(id: 113, category: .ruqyah, arabicText: "قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ، مِن شَرِّ مَا خَلَقَ، وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ، وَمِن شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ، وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ", transliteration: nil, translation: "سورة الفلق", reference: "القرآن", repetitionCount: 3, benefit: nil, audioURL: nil),
            Zikr(id: 114, category: .ruqyah, arabicText: "قُلْ أَعُوذُ بِرَبِّ النَّاسِ، مَلِكِ النَّاسِ، إِلَٰهِ النَّاسِ، مِن شَرِّ الْوَسْوَاسِ الْخَنَّاسِ، الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ، مِنَ الْجِنَّةِ وَالنَّاسِ", transliteration: nil, translation: "سورة الناس", reference: "القرآن", repetitionCount: 3, benefit: nil, audioURL: nil),
            Zikr(id: 115, category: .ruqyah, arabicText: "أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّةِ مِنْ كُلِّ شَيْطَانٍ وَهَامَّةٍ، وَمِنْ كُلِّ عَيْنٍ لَامَّةٍ", transliteration: nil, translation: "أعوذ بكلمات الله التامة", reference: "البخاري", repetitionCount: 1, benefit: "كان النبي ﷺ يعوّذ الحسن والحسين بها", audioURL: nil),
            
            // أسماء الله الحسنى (99 اسماً)
            Zikr(id: 121, category: .namesOfAllah, arabicText: "اللهُ - الرَّحْمَنُ - الرَّحِيمُ - المَلِكُ - القُدُّوسُ - السَّلامُ - المُؤْمِنُ - المُهَيْمِنُ - العَزِيزُ - الجَبَّارُ - المُتَكَبِّرُ - الخَالِقُ - البَارِئُ - المُصَوِّرُ - الغَفَّارُ - القَهَّارُ - الوَهَّابُ - الرَّزَّاقُ - الفَتَّاحُ - العَلِيمُ", transliteration: nil, translation: "أسماء الله الحسنى (١-٢٠)", reference: "البخاري ومسلم", repetitionCount: 1, benefit: "من أحصاها دخل الجنة", audioURL: nil),
            Zikr(id: 122, category: .namesOfAllah, arabicText: "القَابِضُ - البَاسِطُ - الخَافِضُ - الرَّافِعُ - المُعِزُّ - المُذِلُّ - السَّمِيعُ - البَصِيرُ - الحَكَمُ - العَدْلُ - اللَّطِيفُ - الخَبِيرُ - الحَلِيمُ - العَظِيمُ - الغَفُورُ - الشَّكُورُ - العَلِيُّ - الكَبِيرُ - الحَفِيظُ - المُقِيتُ", transliteration: nil, translation: "أسماء الله الحسنى (٢١-٤٠)", reference: "البخاري ومسلم", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 123, category: .namesOfAllah, arabicText: "الحَسِيبُ - الجَلِيلُ - الكَرِيمُ - الرَّقِيبُ - المُجِيبُ - الوَاسِعُ - الحَكِيمُ - الوَدُودُ - المَجِيدُ - البَاعِثُ - الشَّهِيدُ - الحَقُّ - الوَكِيلُ - القَوِيُّ - المَتِينُ - الوَلِيُّ - الحَمِيدُ - المُحْصِي - المُبْدِئُ - المُعِيدُ", transliteration: nil, translation: "أسماء الله الحسنى (٤١-٦٠)", reference: "البخاري ومسلم", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 124, category: .namesOfAllah, arabicText: "المُحْيِي - المُمِيتُ - الحَيُّ - القَيُّومُ - الوَاجِدُ - المَاجِدُ - الوَاحِدُ - الصَّمَدُ - القَادِرُ - المُقْتَدِرُ - المُقَدِّمُ - المُؤَخِّرُ - الأَوَّلُ - الآخِرُ - الظَّاهِرُ - البَاطِنُ - الوَالِي - المُتَعَالِي - البَرُّ - التَّوَّابُ", transliteration: nil, translation: "أسماء الله الحسنى (٦١-٨٠)", reference: "البخاري ومسلم", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 125, category: .namesOfAllah, arabicText: "المُنْتَقِمُ - العَفُوُّ - الرَّؤُوفُ - مَالِكُ المُلْكِ - ذُو الجَلالِ وَالإِكْرَامِ - المُقْسِطُ - الجَامِعُ - الغَنِيُّ - المُغْنِي - المَانِعُ - الضَّارُّ - النَّافِعُ - النُّورُ - الهَادِي - البَدِيعُ - البَاقِي - الوَارِثُ - الرَّشِيدُ - الصَّبُورُ", transliteration: nil, translation: "أسماء الله الحسنى (٨١-٩٩)", reference: "البخاري ومسلم", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 126, category: .namesOfAllah, arabicText: "هُوَ ٱللَّهُ ٱلَّذِى لَآ إِلَٰهَ إِلَّا هُوَ ۖ عَٰلِمُ ٱلْغَيْبِ وَٱلشَّهَٰدَةِ ۖ هُوَ ٱلرَّحْمَٰنُ ٱلرَّحِيمُ ۝ هُوَ ٱللَّهُ ٱلَّذِى لَآ إِلَٰهَ إِلَّا هُوَ ٱلْمَلِكُ ٱلْقُدُّوسُ ٱلسَّلَٰمُ ٱلْمُؤْمِنُ ٱلْمُهَيْمِنُ ٱلْعَزِيزُ ٱلْجَبَّارُ ٱلْمُتَكَبِّرُ ۚ سُبْحَٰنَ ٱللَّهِ عَمَّا يُشْرِكُونَ ۝ هُوَ ٱللَّهُ ٱلْخَٰلِقُ ٱلْبَارِئُ ٱلْمُصَوِّرُ ۖ لَهُ ٱلْأَسْمَآءُ ٱلْحُسْنَىٰ", transliteration: nil, translation: "آيات الأسماء الحسنى من سورة الحشر", reference: "الحشر:22-24", repetitionCount: 1, benefit: "من قرأها في الصباح والمساء حُفظ", audioURL: nil),
            
            // أذكار الكرب والهم
            Zikr(id: 131, category: .distress, arabicText: "لَا إِلَهَ إِلَّا اللَّهُ الْعَظِيمُ الْحَلِيمُ، لَا إِلَهَ إِلَّا اللَّهُ رَبُّ الْعَرْشِ الْعَظِيمِ، لَا إِلَهَ إِلَّا اللَّهُ رَبُّ السَّمَاوَاتِ وَرَبُّ الْأَرْضِ وَرَبُّ الْعَرْشِ الْكَرِيمِ", transliteration: nil, translation: "دعاء الكرب", reference: "البخاري ومسلم", repetitionCount: 1, benefit: "دعاء الكرب العظيم", audioURL: nil),
            Zikr(id: 132, category: .distress, arabicText: "اللَّهُمَّ رَحْمَتَكَ أَرْجُو فَلَا تَكِلْنِي إِلَى نَفْسِي طَرْفَةَ عَيْنٍ، وَأَصْلِحْ لِي شَأْنِي كُلَّهُ، لَا إِلَهَ إِلَّا أَنْتَ", transliteration: nil, translation: "اللهم رحمتك أرجو", reference: "أبو داود", repetitionCount: 1, benefit: nil, audioURL: nil),
            Zikr(id: 133, category: .distress, arabicText: "لَا إِلَهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ", transliteration: nil, translation: "دعاء يونس عليه السلام", reference: "الأنبياء:87", repetitionCount: 1, benefit: "ما دعا بها مسلم في شيء قط إلا استجاب الله له", audioURL: nil),
            Zikr(id: 134, category: .distress, arabicText: "اللَّهُمَّ إِنِّي عَبْدُكَ، ابْنُ عَبْدِكَ، ابْنُ أَمَتِكَ، نَاصِيَتِي بِيَدِكَ، مَاضٍ فِيَّ حُكْمُكَ، عَدْلٌ فِيَّ قَضَاؤُكَ، أَسْأَلُكَ بِكُلِّ اسْمٍ هُوَ لَكَ، سَمَّيْتَ بِهِ نَفْسَكَ، أَوْ أَنْزَلْتَهُ فِي كِتَابِكَ، أَوْ عَلَّمْتَهُ أَحَدًا مِنْ خَلْقِكَ، أَوِ اسْتَأْثَرْتَ بِهِ فِي عِلْمِ الْغَيْبِ عِنْدَكَ، أَنْ تَجْعَلَ الْقُرْآنَ رَبِيعَ قَلْبِي، وَنُورَ صَدْرِي، وَجَلَاءَ حُزْنِي، وَذَهَابَ هَمِّي", transliteration: nil, translation: "دعاء الهم والحزن", reference: "أحمد", repetitionCount: 1, benefit: "أذهب الله همه وحزنه وأبدله مكانه فرحًا", audioURL: nil),
            Zikr(id: 135, category: .distress, arabicText: "حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ", transliteration: nil, translation: "حسبي الله لا إله إلا هو", reference: "التوبة:129", repetitionCount: 7, benefit: "من قالها سبع مرات صباحًا ومساءً كفاه الله ما أهمه", audioURL: nil),
            
            // أذكار الاستغفار والتوبة
            Zikr(id: 141, category: .forgiveness, arabicText: "أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ الَّذِي لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ وَأَتُوبُ إِلَيْهِ", transliteration: nil, translation: "سيد الاستغفار", reference: "الترمذي", repetitionCount: 3, benefit: "غُفرت ذنوبه وإن كانت مثل زبد البحر", audioURL: nil),
            Zikr(id: 142, category: .forgiveness, arabicText: "اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ", transliteration: nil, translation: "سيد الاستغفار", reference: "البخاري", repetitionCount: 1, benefit: "من قالها موقنًا بها فمات من يومه دخل الجنة", audioURL: nil),
            Zikr(id: 143, category: .forgiveness, arabicText: "رَبِّ اغْفِرْ لِي وَتُبْ عَلَيَّ إِنَّكَ أَنْتَ التَّوَّابُ الرَّحِيمُ", transliteration: nil, translation: "رب اغفر لي وتب علي", reference: "الترمذي", repetitionCount: 100, benefit: "كان النبي ﷺ يقولها في المجلس مائة مرة", audioURL: nil),
            
            // أذكار الصلاة على النبي ﷺ
            Zikr(id: 151, category: .salawat, arabicText: "اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ، كَمَا صَلَّيْتَ عَلَى إِبْرَاهِيمَ وَعَلَى آلِ إِبْرَاهِيمَ، إِنَّكَ حَمِيدٌ مَجِيدٌ، اللَّهُمَّ بَارِكْ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ، كَمَا بَارَكْتَ عَلَى إِبْرَاهِيمَ وَعَلَى آلِ إِبْرَاهِيمَ، إِنَّكَ حَمِيدٌ مَجِيدٌ", transliteration: nil, translation: "الصلاة الإبراهيمية", reference: "البخاري", repetitionCount: 10, benefit: "من صلى عليَّ صلاة صلى الله عليه بها عشرًا", audioURL: nil),
            Zikr(id: 152, category: .salawat, arabicText: "صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ", transliteration: nil, translation: "صلى الله عليه وسلم", reference: "متفق عليه", repetitionCount: 100, benefit: "أكثروا من الصلاة علي يوم الجمعة", audioURL: nil),
            
            // أذكار يوم الجمعة
            Zikr(id: 161, category: .friday, arabicText: "قُلْ هُوَ اللَّهُ أَحَدٌ، اللَّهُ الصَّمَدُ، لَمْ يَلِدْ وَلَمْ يُولَدْ، وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ", transliteration: nil, translation: "سورة الإخلاص", reference: "القرآن", repetitionCount: 3, benefit: "من قرأها ثلاث مرات فكأنما قرأ القرآن كله", audioURL: nil),
            Zikr(id: 162, category: .friday, arabicText: "اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ", transliteration: nil, translation: "الصلاة على النبي يوم الجمعة", reference: "أبو داود", repetitionCount: 100, benefit: "أكثروا من الصلاة علي يوم الجمعة وليلة الجمعة", audioURL: nil),
            
            // أذكار الشكر
            Zikr(id: 171, category: .gratitude, arabicText: "الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ", transliteration: nil, translation: "الحمد لله رب العالمين", reference: "الفاتحة:2", repetitionCount: 33, benefit: "الحمد تملأ الميزان", audioURL: nil),
            Zikr(id: 172, category: .gratitude, arabicText: "اللَّهُمَّ مَا أَصْبَحَ بِي مِنْ نِعْمَةٍ فَمِنْكَ وَحْدَكَ لَا شَرِيكَ لَكَ، فَلَكَ الْحَمْدُ وَلَكَ الشُّكْرُ", transliteration: nil, translation: "اللهم ما أصبح بي من نعمة", reference: "أبو داود", repetitionCount: 1, benefit: "أدى شكر يومه", audioURL: nil),
            
            // أذكار الحفظ والحماية
            Zikr(id: 181, category: .protection, arabicText: "اللَّهُمَّ احْفَظْنِي مِنْ بَيْنِ يَدَيَّ، وَمِنْ خَلْفِي، وَعَنْ يَمِينِي، وَعَنْ شِمَالِي، وَمِنْ فَوْقِي، وَأَعُوذُ بِعَظَمَتِكَ أَنْ أُغْتَالَ مِنْ تَحْتِي", transliteration: nil, translation: "اللهم احفظني من بين يدي", reference: "أبو داود", repetitionCount: 1, benefit: "دعاء الحفظ من كل جهة", audioURL: nil),
            Zikr(id: 182, category: .protection, arabicText: "اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنْ زَوَالِ نِعْمَتِكَ، وَتَحَوُّلِ عَافِيَتِكَ، وَفُجَاءَةِ نِقْمَتِكَ، وَجَمِيعِ سَخَطِكَ", transliteration: nil, translation: "اللهم إني أعوذ بك من زوال نعمتك", reference: "مسلم", repetitionCount: 1, benefit: nil, audioURL: nil),
            
            // ═══════════════════════════════════════════════════════════
            // صلاة الاستخارة وصفتها
            // ═══════════════════════════════════════════════════════════
            Zikr(id: 401, category: .istikhara, arabicText: "صِفَةُ صَلَاةِ الاسْتِخَارَةِ:\n\n١. تَتَوَضَّأُ وُضُوءَكَ لِلصَّلَاةِ\n٢. تُصَلِّي رَكْعَتَيْنِ مِنْ غَيْرِ الفَرِيضَةِ\n٣. تَقْرَأُ فِي الرَّكْعَةِ الأُولَى الفَاتِحَةَ وَسُورَةَ الكَافِرُونَ\n٤. تَقْرَأُ فِي الرَّكْعَةِ الثَّانِيَةِ الفَاتِحَةَ وَسُورَةَ الإِخْلَاصِ\n٥. بَعْدَ السَّلَامِ تَرْفَعُ يَدَيْكَ وَتَدْعُو بِدُعَاءِ الاسْتِخَارَةِ", transliteration: nil, translation: "صفة صلاة الاستخارة - ركعتان من غير الفريضة", reference: "البخاري", repetitionCount: 1, benefit: "تُصلى عند التردد في أمر من أمور الدنيا المباحة", audioURL: nil),
            Zikr(id: 402, category: .istikhara, arabicText: "اللَّهُمَّ إِنِّي أَسْتَخِيرُكَ بِعِلْمِكَ، وَأَسْتَقْدِرُكَ بِقُدْرَتِكَ، وَأَسْأَلُكَ مِنْ فَضْلِكَ الْعَظِيمِ، فَإِنَّكَ تَقْدِرُ وَلَا أَقْدِرُ، وَتَعْلَمُ وَلَا أَعْلَمُ، وَأَنْتَ عَلَّامُ الْغُيُوبِ", transliteration: nil, translation: "دعاء الاستخارة - الجزء الأول", reference: "البخاري", repetitionCount: 1, benefit: "يُقال بعد الصلاة", audioURL: nil),
            Zikr(id: 403, category: .istikhara, arabicText: "اللَّهُمَّ إِنْ كُنْتَ تَعْلَمُ أَنَّ هَذَا الْأَمْرَ (وَتُسَمِّي حَاجَتَكَ) خَيْرٌ لِي فِي دِينِي وَمَعَاشِي وَعَاقِبَةِ أَمْرِي - أَوْ قَالَ: عَاجِلِ أَمْرِي وَآجِلِهِ - فَاقْدُرْهُ لِي وَيَسِّرْهُ لِي، ثُمَّ بَارِكْ لِي فِيهِ", transliteration: nil, translation: "دعاء الاستخارة - الجزء الثاني (إن كان خيرًا)", reference: "البخاري", repetitionCount: 1, benefit: "تُسمّي حاجتك عند قولك (هذا الأمر)", audioURL: nil),
            Zikr(id: 404, category: .istikhara, arabicText: "وَإِنْ كُنْتَ تَعْلَمُ أَنَّ هَذَا الْأَمْرَ (وَتُسَمِّي حَاجَتَكَ) شَرٌّ لِي فِي دِينِي وَمَعَاشِي وَعَاقِبَةِ أَمْرِي - أَوْ قَالَ: عَاجِلِ أَمْرِي وَآجِلِهِ - فَاصْرِفْهُ عَنِّي وَاصْرِفْنِي عَنْهُ، وَاقْدُرْ لِيَ الْخَيْرَ حَيْثُ كَانَ، ثُمَّ أَرْضِنِي بِهِ", transliteration: nil, translation: "دعاء الاستخارة - الجزء الثالث (إن كان شرًا)", reference: "البخاري", repetitionCount: 1, benefit: "ثم تمضي في أمرك وتتوكل على الله", audioURL: nil),
            Zikr(id: 405, category: .istikhara, arabicText: "مَلَاحَظَاتٌ مُهِمَّةٌ عَنِ الاسْتِخَارَةِ:\n\n• لَا تَنْتَظِرْ رُؤْيَا أَوْ حُلُمًا، بَلْ تَوَكَّلْ عَلَى اللهِ وَامْضِ فِي أَمْرِكَ\n• يَجُوزُ تَكْرَارُهَا إِذَا لَمْ يَتَبَيَّنْ لَكَ شَيْءٌ\n• الاسْتِخَارَةُ فِي الأُمُورِ المُبَاحَةِ فَقَطْ، لَا فِي الوَاجِبَاتِ وَالمُحَرَّمَاتِ\n• لَا تَسْتَخِيرُ فِي تَرْكِ وَاجِبٍ أَوْ فِعْلِ مُحَرَّمٍ\n• إِذَا انْشَرَحَ صَدْرُكَ لِلْأَمْرِ فَهُوَ عَلَامَةُ خَيْرٍ", transliteration: nil, translation: "ملاحظات مهمة عن صلاة الاستخارة", reference: "أهل العلم", repetitionCount: 1, benefit: "فقه صلاة الاستخارة", audioURL: nil)
        ]
    }

    func scheduleMorningEvening() {
        notifications.scheduleAzkarReminder(hour: 5, minute: 30, category: .morning)
        notifications.scheduleAzkarReminder(hour: 17, minute: 0, category: .evening)
    }
}

