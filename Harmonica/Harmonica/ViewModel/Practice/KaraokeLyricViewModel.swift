// KaraokeLyricViewModel.swift
import SwiftUI
import AVFoundation

class KaraokeLyricViewModel: ObservableObject {
    // MARK: - StateC
    private var currentLineIndex: Int = 0
    private var currentLine: LyricLine = LyricLine(text: "", timings: [])
    private var currentCharacterIndex: Int = 0
    @Published var currentCharacterProgress: CGFloat = 0.0
    private var currentCharDuration: Double = 0.0
    private var startTime: Date = Date()
    @Published var countdown: Int? = nil
    private var countdownTimer: Timer?
    private var isCountingDown = false
    
    private var nextLineIndex: Int = 1
    private var nextLine: LyricLine = LyricLine(text: "", timings: [])
    private var nextCharacterIndex: Int = 0
    @Published var nextCharacterProgress: CGFloat = 0.0
    private var nextCharDuration: Double = 0.0
    private var nextstartTime: Date = Date()
    
    // 음악 재생 관련 State
    let songInfo: SongInfo
    private var player: AVPlayer = AVPlayer()
    @Published var mode: PlayMode = .ar
    private var currentTime: Double = 0
    private var playbackTimer: Timer?
    private var autoProgressTimer: Timer?
    @Published var currentSegmentIndex = 0
    @Published var segments: [LyricSegment] = []
    @Published var lyricLines: [LyricLine] = []
    @Published var isPlaying = false
    
    // 메트로놈 관련 State
    private var metronomeStartTime: Date?
    private var currentBeat: Int = 0
    private var beatProgress: CGFloat = 0.0
    private var isMetronomeActive = false
    private var lastBeatTime: Date = Date()
    private var metronomePlayer: AVAudioPlayer?

    //View용 State
    @Published var isBackPressed: Bool = false
    @Published var isRetryPressed: Bool = false
    @Published var isNextPressed: Bool = false
    
    init(songInfo: SongInfo) {
        self.songInfo = songInfo
    }
    
    var beatsPerMeasure: Int {
        songInfo.timeSignatureTop
    }

    private var beatDuration: Double {
        60.0 / Double(songInfo.bpm)
    }
    
    var hasNextLine: Bool {
        guard nextLineIndex < lyricLines.count,
              nextLineIndex < segments.count,
              currentSegmentIndex < segments.count else { return false }
        return segments[currentSegmentIndex].index == segments[nextLineIndex].index
    }
    
    var lyricsWithDuration: [(String, Double)] {
        currentLine.characterDurations
    }
    
    var NextlyricsWithDuration: [(String, Double)] {
        nextLine.characterDurations
    }
    
    var fullText: String {
        lyricsWithDuration.map { $0.0 }.joined()
    }
    var highlightedText: String {
        lyricsWithDuration.prefix(currentCharacterIndex).map { $0.0 }.joined()
    }
    var currentChar: String {
        currentCharacterIndex < lyricsWithDuration.count ? lyricsWithDuration[currentCharacterIndex].0 : ""
    }
    
    var nextfullText: String {
        NextlyricsWithDuration.map { $0.0 }.joined()
    }
    
    var nexthighlightedtext: String {
        NextlyricsWithDuration.prefix(nextCharacterIndex).map { $0.0 }.joined()
    }
    var nextcurrentChar: String {
        nextCharacterIndex < NextlyricsWithDuration.count ? NextlyricsWithDuration[nextCharacterIndex].0 : ""
    }
    
    // MARK: - Test
    func isModeAR() -> Bool {
        return mode == .ar
    }
    
    func isCountdownActive() -> Bool {
        return countdown != nil
    }
    
    func updateAllTimers() {
        updateTimerCurrent()
        updateTimerNext()
        updateMetronome()
    }
    
