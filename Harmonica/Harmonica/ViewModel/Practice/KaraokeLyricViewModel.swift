// KaraokeLyricViewModel.swift
import SwiftUI
import AVFoundation

@Observable // 이거랑 ObservableObject가 동시에 필요할까?
class KaraokeLyricViewModel: ObservableObject {
    // MARK: - State
    @Published private var currentLineIndex: Int = 0
    @Published private var currentLine: LyricLine = LyricLine(text: "", timings: [])
    @Published private var currentCharacterIndex: Int = 0
    @Published private var currentCharacterProgress: CGFloat = 0.0
    @Published private var currentCharDuration: Double = 0.0
    @Published private var startTime: Date = Date()
    @Published private var countdown: Int? = nil
    @Published private var countdownTimer: Timer?
    @Published private var isCountingDown = false
    
    @Published private var nextLineIndex: Int = 1
    @Published private var nextLine: LyricLine = LyricLine(text: "", timings: [])
    @Published private var nextCharacterIndex: Int = 0
    @Published private var nextCharacterProgress: CGFloat = 0.0
    @Published private var nextCharDuration: Double = 0.0
    @Published private var nextstartTime: Date = Date()
    
    // 음악 재생 관련 State
    let songInfo: SongInfo
    @Published private var player: AVPlayer = AVPlayer()
    @Published private var mode: PlayMode = .ar
    @Published private var currentTime: Double = 0
    @Published private var playbackTimer: Timer?
    @Published private var autoProgressTimer: Timer?
    @Published private var currentSegmentIndex = 0
    @Published private var segments: [LyricSegment] = []
    @Published private var lyricLines: [LyricLine] = []
    @Published private var isPlaying = false
    
    // 메트로놈 관련 State
    @Published private var metronomeStartTime: Date?
    @Published private var currentBeat: Int = 0
    @Published private var beatProgress: CGFloat = 0.0
    @Published private var isMetronomeActive = false
    @Published private var lastBeatTime: Date = Date()
    @Published private var metronomePlayer: AVAudioPlayer?

    //View용 State
    @Published private var isBackPressed: Bool = false
    @Published private var isRetryPressed: Bool = false
    @Published private var isNextPressed: Bool = false
    
    @Published private var beatsPerMeasure: Int {
        songInfo.timeSignatureTop
    }

    @Published private var beatDuration: Double {
        60.0 / Double(songInfo.bpm)
    }
    
    @Published var hasNextLine: Bool {
        guard nextLineIndex < lyricLines.count,
              nextLineIndex < segments.count,
              currentSegmentIndex < segments.count else { return false }
        return segments[currentSegmentIndex].index == segments[nextLineIndex].index
    }
    
    @Published var lyricsWithDuration: [(String, Double)] {
        currentLine.characterDurations
    }
    
    @Published var NextlyricsWithDuration: [(String, Double)] {
        nextLine.characterDurations
    }
    
    @Published let fullText = lyricsWithDuration.map { $0.0 }.joined()
    @Published let highlightedText = lyricsWithDuration.prefix(currentCharacterIndex).map { $0.0 }.joined()
    @Published let currentChar = currentCharacterIndex < lyricsWithDuration.count ? lyricsWithDuration[currentCharacterIndex].0 : ""
    
    @Published let nextfullText = NextlyricsWithDuration.map { $0.0 }.joined()
    @Published let nexthighlightedtext = NextlyricsWithDuration.prefix(nextCharacterIndex).map { $0.0 }.joined()
    @Published let nextcurrentChar = nextCharacterIndex < NextlyricsWithDuration.count ? NextlyricsWithDuration[nextCharacterIndex].0 : ""
    
    
    // MARK: - Test
    
    
    func updateTimer() {
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
    
    func updateTimer2() {
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
                        mode = .mr
                        startMRPlayback(segment: segment)
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
            guard let currentCount = countdown else { return }
            
            countdown = currentCount + 1
            
            if countdown! >= 4 {
                countdown = nil
                isCountingDown = false
                timer.invalidate()
                countdownTimer = nil
                
                guard currentSegmentIndex < segments.count else { return }
                let segment = segments[currentSegmentIndex]
                player.play()
                startPlaybackTimer(segment: segment)
                
                currentCharDuration = lyricsWithDuration.first?.1 ?? 0.0
                startTime = Date()
                if hasNextLine {
                    nextCharDuration = NextlyricsWithDuration.first?.1 ?? 0.0
                    nextstartTime = Date()
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
            guard let currentCount = countdown else { return }
            
            countdown = currentCount + 1
            
            if countdown! >= 4 {
                countdown = nil
                isCountingDown = false
                timer.invalidate()
                countdownTimer = nil
                
                guard currentSegmentIndex < segments.count else { return }
                let segment = segments[currentSegmentIndex]
                player.play()
                startPlaybackTimer(segment: segment)
                
                currentCharDuration = lyricsWithDuration.first?.1 ?? 0.0
                startTime = Date()
                if hasNextLine {
                    nextCharDuration = NextlyricsWithDuration.first?.1 ?? 0.0
                    nextstartTime = Date()
                }
            }
        }
    }
}
