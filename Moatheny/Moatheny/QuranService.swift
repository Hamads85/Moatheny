import Foundation

/// Handles Quran text, reciters, and audio download/playback.
final class QuranService {
    private let api: APIClient
    private let cache: LocalCache
    private let downloadManager: DownloadManager
    private let audio: AudioPlayerService

    init(api: APIClient, cache: LocalCache, downloadManager: DownloadManager, audio: AudioPlayerService) {
        self.api = api
        self.cache = cache
        self.downloadManager = downloadManager
        self.audio = audio
    }

    func loadQuran() async throws -> [Surah] {
        // 1) الكاش: استخدمه فقط إذا كان كاملاً (114 سورة على الأقل)
        if let cached: [Surah] = try? cache.load([Surah].self, named: "quran.json"), cached.count >= 114 {
            return cached
        }
        
        // 2) الإنترنت: إذا توفر API يعيد المصحف كاملاً، خزّنه ثم أعده
        if let remoteSurahs = try? await api.fetchQuran(), remoteSurahs.count >= 114 {
            try? cache.store(remoteSurahs, named: "quran.json")
            return remoteSurahs
        }
        
        // 3) الملف المضمّن (Resources/sample_quran.json) - كامل 114 سورة
        if let bundled = loadBundledQuran(), bundled.count >= 114 {
            try? cache.store(bundled, named: "quran.json")
            return bundled
        }
        
        // 4) آخر حل: نسخة محلية مختصرة
        let localSurahs = createLocalSurahs()
        if !localSurahs.isEmpty {
            try? cache.store(localSurahs, named: "quran.json")
            return localSurahs
        }
        
        throw NSError(domain: "QuranService", code: -1, userInfo: [NSLocalizedDescriptionKey: "تعذر تحميل القرآن"])
    }
    