    func updateTimerCurrent() {
        guard countdown == nil else { return }
        guard currentCharacterIndex < lyricsWithDuration.count else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let duration = lyricsWithDuration[currentCharacterIndex].1
        currentCharacterProgress = min(1.0, elapsed / duration)
        
        if currentCharacterProgress >= 1.0 {
            currentCharacterIndex += 1
            currentCharacterProgress = 0.0
            if currentCharacterIndex < lyricsWithDuration.count {
                currentCharDuration = lyricsWithDuration[currentCharacterIndex].1
                startTime = Date()
            }
        }
    }
    
    func updateTimerNext() {
        guard countdown == nil else { return }
        guard hasNextLine else { return }
        guard nextCharacterIndex < NextlyricsWithDuration.count else { return }
        
        let elapsed = Date().timeIntervalSince(nextstartTime)
        let duration = NextlyricsWithDuration[nextCharacterIndex].1
        nextCharacterProgress = min(1.0, elapsed / duration)
        
        if nextCharacterProgress >= 1.0 {
            nextCharacterIndex += 1
            nextCharacterProgress = 0.0
            if nextCharacterIndex < NextlyricsWithDuration.count {
                nextCharDuration = NextlyricsWithDuration[nextCharacterIndex].1
                nextstartTime = Date()
            }
        }
    }
    
