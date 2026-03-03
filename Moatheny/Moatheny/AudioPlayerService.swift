import Foundation
import AVFoundation
import Combine
import MediaPlayer
import UIKit

/// Lightweight AVPlayer wrapper for ayah/adhan playback with background support.
/// يدعم التشغيل في الخلفية وعلى شاشة القفل
final class AudioPlayerService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var duration: Double = 0
    @Published var currentTitle: String = ""
    @Published var isStreaming = false
    @Published var currentURL: URL?
    @Published var errorMessage: String?
    @Published var isBuffering = false
    
    // MARK: - Private Properties
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var playerItemObserver: NSKeyValueObservation?
    private var bufferingObserver: NSKeyValueObservation?
    private var cancellables = Set<AnyCancellable>()
    private var wasPlayingBeforeInterruption = false
    
    // MARK: - ملاحظة
    // نتجنب singleton هنا ونعتمد على AppContainer لحقن نفس النسخة في كل الواجهات.
    
    // MARK: - Initialization
    
    init() {
        setupAudioSession()
        setupRemoteCommands()
        setupInterruptionHandling()
        setupRouteChangeHandling()
    }
    
    deinit {
        stop()
        removeRemoteCommands()
    }
    
    // MARK: - Audio Session Setup
    
    /// إعداد جلسة الصوت للتشغيل في الخلفية
    /// يجب استدعاء هذه الدالة قبل أي تشغيل
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // إعداد الفئة للتشغيل في الخلفية
            // .playback: يسمح بالتشغيل في الخلفية وعلى شاشة القفل
            // .duckOthers: يخفض صوت التطبيقات الأخرى بدلاً من إيقافها
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.allowAirPlay, .allowBluetoothA2DP, .duckOthers]
            )
            
            // تفعيل جلسة الصوت
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            print("✅ تم إعداد جلسة الصوت للتشغيل في الخلفية بنجاح")
        } catch {
            print("❌ خطأ في إعداد جلسة الصوت: \(error.localizedDescription)")
            errorMessage = "خطأ في إعداد الصوت"
        }
    }
    
    /// إعادة تفعيل جلسة الصوت (تُستدعى قبل كل تشغيل)
    private func activateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ خطأ في تفعيل جلسة الصوت: \(error)")
        }
    }
    
    // MARK: - Remote Control Commands (للتحكم من شاشة القفل و Control Center)
    
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // تفعيل الأوامر
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.stopCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        
        // زر التشغيل
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        
        // زر الإيقاف المؤقت
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        // زر التشغيل/الإيقاف (سماعات البلوتوث)
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        
        // زر الإيقاف
        commandCenter.stopCommand.addTarget { [weak self] _ in
            self?.stop()
            return .success
        }
        
        // تغيير موضع التشغيل (السحب في شريط التقدم)
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self.seekToTime(positionEvent.positionTime)
            return .success
        }
    }
    
    private func removeRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.stopCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
    }
    
    // MARK: - Interruption Handling (للتعامل مع المكالمات وغيرها)
    
    private func setupInterruptionHandling() {
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                self?.handleInterruption(notification)
            }
            .store(in: &cancellables)
    }
    
    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // تم مقاطعة الصوت (مكالمة، تنبيه، Siri، إلخ)
            wasPlayingBeforeInterruption = isPlaying
            pause()
            print("⏸ تم إيقاف الصوت مؤقتاً بسبب مقاطعة")
            
        case .ended:
            // انتهت المقاطعة
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            
            if options.contains(.shouldResume) && wasPlayingBeforeInterruption {
                // إعادة تفعيل جلسة الصوت قبل الاستئناف
                activateAudioSession()
                resume()
                print("▶️ تم استئناف الصوت بعد انتهاء المقاطعة")
            }
            
        @unknown default:
            break
        }
    }
    
    // MARK: - Route Change Handling (للتعامل مع فصل السماعات)
    
    private func setupRouteChangeHandling() {
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] notification in
                self?.handleRouteChange(notification)
            }
            .store(in: &cancellables)
    }
    
    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .oldDeviceUnavailable:
            // تم فصل السماعات - إيقاف التشغيل
            DispatchQueue.main.async { [weak self] in
                self?.pause()
                print("⏸ تم إيقاف الصوت بسبب فصل السماعات")
            }
        default:
            break
        }
    }
    
    // MARK: - Now Playing Info (معلومات التشغيل على شاشة القفل)
    
    private func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()
        
        // العنوان
        nowPlayingInfo[MPMediaItemPropertyTitle] = currentTitle.isEmpty ? "القرآن الكريم" : currentTitle
        
        // الفنان/التطبيق
        nowPlayingInfo[MPMediaItemPropertyArtist] = "مؤذني"
        
        // معدل التشغيل
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        // المدة والوقت المنقضي
        if duration > 0 {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = progress * duration
        }
        
        // صورة الألبوم
        if let image = UIImage(named: "AppIcon") ?? UIImage(systemName: "book.fill")?.withTintColor(.systemGreen, renderingMode: .alwaysOriginal) {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        
        // تحديث المعلومات
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    // MARK: - Playback Methods
    
    /// تشغيل ملف صوتي من URL
    func play(url: URL, metadata: String = "") {
        // إيقاف أي تشغيل سابق
        stop()
        
        // إعادة تعيين الحالة
        errorMessage = nil
        currentURL = url
        currentTitle = metadata
        isBuffering = true
        
        // تفعيل جلسة الصوت
        activateAudioSession()
        
        // إنشاء المشغل
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        
        // الاحتفاظ بمرجع قوي للمشغل (مهم جداً للتشغيل في الخلفية)
        player?.automaticallyWaitsToMinimizeStalling = true
        
        // مراقبة حالة التشغيل
        setupPlayerItemObserver(for: item, metadata: metadata)
        
        // مراقبة التخزين المؤقت
        setupBufferingObserver(for: item)
        
        // مراقبة انتهاء التشغيل
        setupPlaybackEndObserver(for: item)
        
        // مراقبة التقدم
        setupTimeObserver()
    }
    
    private func setupPlayerItemObserver(for item: AVPlayerItem, metadata: String) {
        playerItemObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch item.status {
                case .readyToPlay:
                    self.player?.play()
                    self.isPlaying = true
                    self.isStreaming = false
                    self.isBuffering = false
                    self.updateNowPlayingInfo()
                    print("✅ بدأ تشغيل: \(metadata)")
                    
                case .failed:
                    self.errorMessage = item.error?.localizedDescription ?? "خطأ في التشغيل"
                    self.isPlaying = false
                    self.isBuffering = false
                    print("❌ فشل التشغيل: \(item.error?.localizedDescription ?? "خطأ غير معروف")")
                    
                case .unknown:
                    break
                    
                @unknown default:
                    break
                }
            }
        }
    }
    
    private func setupBufferingObserver(for item: AVPlayerItem) {
        bufferingObserver = item.observe(\.isPlaybackBufferEmpty, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                self?.isBuffering = item.isPlaybackBufferEmpty
            }
        }
    }
    
    private func setupPlaybackEndObserver(for item: AVPlayerItem) {
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.isPlaying = false
            self?.progress = 0
            self?.updateNowPlayingInfo()
            print("✅ انتهى التشغيل")
        }
    }
    
    private func setupTimeObserver() {
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self = self,
                  let duration = self.player?.currentItem?.duration.seconds,
                  duration > 0, !duration.isNaN else { return }
            
            self.duration = duration
            self.progress = time.seconds / duration
            self.updateNowPlayingInfo()
        }
    }
    
    /// تشغيل بث مباشر (streaming)
    func playStream(url: URL, title: String = "") {
        stop()
        
        errorMessage = nil
        currentURL = url
        currentTitle = title
        isBuffering = true
        
        activateAudioSession()
        
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player?.automaticallyWaitsToMinimizeStalling = true
        
        playerItemObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch item.status {
                case .readyToPlay:
                    self.player?.play()
                    self.isPlaying = true
                    self.isStreaming = true
                    self.isBuffering = false
                    self.updateNowPlayingInfo()
                    print("✅ بدأ البث: \(title)")
                    
                case .failed:
                    self.errorMessage = item.error?.localizedDescription ?? "خطأ في البث"
                    self.isPlaying = false
                    self.isBuffering = false
                    print("❌ فشل البث: \(item.error?.localizedDescription ?? "خطأ غير معروف")")
                    
                case .unknown:
                    break
                    
                @unknown default:
                    break
                }
            }
        }
        
        setupBufferingObserver(for: item)
    }
    
    /// إيقاف مؤقت
    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }
    
    /// استئناف التشغيل
    func resume() {
        activateAudioSession()
        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    /// تبديل التشغيل/الإيقاف
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }
    
    /// الانتقال إلى موضع معين (نسبة مئوية)
    func seek(to progress: Double) {
        guard let duration = player?.currentItem?.duration.seconds,
              !duration.isNaN else { return }
        let time = CMTime(seconds: progress * duration, preferredTimescale: 600)
        player?.seek(to: time) { [weak self] _ in
            self?.updateNowPlayingInfo()
        }
    }
    
    /// الانتقال إلى وقت محدد (بالثواني)
    func seekToTime(_ seconds: TimeInterval) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: time) { [weak self] _ in
            self?.updateNowPlayingInfo()
        }
    }
    
    /// إيقاف التشغيل بالكامل
    func stop() {
        // إيقاف المشغل
        player?.pause()
        
        // إزالة المراقبين
        if let obs = timeObserver {
            player?.removeTimeObserver(obs)
            timeObserver = nil
        }
        
        playerItemObserver?.invalidate()
        playerItemObserver = nil
        
        bufferingObserver?.invalidate()
        bufferingObserver = nil
        
        // إزالة مراقب انتهاء التشغيل
        if let item = player?.currentItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: item)
        }
        
        // تحرير المشغل
        player = nil
        
        // إعادة تعيين الحالة
        isPlaying = false
        isStreaming = false
        isBuffering = false
        progress = 0
        duration = 0
        currentTitle = ""
        currentURL = nil
        errorMessage = nil
        
        // مسح معلومات التشغيل من شاشة القفل
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    // MARK: - Convenience Methods
    
    /// تشغيل ملف صوت محلي
    func playLocal(named name: String, ext: String = "mp3") {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            print("❌ ملف الصوت غير موجود: \(name).\(ext)")
            errorMessage = "ملف الصوت غير موجود"
            return
        }
        play(url: url, metadata: name)
    }
    
    /// تشغيل سورة من قارئ معين
    func playSurah(reciter: MP3Reciter, surahNumber: Int, surahName: String) {
        guard let moshaf = reciter.moshaf.first else {
            errorMessage = "لا يوجد مصحف متاح لهذا القارئ"
            return
        }
        
        // التحقق من توفر السورة
        guard moshaf.surahList.contains(surahNumber) else {
            errorMessage = "السورة غير متوفرة لهذا القارئ"
            return
        }
        
        // بناء رابط الصوت
        let surahStr = String(format: "%03d", surahNumber)
        let audioURLString = "\(moshaf.server)\(surahStr).mp3"
        
        guard let url = URL(string: audioURLString) else {
            errorMessage = "رابط الصوت غير صالح"
            return
        }
        
        let metadata = "\(surahName) - \(reciter.name)"
        play(url: url, metadata: metadata)
    }
    
    /// تشغيل الأذان
    func playAdhan() {
        playLocal(named: "adhan", ext: "mp3")
        currentTitle = "الأذان"
        updateNowPlayingInfo()
    }
    
    /// تشغيل الإقامة
    func playIqama() {
        playLocal(named: "iqama", ext: "mp3")
        currentTitle = "الإقامة"
        updateNowPlayingInfo()
    }
}