    /// قراءة القرآن الكامل من الملف المضمّن في Resources
    private func loadBundledQuran() -> [Surah]? {
        guard let url = Bundle.main.url(forResource: "sample_quran", withExtension: "json") else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Surah].self, from: data)
        } catch {
            print("Failed to load bundled Quran: \(error)")
            return nil
        }
    }
    
    /// إنشاء سور محلية كنسخة احتياطية
    private func createLocalSurahs() -> [Surah] {
        [
            // سورة الفاتحة
            Surah(
                id: 1,
                name: "سُورَةُ ٱلْفَاتِحَةِ",
                englishName: "Al-Fatihah",
                revelationType: "Meccan",
                numberOfAyahs: 7,
                ayahs: [
                    Ayah(id: 1, numberInSurah: 1, text: "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ", juz: 1, hizb: 1, page: 1, audioURL: nil, translations: nil),
                    Ayah(id: 2, numberInSurah: 2, text: "ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ", juz: 1, hizb: 1, page: 1, audioURL: nil, translations: nil),
                    Ayah(id: 3, numberInSurah: 3, text: "ٱلرَّحْمَٰنِ ٱلرَّحِيمِ", juz: 1, hizb: 1, page: 1, audioURL: nil, translations: nil),
                    Ayah(id: 4, numberInSurah: 4, text: "مَٰلِكِ يَوْمِ ٱلدِّينِ", juz: 1, hizb: 1, page: 1, audioURL: nil, translations: nil),
                    Ayah(id: 5, numberInSurah: 5, text: "إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ", juz: 1, hizb: 1, page: 1, audioURL: nil, translations: nil),
                    Ayah(id: 6, numberInSurah: 6, text: "ٱهْدِنَا ٱلصِّرَٰطَ ٱلْمُسْتَقِيمَ", juz: 1, hizb: 1, page: 1, audioURL: nil, translations: nil),
                    Ayah(id: 7, numberInSurah: 7, text: "صِرَٰطَ ٱلَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ ٱلْمَغْضُوبِ عَلَيْهِمْ وَلَا ٱلضَّآلِّينَ", juz: 1, hizb: 1, page: 1, audioURL: nil, translations: nil)
                ]
            ),
            // سورة البقرة (أول 10 آيات)
            Surah(
                id: 2,
                name: "سُورَةُ ٱلْبَقَرَةِ",
                englishName: "Al-Baqarah",
                revelationType: "Medinan",
                numberOfAyahs: 286,
                ayahs: [
                    Ayah(id: 8, numberInSurah: 1, text: "الٓمٓ", juz: 1, hizb: 1, page: 2, audioURL: nil, translations: nil),
                    Ayah(id: 9, numberInSurah: 2, text: "ذَٰلِكَ ٱلْكِتَٰبُ لَا رَيْبَ ۛ فِيهِ ۛ هُدًى لِّلْمُتَّقِينَ", juz: 1, hizb: 1, page: 2, audioURL: nil, translations: nil),
                    Ayah(id: 10, numberInSurah: 3, text: "ٱلَّذِينَ يُؤْمِنُونَ بِٱلْغَيْبِ وَيُقِيمُونَ ٱلصَّلَوٰةَ وَمِمَّا رَزَقْنَٰهُمْ يُنفِقُونَ", juz: 1, hizb: 1, page: 2, audioURL: nil, translations: nil),
                    Ayah(id: 11, numberInSurah: 4, text: "وَٱلَّذِينَ يُؤْمِنُونَ بِمَآ أُنزِلَ إِلَيْكَ وَمَآ أُنزِلَ مِن قَبْلِكَ وَبِٱلْءَاخِرَةِ هُمْ يُوقِنُونَ", juz: 1, hizb: 1, page: 2, audioURL: nil, translations: nil),
                    Ayah(id: 12, numberInSurah: 5, text: "أُوْلَٰٓئِكَ عَلَىٰ هُدًى مِّن رَّبِّهِمْ ۖ وَأُوْلَٰٓئِكَ هُمُ ٱلْمُفْلِحُونَ", juz: 1, hizb: 1, page: 2, audioURL: nil, translations: nil),
                    Ayah(id: 285, numberInSurah: 255, text: "ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ ٱلْحَىُّ ٱلْقَيُّومُ ۚ لَا تَأْخُذُهُۥ سِنَةٌ وَلَا نَوْمٌ ۚ لَّهُۥ مَا فِى ٱلسَّمَٰوَٰتِ وَمَا فِى ٱلْأَرْضِ ۗ مَن ذَا ٱلَّذِى يَشْفَعُ عِندَهُۥٓ إِلَّا بِإِذْنِهِۦ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَىْءٍ مِّنْ عِلْمِهِۦٓ إِلَّا بِمَا شَآءَ ۚ وَسِعَ كُرْسِيُّهُ ٱلسَّمَٰوَٰتِ وَٱلْأَرْضَ ۖ وَلَا يَـُٔودُهُۥ حِفْظُهُمَا ۚ وَهُوَ ٱلْعَلِىُّ ٱلْعَظِيمُ", juz: 3, hizb: 5, page: 42, audioURL: nil, translations: [Translation(language: "ar", text: "آية الكرسي - أعظم آية في القرآن")])
                ]
            ),
            // سورة يس
            Surah(
                id: 36,
                name: "سُورَةُ يٰسٓ",
                englishName: "Ya-Sin",
                revelationType: "Meccan",
                numberOfAyahs: 83,
                ayahs: [
                    Ayah(id: 3566, numberInSurah: 1, text: "يسٓ", juz: 22, hizb: 44, page: 440, audioURL: nil, translations: nil),
                    Ayah(id: 3567, numberInSurah: 2, text: "وَٱلْقُرْءَانِ ٱلْحَكِيمِ", juz: 22, hizb: 44, page: 440, audioURL: nil, translations: nil),
                    Ayah(id: 3568, numberInSurah: 3, text: "إِنَّكَ لَمِنَ ٱلْمُرْسَلِينَ", juz: 22, hizb: 44, page: 440, audioURL: nil, translations: nil),
                    Ayah(id: 3569, numberInSurah: 4, text: "عَلَىٰ صِرَٰطٍ مُّسْتَقِيمٍ", juz: 22, hizb: 44, page: 440, audioURL: nil, translations: nil),
                    Ayah(id: 3570, numberInSurah: 5, text: "تَنزِيلَ ٱلْعَزِيزِ ٱلرَّحِيمِ", juz: 22, hizb: 44, page: 440, audioURL: nil, translations: nil)
                ]
            ),
            // سورة الملك
            Surah(
                id: 67,
                name: "سُورَةُ ٱلْمُلْكِ",
                englishName: "Al-Mulk",
                revelationType: "Meccan",
                numberOfAyahs: 30,
                ayahs: [
                    Ayah(id: 5648, numberInSurah: 1, text: "تَبَٰرَكَ ٱلَّذِى بِيَدِهِ ٱلْمُلْكُ وَهُوَ عَلَىٰ كُلِّ شَىْءٍ قَدِيرٌ", juz: 29, hizb: 57, page: 562, audioURL: nil, translations: nil),
                    Ayah(id: 5649, numberInSurah: 2, text: "ٱلَّذِى خَلَقَ ٱلْمَوْتَ وَٱلْحَيَوٰةَ لِيَبْلُوَكُمْ أَيُّكُمْ أَحْسَنُ عَمَلًا ۚ وَهُوَ ٱلْعَزِيزُ ٱلْغَفُورُ", juz: 29, hizb: 57, page: 562, audioURL: nil, translations: nil),
                    Ayah(id: 5650, numberInSurah: 3, text: "ٱلَّذِى خَلَقَ سَبْعَ سَمَٰوَٰتٍ طِبَاقًا ۖ مَّا تَرَىٰ فِى خَلْقِ ٱلرَّحْمَٰنِ مِن تَفَٰوُتٍ ۖ فَٱرْجِعِ ٱلْبَصَرَ هَلْ تَرَىٰ مِن فُطُورٍ", juz: 29, hizb: 57, page: 562, audioURL: nil, translations: nil)
                ]
            ),
            // سورة الرحمن
            Surah(
                id: 55,
                name: "سُورَةُ ٱلرَّحْمَٰنِ",
                englishName: "Ar-Rahman",
                revelationType: "Medinan",
                numberOfAyahs: 78,
                ayahs: [
                    Ayah(id: 5065, numberInSurah: 1, text: "ٱلرَّحْمَٰنُ", juz: 27, hizb: 53, page: 531, audioURL: nil, translations: nil),
                    Ayah(id: 5066, numberInSurah: 2, text: "عَلَّمَ ٱلْقُرْءَانَ", juz: 27, hizb: 53, page: 531, audioURL: nil, translations: nil),
                    Ayah(id: 5067, numberInSurah: 3, text: "خَلَقَ ٱلْإِنسَٰنَ", juz: 27, hizb: 53, page: 531, audioURL: nil, translations: nil),
                    Ayah(id: 5068, numberInSurah: 4, text: "عَلَّمَهُ ٱلْبَيَانَ", juz: 27, hizb: 53, page: 531, audioURL: nil, translations: nil),
                    Ayah(id: 5077, numberInSurah: 13, text: "فَبِأَىِّ ءَالَآءِ رَبِّكُمَا تُكَذِّبَانِ", juz: 27, hizb: 53, page: 531, audioURL: nil, translations: nil)
                ]
            ),
            // سورة الواقعة
            Surah(
                id: 56,
                name: "سُورَةُ ٱلْوَاقِعَةِ",
                englishName: "Al-Waqi'ah",
                revelationType: "Meccan",
                numberOfAyahs: 96,
                ayahs: [
                    Ayah(id: 5143, numberInSurah: 1, text: "إِذَا وَقَعَتِ ٱلْوَاقِعَةُ", juz: 27, hizb: 54, page: 534, audioURL: nil, translations: nil),
                    Ayah(id: 5144, numberInSurah: 2, text: "لَيْسَ لِوَقْعَتِهَا كَاذِبَةٌ", juz: 27, hizb: 54, page: 534, audioURL: nil, translations: nil),
                    Ayah(id: 5145, numberInSurah: 3, text: "خَافِضَةٌ رَّافِعَةٌ", juz: 27, hizb: 54, page: 534, audioURL: nil, translations: nil)
                ]
            ),
            // سورة الكهف
            Surah(
                id: 18,
                name: "سُورَةُ ٱلْكَهْفِ",
                englishName: "Al-Kahf",
                revelationType: "Meccan",
                numberOfAyahs: 110,
                ayahs: [
                    Ayah(id: 2085, numberInSurah: 1, text: "ٱلْحَمْدُ لِلَّهِ ٱلَّذِىٓ أَنزَلَ عَلَىٰ عَبْدِهِ ٱلْكِتَٰبَ وَلَمْ يَجْعَل لَّهُۥ عِوَجَا", juz: 15, hizb: 29, page: 293, audioURL: nil, translations: nil),
                    Ayah(id: 2086, numberInSurah: 2, text: "قَيِّمًا لِّيُنذِرَ بَأْسًا شَدِيدًا مِّن لَّدُنْهُ وَيُبَشِّرَ ٱلْمُؤْمِنِينَ ٱلَّذِينَ يَعْمَلُونَ ٱلصَّٰلِحَٰتِ أَنَّ لَهُمْ أَجْرًا حَسَنًا", juz: 15, hizb: 29, page: 293, audioURL: nil, translations: nil),
                    Ayah(id: 2185, numberInSurah: 10, text: "إِذْ أَوَى ٱلْفِتْيَةُ إِلَى ٱلْكَهْفِ فَقَالُواْ رَبَّنَآ ءَاتِنَا مِن لَّدُنكَ رَحْمَةً وَهَيِّئْ لَنَا مِنْ أَمْرِنَا رَشَدًا", juz: 15, hizb: 30, page: 294, audioURL: nil, translations: nil)
                ]
            ),
            // سورة الإخلاص
            Surah(
                id: 112,
                name: "سُورَةُ ٱلْإِخْلَاصِ",
                englishName: "Al-Ikhlas",
                revelationType: "Meccan",
                numberOfAyahs: 4,
                ayahs: [
                    Ayah(id: 6221, numberInSurah: 1, text: "قُلْ هُوَ ٱللَّهُ أَحَدٌ", juz: 30, hizb: 60, page: 604, audioURL: nil, translations: nil),
                    Ayah(id: 6222, numberInSurah: 2, text: "ٱللَّهُ ٱلصَّمَدُ", juz: 30, hizb: 60, page: 604, audioURL: nil, translations: nil),
                    Ayah(id: 6223, numberInSurah: 3, text: "لَمْ يَلِدْ وَلَمْ يُولَدْ", juz: 30, hizb: 60, page: 604, audioURL: nil, translations: nil),
                    Ayah(id: 6224, numberInSurah: 4, text: "وَلَمْ يَكُن لَّهُۥ كُفُوًا أَحَدٌۢ", juz: 30, hizb: 60, page: 604, audioURL: nil, translations: nil)
                ]
            ),
            // سورة الفلق
            Surah(
                id: 113,
                name: "سُورَةُ ٱلْفَلَقِ",
                englishName: "Al-Falaq",
                revelationType: "Meccan",
                numberOfAyahs: 5,
                ayahs: [
                    Ayah(id: 6225, numberInSurah: 1, text: "قُلْ أَعُوذُ بِرَبِّ ٱلْفَلَقِ", juz: 30, hizb: 60, page: 604, audioURL: nil, translations: nil),
                    Ayah(id: 6226, numberInSurah: 2, text: "مِن شَرِّ مَا خَلَقَ", juz: 30, hizb: 60, page: 604, audioURL: nil, translations: nil),
                    Ayah(id: 6227, numberInSurah: 3, text: "وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ", juz: 30, hizb: 60, page: 604, audioURL: nil, translations: nil),
                    Ayah(id: 6228, numberInSurah: 4, text: "وَمِن شَرِّ ٱلنَّفَّٰثَٰتِ فِى ٱلْعُقَدِ", juz: 30, hizb: 60, page: 604, audioURL: nil, translations: nil),
                    Ayah(id: 6229, numberInSurah: 5, text: "وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ", juz: 30, hizb: 60, page: 604, audioURL: nil, translations: nil)
                ]
            ),
            // سورة الناس
            Surah(
                id: 114,
                name: "سُورَةُ ٱلنَّاسِ",
                englishName: "An-Nas",
                revelationType: "Meccan",
                numberOfAyahs: 6,
                ayahs: [
                    Ayah(id: 6230, numberInSurah: 1, text: "قُلْ أَعُوذُ بِرَبِّ ٱلنَّاسِ", juz: 30, hizb: 60, page: 604, audioURL: nil, translations: nil),
                    Ayah(id: 6231, numberInSurah: 2, text: "مَلِكِ ٱلنَّاسِ", juz: 30, hizb: 60, page: 604, audioURL: nil, translations: nil),
                    Ayah(id: 6232, numberInSurah: 3, text: "إِلَٰهِ ٱلنَّاسِ", juz: 30, hizb: 60, page: 604, audioURL: nil, translations: nil),
                    Ayah(id: 6233, numberInSurah: 4, text: "مِن شَرِّ ٱلْوَسْوَاسِ ٱلْخَنَّاسِ", juz: 30, hizb: 60, page: 604, audioURL: nil, translations: nil),
                    Ayah(id: 6234, numberInSurah: 5, text: "ٱلَّذِى يُوَسْوِسُ فِى صُدُورِ ٱلنَّاسِ", juz: 30, hizb: 60, page: 604, audioURL: nil, translations: nil),
                    Ayah(id: 6235, numberInSurah: 6, text: "مِنَ ٱلْجِنَّةِ وَٱلنَّاسِ", juz: 30, hizb: 60, page: 604, audioURL: nil, translations: nil)
                ]
            ),
            // سورة الضحى
            Surah(
                id: 93,
                name: "سُورَةُ ٱلضُّحَىٰ",
                englishName: "Ad-Dhuha",
                revelationType: "Meccan",
                numberOfAyahs: 11,
                ayahs: [
                    Ayah(id: 6099, numberInSurah: 1, text: "وَٱلضُّحَىٰ", juz: 30, hizb: 60, page: 596, audioURL: nil, translations: nil),
                    Ayah(id: 6100, numberInSurah: 2, text: "وَٱلَّيْلِ إِذَا سَجَىٰ", juz: 30, hizb: 60, page: 596, audioURL: nil, translations: nil),
                    Ayah(id: 6101, numberInSurah: 3, text: "مَا وَدَّعَكَ رَبُّكَ وَمَا قَلَىٰ", juz: 30, hizb: 60, page: 596, audioURL: nil, translations: nil),
                    Ayah(id: 6102, numberInSurah: 4, text: "وَلَلْءَاخِرَةُ خَيْرٌ لَّكَ مِنَ ٱلْأُولَىٰ", juz: 30, hizb: 60, page: 596, audioURL: nil, translations: nil),
                    Ayah(id: 6103, numberInSurah: 5, text: "وَلَسَوْفَ يُعْطِيكَ رَبُّكَ فَتَرْضَىٰٓ", juz: 30, hizb: 60, page: 596, audioURL: nil, translations: nil),
                    Ayah(id: 6104, numberInSurah: 6, text: "أَلَمْ يَجِدْكَ يَتِيمًا فَـَٔاوَىٰ", juz: 30, hizb: 60, page: 596, audioURL: nil, translations: nil),
                    Ayah(id: 6105, numberInSurah: 7, text: "وَوَجَدَكَ ضَآلًّا فَهَدَىٰ", juz: 30, hizb: 60, page: 596, audioURL: nil, translations: nil),
                    Ayah(id: 6106, numberInSurah: 8, text: "وَوَجَدَكَ عَآئِلًا فَأَغْنَىٰ", juz: 30, hizb: 60, page: 596, audioURL: nil, translations: nil),
                    Ayah(id: 6107, numberInSurah: 9, text: "فَأَمَّا ٱلْيَتِيمَ فَلَا تَقْهَرْ", juz: 30, hizb: 60, page: 596, audioURL: nil, translations: nil),
                    Ayah(id: 6108, numberInSurah: 10, text: "وَأَمَّا ٱلسَّآئِلَ فَلَا تَنْهَرْ", juz: 30, hizb: 60, page: 596, audioURL: nil, translations: nil),
                    Ayah(id: 6109, numberInSurah: 11, text: "وَأَمَّا بِنِعْمَةِ رَبِّكَ فَحَدِّثْ", juz: 30, hizb: 60, page: 596, audioURL: nil, translations: nil)
                ]
            ),
            // سورة الشرح
            Surah(
                id: 94,
                name: "سُورَةُ ٱلشَّرْحِ",
                englishName: "Ash-Sharh",
                revelationType: "Meccan",
                numberOfAyahs: 8,
                ayahs: [
                    Ayah(id: 6110, numberInSurah: 1, text: "أَلَمْ نَشْرَحْ لَكَ صَدْرَكَ", juz: 30, hizb: 60, page: 596, audioURL: nil, translations: nil),
                    Ayah(id: 6111, numberInSurah: 2, text: "وَوَضَعْنَا عَنكَ وِزْرَكَ", juz: 30, hizb: 60, page: 596, audioURL: nil, translations: nil),
                    Ayah(id: 6112, numberInSurah: 3, text: "ٱلَّذِىٓ أَنقَضَ ظَهْرَكَ", juz: 30, hizb: 60, page: 596, audioURL: nil, translations: nil),
                    Ayah(id: 6113, numberInSurah: 4, text: "وَرَفَعْنَا لَكَ ذِكْرَكَ", juz: 30, hizb: 60, page: 596, audioURL: nil, translations: nil),
                    Ayah(id: 6114, numberInSurah: 5, text: "فَإِنَّ مَعَ ٱلْعُسْرِ يُسْرًا", juz: 30, hizb: 60, page: 596, audioURL: nil, translations: nil),
                    Ayah(id: 6115, numberInSurah: 6, text: "إِنَّ مَعَ ٱلْعُسْرِ يُسْرًا", juz: 30, hizb: 60, page: 596, audioURL: nil, translations: nil),
                    Ayah(id: 6116, numberInSurah: 7, text: "فَإِذَا فَرَغْتَ فَٱنصَبْ", juz: 30, hizb: 60, page: 596, audioURL: nil, translations: nil),
                    Ayah(id: 6117, numberInSurah: 8, text: "وَإِلَىٰ رَبِّكَ فَٱرْغَب", juz: 30, hizb: 60, page: 596, audioURL: nil, translations: nil)
                ]
            )
        ]
    }

    func loadReciters() async throws -> [Reciter] {
        if let cached: [Reciter] = try? cache.load([Reciter].self, named: "reciters.json") {
            return cached
        }
        do {
        let reciters = try await api.fetchReciters()
        try? cache.store(reciters, named: "reciters.json")
        return reciters
        } catch {
            // إرجاع قائمة فارغة إذا فشل
            return []
        }
    }

    func play(ayah: Ayah, reciter: Reciter) {
        // If ayah has explicit audio URL use it, otherwise fallback to reciter base URL.
        audio.play(url: ayah.audioURL ?? reciter.baseURL, metadata: "Ayah \(ayah.numberInSurah)")
    }

    func downloadSurah(_ surah: Surah, reciter: Reciter) async {
        await downloadManager.download(surah: surah, reciter: reciter)
    }
}