    // MARK: - Functions
    func setupAudio() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("오디오 세션 설정 실패: \(error)")
        }
    }
    
    func setupMetronomeSound() {
        guard let soundURL = Bundle.main.url(forResource: "metronome_click", withExtension: "mp3") else {
            print("No metronome sound file: use system sound")
            return
        }
        
        do {
            metronomePlayer = try AVAudioPlayer(contentsOf: soundURL)
            metronomePlayer?.prepareToPlay()
            metronomePlayer?.volume = 0.7
        } catch {
            print("FAIL metronome sound setting: \(error)")
        }
    }
    
    func playMetronomeSound() {
        guard isPlaying || countdown != nil else { return }
        
        if let player = metronomePlayer {
            player.stop()
            player.currentTime = 0
            player.play()
        } else {
            AudioServicesPlaySystemSound(1103)
        }
    }
    
    func startMetronome() {
        metronomeStartTime = Date()
        lastBeatTime = Date()
        currentBeat = 0
        beatProgress = 0.0
        isMetronomeActive = true
        playMetronomeSound()
    }
    
    func stopMetronome() {
        isMetronomeActive = false
        metronomeStartTime = nil
        currentBeat = 0
        beatProgress = 0.0
    }
    
    func updateMetronome() {
        guard (isPlaying || countdown != nil) && isMetronomeActive, let startTime = metronomeStartTime else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let totalBeats = elapsed / beatDuration
        
        let newBeat = Int(totalBeats) % beatsPerMeasure
        
        if newBeat != currentBeat {
            currentBeat = newBeat
            playMetronomeSound()
            lastBeatTime = Date()
        }
        
        let beatElapsed = totalBeats - floor(totalBeats)
        beatProgress = CGFloat(beatElapsed)
    }
    
    func getMetronomeImageState(for index: Int) -> Bool {
        if let count = countdown {
            return index <= count
        }
        
        if isMetronomeActive {
            return index <= currentBeat
        }
        
        return false
    }
    
    func loadLyrics() {
        guard let path = Bundle.main.path(forResource: songInfo.lyricsFileName, ofType: "json") else {
            print("가사 파일을 찾을 수 없습니다: \(songInfo.lyricsFileName)")
            return
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let lyricDataArray = try JSONDecoder().decode([LyricData].self, from: data)
            
            segments = parseLyricsFromJSON(lyricDataArray: lyricDataArray)
            lyricLines = createLyricLines(from: lyricDataArray)
        } catch {
            print("가사 파일 읽기 실패: \(error)")
        }
    }
    
    func parseLyricsFromJSON(lyricDataArray: [LyricData]) -> [LyricSegment] {
        var segments: [LyricSegment] = []
        
        for lyricData in lyricDataArray {
            let startTime = lyricData.mp3Start
            let endTime: Double
            
            // duration이 null이면 기본값 3초 사용
            if let duration = lyricData.duration {
                endTime = startTime + duration
            } else {
                endTime = startTime + 3.0
            }
            
            let segment = LyricSegment(
                startTime: startTime,
                endTime: endTime,
                lyric: lyricData.Lyric,
                timingArray: lyricData.timingArray,
                index: lyricData.index
            )
            
            segments.append(segment)
        }
        
        return segments
    }
    
    func createLyricLines(from lyricDataArray: [LyricData]) -> [LyricLine] {
        return lyricDataArray
            .sorted(by: { $0.index < $1.index })
            .map { LyricLine(text: $0.Lyric, timings: $0.timingArray) }
    }
    
    func updateCurrentLines() {
        guard currentLineIndex < lyricLines.count else { return }
        
        currentLine = lyricLines[currentLineIndex]
        nextLineIndex = currentLineIndex + 1
        if nextLineIndex < lyricLines.count && hasNextLine {
            nextLine = lyricLines[nextLineIndex]
        }
    }
    
    func resetCharacterStates() {
        currentCharacterIndex = 0
        nextCharacterIndex = 0
        currentCharacterProgress = 0
        nextCharacterProgress = 0
        countdown = 0
        startCountdown()
    }
    
    func resetCharacterStatesForMR() {
        currentCharacterIndex = 0
        nextCharacterIndex = 0
        currentCharacterProgress = 0
        nextCharacterProgress = 0
        countdown = 0
        startCountdownForMR()
    }
    
    func previous() {
        guard currentSegmentIndex > 0 else { return }
        
        stopPlayback()
        mode = .ar
        
        let currentIndex = segments[currentSegmentIndex].index
        var targetSegmentIndex = currentSegmentIndex - 1
        
        while targetSegmentIndex >= 0 && segments[targetSegmentIndex].index == currentIndex {
            targetSegmentIndex -= 1
        }
        
        if targetSegmentIndex >= 0 {
            let targetIndex = segments[targetSegmentIndex].index
            while targetSegmentIndex > 0 && segments[targetSegmentIndex - 1].index == targetIndex {
                targetSegmentIndex -= 1
            }
            
            currentSegmentIndex = targetSegmentIndex
            currentLineIndex = findLineIndexBySegmentIndex(targetSegmentIndex)
            updateCurrentLines()
            replay()
        }
    }
    
    func next() {
        guard currentSegmentIndex < segments.count - 1 else { return }
        
        stopPlayback()
        mode = .ar
        
        let currentIndex = segments[currentSegmentIndex].index
        var targetSegmentIndex = currentSegmentIndex + 1
        
        while targetSegmentIndex < segments.count && segments[targetSegmentIndex].index == currentIndex {
            targetSegmentIndex += 1
        }
        
        if targetSegmentIndex < segments.count {
            currentSegmentIndex = targetSegmentIndex
            currentLineIndex = findLineIndexBySegmentIndex(targetSegmentIndex)
            updateCurrentLines()
            replay()
        }
    }
    
    // 세그먼트 인덱스에 해당하는 가사 라인 인덱스 찾는 함수
    func findLineIndexBySegmentIndex(_ segmentIndex: Int) -> Int {
        guard segmentIndex < segments.count else { return 0 }
        let targetIndex = segments[segmentIndex].index
        
        for (lineIndex, segment) in segments.enumerated() {
            if segment.index == targetIndex {
                return lineIndex
            }
        }
        return segmentIndex // 찾지 못한 경우 segmentIndex 반환
    }
    
    func replay() {
        guard currentSegmentIndex < segments.count else { return }
        
        stopPlayback()
        mode = .ar
        
        let segment = segments[currentSegmentIndex]
        let fileName = songInfo.arFileName // 항상 AR부터 시작
        
        guard let url = Bundle.main.url(forResource: fileName.replacingOccurrences(of: ".mp3", with: ""), withExtension: "mp3") else {
            print("오디오 파일을 찾을 수 없습니다: \(fileName)")
            return
        }
        
        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        
        let startTime = CMTime(seconds: segment.startTime, preferredTimescale: 600)
        player.seek(to: startTime) { [self] _ in
            resetCharacterStates()
        }
    }
    
    func startPlaybackTimer(segment: LyricSegment) {
        stopTimer()
        isPlaying = true
        
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [self] timer in
            let currentTime = player.currentTime().seconds
            
            if currentTime >= segment.endTime {
                player.pause()
                timer.invalidate()
                
                if mode == .ar {
                    autoProgressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                        self.mode = .mr
                        self.startMRPlayback(segment: segment)
                    }
                } else {
                    isPlaying = false
                    stopMetronome()
                }
            }
            
            self.currentTime = currentTime
        }
    }
    
    func startMRPlayback(segment: LyricSegment) {
        let fileName = songInfo.mrFileName
        
        guard let url = Bundle.main.url(forResource: fileName.replacingOccurrences(of: ".mp3", with: ""), withExtension: "mp3") else {
            print("MR 파일을 찾을 수 없습니다: \(fileName)")
            return
        }
        
        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        
        let startTime = CMTime(seconds: segment.startTime, preferredTimescale: 600)
        player.seek(to: startTime) { [self] _ in
            resetCharacterStatesForMR()
        }
    }
    
    func stopTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        autoProgressTimer?.invalidate()
        autoProgressTimer = nil
    }
    
    func stopPlayback() {
        player.pause()
        isPlaying = false
        stopTimer()
        stopMetronome()
    }
    
    // 하나 둘 셋 넷 카운터 (AR용)
    private func startCountdown() {
        countdownTimer?.invalidate()
        
        startMetronome()
        
        let countdownInterval = beatDuration
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: countdownInterval, repeats: true) { timer in
            guard let currentCount = self.countdown else { return }
            
            self.countdown = currentCount + 1
            
            if self.countdown! >= 4 {
                self.countdown = nil
                self.isCountingDown = false
                timer.invalidate()
                self.countdownTimer = nil
                
                guard self.currentSegmentIndex < self.segments.count else { return }
                let segment = self.segments[self.currentSegmentIndex]
                self.player.play()
                self.startPlaybackTimer(segment: segment)
                
                self.currentCharDuration = self.lyricsWithDuration.first?.1 ?? 0.0
                self.startTime = Date()
                if self.hasNextLine {
                    self.nextCharDuration = self.NextlyricsWithDuration.first?.1 ?? 0.0
                    self.nextstartTime = Date()
                }
            }
        }
    }
    
    // 하나 둘 셋 넷 카운터 (MR용)
    private func startCountdownForMR() {
        countdownTimer?.invalidate()
        
        startMetronome()
        
        let countdownInterval = beatDuration
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: countdownInterval, repeats: true) { timer in
            guard let currentCount = self.countdown else { return }
            
            self.countdown = currentCount + 1
            
            if self.countdown! >= 4 {
                self.countdown = nil
                self.isCountingDown = false
                timer.invalidate()
                self.countdownTimer = nil
                
                guard self.currentSegmentIndex < self.segments.count else { return }
                let segment = self.segments[self.currentSegmentIndex]
                self.player.play()
                self.startPlaybackTimer(segment: segment)
                
                self.currentCharDuration = self.lyricsWithDuration.first?.1 ?? 0.0
                self.startTime = Date()
                if self.hasNextLine {
                    self.nextCharDuration = self.NextlyricsWithDuration.first?.1 ?? 0.0
                    self.nextstartTime = Date()
                }
            }
        }
    }
}
